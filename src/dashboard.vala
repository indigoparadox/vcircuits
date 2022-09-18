
using Mosquitto;
using Gtk;
using Json;

namespace Dashboard {

    public abstract class Dashlet {
        public string title;
        public Dashboard dashboard;

        public abstract void build( Gtk.Box box );
        public abstract void mqtt_connect( Mosquitto.Client m );
        public abstract void mqtt_message( Mosquitto.Client m, Mosquitto.Message msg );
        public abstract void config( Json.Object config_obj );
    }

    public class Dashboard {
        public List<Dashlet> dashlets;
        private int y_iter;
        private int x_iter;
        public Mosquitto.Client m;
        
        private Gtk.Window window;
        string mqtt_host;
        int mqtt_port;
        string mqtt_user;
        string mqtt_pass;

        public class DashletBreak : Dashlet {
            public DashletBreak( Dashboard dashboard_in ) {
                this.dashboard = dashboard_in;
            }
            public override void build( Gtk.Box box ) {
                this.dashboard.x_iter += 1;
                this.dashboard.y_iter = 1;
            }
            public override void mqtt_connect( Mosquitto.Client m ) {}
            public override void mqtt_message( Mosquitto.Client m, Mosquitto.Message msg ) {}
            public override void config( Json.Object config_obj ) {}
        }

        public Dashboard() {
            this.dashlets = new List<Dashlet>();
            this.window = new Gtk.Window();
            this.x_iter = 0;
            this.y_iter = 1;
        }

        public void config( string config_path ) {

            Gtk.CssProvider style = new Gtk.CssProvider();
            style.load_from_path( "circuits.css" );
            Gtk.StyleContext context = new Gtk.StyleContext();
            context.add_provider_for_screen(
                Gdk.Screen.get_default(),
                style,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION );

            Json.Parser parser = new Json.Parser();
            
            try {
                parser.load_from_file( config_path );
                var config_root = parser.get_root().get_object();
        
                // Parse general config.
                var config_options = config_root.get_object_member( "options" );
                int dash_w = (int)config_options.get_int_member( "width" );
                int dash_h = (int)config_options.get_int_member( "height" );
                var dash_decorated = config_options.get_boolean_member( "decorated" );
                if( !dash_decorated ) {
                    this.window.set_decorated( false );
                }
                this.window.set_default_size( dash_w, dash_h );
               
                // Parse Dashlet config.
                var config_dashboard = config_root.get_array_member( "dashboard" );
                foreach( var dashlet_iter in config_dashboard.get_elements() ) {
                    var dashlet_obj = dashlet_iter.get_object();
                    Dashlet dashlet_out = null;
        
                    stdout.printf( "dashlet: %s\n", dashlet_obj.get_string_member( "type" ) );
                    switch( dashlet_obj.get_string_member( "type" ) ) {
                    case "zendesk":
                        dashlet_out = new DashletZendesk( this );
                        break;
                    
                    case "rest":
                        dashlet_out = new DashletREST( this );
                        break;

                    case "break":
                        dashlet_out = new DashletBreak( this );
                        break;
                    }
        
                    if( null != dashlet_out ) {
                        dashlets.append( dashlet_out );
                        dashlet_out.config( dashlet_obj );
                        dashlet_out.title = dashlet_obj.get_string_member( "title" );
                    }
                }
        
                // Parse MQTT config.
                var config_mqtt = config_root.get_object_member( "mqtt" );

                this.mqtt_host = config_mqtt.get_string_member( "host" );
                this.mqtt_port = (int)config_mqtt.get_int_member( "port" );
                this.mqtt_user = config_mqtt.get_string_member( "user" );
                this.mqtt_pass = config_mqtt.get_string_member( "pass" );
            } catch( GLib.Error e ) {
                stderr.printf( "JSON error: %s\n", e.message );
            }
        }

        public void build() {
            // Window setup.
            var grid = new Grid();

            grid.set_row_spacing( 3 );

            foreach( var dashlet in dashlets ) {
                // Create dashlet title.
                if( null != dashlet.title ) {
                    var label = new Label( dashlet.title );
                    grid.attach( label, this.x_iter, this.y_iter, 1, 1 );
                    this.y_iter++;
                    var context = label.get_style_context();
                    context.add_class( "circuits-dashlet-title" );
                    label.set_alignment( 0, 0 );
                }

                // Draw dashlet using its individual drawing method.
                Gtk.Box box = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
                grid.attach( box, this.x_iter, this.y_iter, 1, 1 );
                this.y_iter++;
                dashlet.build( box );
                var context = box.get_style_context();
                context.add_class( "circuits-dashlet-box" );
            }

            this.window.add( grid );
            this.window.destroy.connect( Gtk.main_quit );
            this.window.show_all();
        }

        public void mqtt_connect() {
            // Mosquitto setup.
            // TODO: Set client UID from config.
            this.m = new Client( "circ_test_123", true, null );
            this.m.connect_callback_set( on_connect );
            this.m.message_callback_set( on_message_tickets );
            this.m.username_pw_set( mqtt_user, mqtt_pass );
            this.m.connect( mqtt_host, (int)mqtt_port, 60 );

            // Update Mosquitto every couple seconds. 
            GLib.Timeout.add( 2000, () => {
                var rc = this.m.loop( -1, 1 );
                if( 0 != rc ){
                    stderr.printf( "connection error!\n" );
                    this.m.reconnect();
                }
                return true;
            }, 0 );
        }
    }

}