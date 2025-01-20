
// vi:syntax=cs

using Gtk;
using Json;
using Curl;
using Secret;

namespace Dashboard {

    public class DashletRESTIO : Dashlet {

        private class InputOutput {
            public string name;
            public bool flag;
            public string id;
        }

        string url = null;
        string post = null;
        string user = null;
        PasswordHolder password;
        List<InputOutput> inputs;
        List<InputOutput> outputs;
        int columns;

        // Pre-token-replaced URL/POST from the last clicked radio button.
        string output_url = null;
        string output_post = null;

        public DashletRESTIO( Dashboard dashboard_in ) {
            base( dashboard_in );

            this.inputs = new List<InputOutput>();
            this.outputs = new List<InputOutput>();
        }

        protected void call_url( string click_url, string? post_data ) {

            // Perform output replacement based on selected radio button.

            // Perform the actual request.
            var handle = new EasyHandle();
            handle.setopt( Option.URL, click_url );
            handle.setopt( Option.VERBOSE, 0 );
            handle.setopt( Option.STDERR, 0 );
            if( null != post_data ) {
                  handle.setopt( Option.POSTFIELDS, post_data );
            }
            if( null != this.user ) {
                handle.setopt(
                    Option.USERPWD,
                    "%s:%s".printf( this.user, this.password.password ) );
            }
            handle.perform();
        }

        public override void build( Gtk.Box box ) {
            base.build( box );

            if( null != this.user ) {
                // Grab password once at the beginning.
                this.password = new PasswordHolder();
                this.password.schema = new Secret.Schema(
                    "info.interfinitydynamics.circuits.rest",
                    Secret.SchemaFlags.NONE,
                    "url", Secret.SchemaAttributeType.STRING,
                    "user", Secret.SchemaAttributeType.STRING
                );
                this.password.attribs["url"] = this.url;
                this.password.attribs["user"] = this.user;
                this.password.label = "%s@%s".printf( this.user, this.url );
                this.password.config_password(
                    "REST API: %s".printf( this.title ) );
            }

            var input_grid = new Gtk.Grid();
            int input_y_iter = 0;
            int input_x_iter = 0;
            Gtk.RadioButton first_button = null;

            foreach( var output in this.outputs ) {
                Gtk.RadioButton output_btn =
                    new Gtk.RadioButton.with_label_from_widget(
                        first_button, output.name );

                if( null == first_button ) {
                    // Connect subsequent radio buttons to this one.
                    first_button = output_btn;

                    this.output_url = this.url
                        .replace( "{output}", output.id.to_string() );
                    if( null != this.post ) {
                        this.output_post = this.post
                            .replace( "{output}", output.id.to_string() );
                    }
                }

                Gtk.StyleContext context = output_btn.get_style_context();
                context.add_class( "circuits-rest-output-button" );
                output_btn.toggled.connect( ( b ) => {
                    // Callback handler: Setup output URL/POST data.

                    this.output_url = this.url
                        .replace( "{output}", output.id.to_string() );
                    debug( "set output URL to: %s", this.output_url );

                    if( null != this.post ) {
                        this.output_post = this.post
                            .replace( "{output}", output.id.to_string() );
                        debug( "set output POST to: %s", this.output_post );
                    }
                } );
                input_grid.attach(
                    output_btn, input_x_iter, input_y_iter, 1, 1 );

                // Move right, or down if we've reached max columns.
                input_x_iter++;
                if( this.columns <= input_x_iter ) {
                   input_y_iter++;
                   input_x_iter = 0;
                }
            }

            // Reset to a new line in the grid for input buttons.
            input_y_iter += 1;
            input_x_iter = 0;

            foreach( var input in this.inputs ) {
                // TODO: Show an error if button clicked with mismatched
                //       input/output flags?
                //if( input.flag && !output.flag ) {
                //    continue;
                //}

                var input_btn = new Gtk.Button();
                input_btn.set_label( input.name );
                Gtk.StyleContext context = input_btn.get_style_context();
                context.add_class( "circuits-rest-input-button" );
                input_btn.clicked.connect( ( b ) => {
                    // Callback handler: Perform REST request.
                    var click_url = this.output_url
                        .replace( "{input}", input.id.to_string() );

                    string post_data = null;
                    if( null != this.post ) {
                        post_data = this.output_post
                            .replace( "{input}", input.id.to_string() );
                    }

                    this.call_url( click_url, post_data );

                } );
                input_grid.attach(
                    input_btn, input_x_iter, input_y_iter, 1, 1 );

                // Move right, or down if we've reached max columns.
                input_x_iter++;
                if( this.columns <= input_x_iter ) {
                   input_y_iter++;
                   input_x_iter = 0;
                }
            }

            box.add( input_grid );
        }

        private void load_list(
            Json.Array list_in, ref List<InputOutput> xputs
        ) {
            foreach( Json.Node input_iter in list_in.get_elements() ) {
                debug( "list iter" );
                var input = new InputOutput();
                Json.Object input_obj = input_iter.get_object();
                if( input_obj.has_member( "flag" ) ) {
                    input.flag = input_obj.get_boolean_member( "flag" );
                }
                input.name = input_obj.get_string_member( "name" );
                input.id = input_obj.get_string_member( "id" );
                xputs.append( input );
            }
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            this.url = config_obj.get_string_member( "url" );
            debug( "REST url: %s", this.url );

            this.post = config_obj.get_string_member( "post" );

            this.columns = (int)config_obj.get_int_member( "columns" );

            // Determine if the input list is in this part of the JSON file
            // directly, or if it is a reference to a stored list.
            var input_list = config_obj.get_member( "inputs" );
            if( Json.NodeType.ARRAY == input_list.get_node_type() ) {
                debug( "loading inline input list..." );
                this.load_list( input_list.get_array(), ref this.inputs );
            } else {
                var list_key = config_obj.get_string_member( "inputs" );
                debug( "loading stored input list: %s", list_key );
                this.load_list(
                    this.dashboard.lists[list_key], ref this.inputs );
            }

            var output_list = config_obj.get_member( "outputs" );
            if( Json.NodeType.ARRAY == output_list.get_node_type() ) {
                debug( "loading inline output list..." );
                this.load_list( output_list.get_array(), ref this.outputs );
            } else {
                var list_key = config_obj.get_string_member( "outputs" );
                debug( "loading stored output list: %s", list_key );
                this.load_list(
                    this.dashboard.lists[list_key], ref this.outputs );
            }

            this.user = config_obj.get_string_member( "user" );
            debug( "REST user: %s", this.user );
        }
    }
}
