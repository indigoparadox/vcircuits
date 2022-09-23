
using Mosquitto;
using Gtk;
using Json;
using Curl;
using Secret;

namespace Dashboard {

    public class DashletREST : Dashlet {

        private class InputOutput {
            public string name;
            public bool is4k;
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
                var output_lbl = new Gtk.Label( output.name );
                var context = output_lbl.get_style_context();
                context.add_class( "circuits-rest-output-title" );
                box.add( output_lbl );
                output_lbl.set_alignment( 0, 0 );

                var input_grid = new Gtk.Grid();
                int input_y_iter = 0;
                int input_x_iter = 0;

                foreach( var input in this.inputs ) {
                    if( input.is4k && !output.is4k ) {
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

        public override void mqtt_connect( Mosquitto.Client m ) {

        }

        public override void mqtt_message( Mosquitto.Client m, Mosquitto.Message msg ) {

        }

        public override void config( Json.Object config_obj ) {
            this.url = config_obj.get_string_member( "url" );
            stdout.printf( "REST url: %s\n", this.url );

            this.columns = (int)config_obj.get_int_member( "columns" );

            foreach( var input_iter in config_obj.get_array_member( "inputs" ).get_elements() ) {
                var input = new InputOutput();
                var input_obj = input_iter.get_object();
                input.is4k = input_obj.get_boolean_member( "is4k" );
                input.name = input_obj.get_string_member( "name" );
                input.id = input_obj.get_string_member( "id" );
                this.inputs.append( input );
            }

            foreach( var output_iter in config_obj.get_array_member( "outputs" ).get_elements() ) {
                var output = new InputOutput();
                var output_obj = output_iter.get_object();
                output.is4k = output_obj.get_boolean_member( "is4k" );
                output.name = output_obj.get_string_member( "name" );
                output.id = output_obj.get_string_member( "id" );
                this.outputs.append( output );
            }

            this.user = config_obj.get_string_member( "user" );
            stdout.printf( "REST user: %s\n", this.user );
        }
    }
}
