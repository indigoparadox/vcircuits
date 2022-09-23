
using Mosquitto;
using Gtk;
using Json;
using Secret;

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

        public class PasswordHolder {
            public Secret.Schema schema;
            public GLib.HashTable<string, string> attribs;
            public string password;
            public string label;

            public PasswordHolder() {
                this.schema = null;
                this.attribs = new GLib.HashTable<string, string>( str_hash, str_equal );
                this.password = null;
                this.label = null;
            }
        }

        public List<Dashlet> dashlets;
        private int y_iter;
        private int x_iter;
        public Mosquitto.Client m;
        
        private Gtk.Window window;
        string mqtt_host;
        int mqtt_port;
        string mqtt_user;
        private PasswordHolder mqtt_pass;
        bool mqtt_connected = false;

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
            try {
                style.load_from_path( "circuits.css" );
            } catch( GLib.Error e ) {
                stderr.printf( "style error: %s\n", e.message );
            }
            Gtk.StyleContext.add_provider_for_screen(
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
            } catch( GLib.Error e ) {
                stderr.printf( "JSON error: %s\n", e.message );
            }

            //this.mqtt_pass = config_mqtt.get_string_member( "pass" );
        }

        public void config_password( PasswordHolder pass_out ) {
            Secret.password_lookupv.begin(
                pass_out.schema, pass_out.attribs, null,
                ( obj, async_res ) => {
                    pass_out.password = Secret.password_lookup.end( async_res );
                    if( null != pass_out.password ) {
                        return;
                    }

                    // Build password entry dialog.
                    var pass_window = new Gtk.Window();
                    var pass_grid = new Gtk.Grid();

                    var pass_txt = new Gtk.Entry();
                    pass_grid.attach( pass_txt, 0, 0, 2, 1 );

                    var ok_btn = new Gtk.Button();
                    ok_btn.set_label( "&OK" );
                    ok_btn.clicked.connect( ( b ) => {
                        pass_out.password = pass_txt.get_text();
                        Secret.password_storev.begin(
                            pass_out.schema, pass_out.attribs, Secret.COLLECTION_DEFAULT,
                            pass_out.label, pass_out.password, null,
                            ( obj, async_res ) => {
                                if( !Secret.password_store.end( async_res ) ) {
                                    stderr.printf( "unable to store password!\n" );
                                }
                            } );
                        pass_window.destroy();
                    } );
                    pass_grid.attach( ok_btn, 0, 1, 1, 1 );

                    var cancel_btn = new Gtk.Button();
                    cancel_btn.set_label( "&Cancel" );
                    pass_grid.attach( cancel_btn, 0, 2, 1, 1 );

                    pass_window.add( pass_grid );
                    pass_window.show_all();
                }
            );
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

            // Get credentials and start the connection process.
            this.mqtt_pass = new PasswordHolder();
            this.mqtt_pass.schema = new Secret.Schema(
                "info.interfinitydynamics.circuits.mqtt", Secret.SchemaFlags.NONE,
                "host", Secret.SchemaAttributeType.STRING,
                "port", Secret.SchemaAttributeType.STRING,
                "user", Secret.SchemaAttributeType.STRING
            );
            this.mqtt_pass.attribs["host"] = this.mqtt_host;
            this.mqtt_pass.attribs["port"] = this.mqtt_port.to_string();
            this.mqtt_pass.attribs["user"] = this.mqtt_user;
            this.mqtt_pass.label = "%s:%d:%s".printf( this.mqtt_host, this.mqtt_port, this.mqtt_user );

            this.config_password( this.mqtt_pass );

            // Update Mosquitto every couple seconds. 
            GLib.Timeout.add( 2000, () => {
                var rc = this.m.loop( -1, 1 );
                if( 0 == rc ){
                    return true;
                }

                // Connection failure or not connected!
                stderr.printf( "MQTT connection failed!\n" );
                if( null == this.mqtt_user || null != this.mqtt_pass.password ) {
                    stdout.printf( "MQTT reconnecting (%s, %s, %d)...\n",
                        this.mqtt_user, this.mqtt_host, this.mqtt_port );
                    if( this.mqtt_connected ) {
                        // Reconnecting after failure. Params already in place.
                        this.m.reconnect();
                    } else {
                        // First time connection.
                        this.m.username_pw_set( this.mqtt_user, this.mqtt_pass.password );
                        this.m.connect( this.mqtt_host, (int)this.mqtt_port, 60 );
                    }
                }

                return true;
            }, 0 );
        }
    }

}