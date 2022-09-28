
using Gtk;
using Json;
using Curl;
using Secret;

namespace Dashboard {

    public class DashletREST : Dashboard.Dashlet {

        private class InputOutput {
            public string name;
            public bool flag;
            public string id;
        }

        string url = null;
        string user = null;
        PasswordHolder password;
        List<InputOutput> inputs;
        List<InputOutput> outputs;
        int columns;

        public DashletREST( Dashboard dashboard_in ) {
            this.dashboard = dashboard_in;
            this.inputs = new List<InputOutput>();
            this.outputs = new List<InputOutput>();
        }

        public override void build( Gtk.Box box ) {

            if( null != this.user ) {
                // Grab password once at the beginning.
                this.password = new PasswordHolder();
                this.password.schema = new Secret.Schema(
                    "info.interfinitydynamics.circuits.rest", Secret.SchemaFlags.NONE,
                    "url", Secret.SchemaAttributeType.STRING,
                    "user", Secret.SchemaAttributeType.STRING
                );
                this.password.attribs["url"] = this.url;
                this.password.attribs["user"] = this.user;
                this.password.label = "%s@%s".printf( this.user, this.url );

                this.password.config_password( "REST API: %s".printf( this.title ) );
            }

            foreach( var output in this.outputs ) {
                Gtk.StyleContext context = null;

                if( 1 < this.outputs.length() ) {
                    var output_lbl = new Gtk.Label( output.name );
                    context = output_lbl.get_style_context();
                    context.add_class( "circuits-rest-output-title" );
                    box.add( output_lbl );
                    output_lbl.set_halign( Gtk.Align.START );
                }

                var input_grid = new Gtk.Grid();
                int input_y_iter = 0;
                int input_x_iter = 0;

                foreach( var input in this.inputs ) {
                    if( input.flag && !output.flag ) {
                        continue;
                    }

                    var input_btn = new Gtk.Button();
                    input_btn.set_label( input.name );
                    context = input_btn.get_style_context();
                    context.add_class( "circuits-rest-input-button" );
                    input_btn.clicked.connect( ( b ) => {
                        // Callback handler: Perform REST request.
                        var click_url = this.url
                            .replace( "{input}", input.id.to_string() )
                            .replace( "{output}", output.id.to_string() );

                        var handle = new EasyHandle();
                        handle.setopt( Option.URL, click_url );
                        handle.setopt( Option.VERBOSE, 0 );
                        handle.setopt( Option.STDERR, 0 );
                        if( null != this.user ) {
                            handle.setopt( Option.USERPWD, "%s:%s".printf( this.user, this.password.password ) );
                        }
                        handle.perform();
                    } );
                    input_grid.attach( input_btn, input_x_iter, input_y_iter, 1, 1 );

                    // Move right, or down if we've reached max columns.
                    input_x_iter++;
                    if( this.columns <= input_x_iter ) {
                        input_y_iter++;
                        input_x_iter = 0;
                    }
                }

                box.add( input_grid );
            }
        }

        public override void config( Json.Object config_obj ) {
            this.url = config_obj.get_string_member( "url" );
            debug( "REST url: %s", this.url );

            this.columns = (int)config_obj.get_int_member( "columns" );

            foreach( var input_iter in config_obj.get_array_member( "inputs" ).get_elements() ) {
                var input = new InputOutput();
                var input_obj = input_iter.get_object();
                input.flag = input_obj.get_boolean_member( "flag" );
                input.name = input_obj.get_string_member( "name" );
                input.id = input_obj.get_string_member( "id" );
                this.inputs.append( input );
            }

            foreach( var output_iter in config_obj.get_array_member( "outputs" ).get_elements() ) {
                var output = new InputOutput();
                var output_obj = output_iter.get_object();
                output.flag = output_obj.get_boolean_member( "flag" );
                output.name = output_obj.get_string_member( "name" );
                output.id = output_obj.get_string_member( "id" );
                this.outputs.append( output );
            }

            this.user = config_obj.get_string_member( "user" );
            debug( "REST user: %s", this.user );
        }
    }
}
