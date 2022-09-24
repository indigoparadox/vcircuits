
using Mosquitto;
using Gtk;
using Json;
using Secret;
using DashSource;

namespace Dashboard {

    public class Dashboard {

        public abstract class Dashlet {
            public string title = null;
            public Dashboard dashboard;
            public string topic = null;
            public string source = null;
    
            public abstract void build( Gtk.Box box );
            public abstract void config( Json.Object config_obj );
        }

        public List<Dashlet> dashlets;
        public HashTable<string, DashSource.DashSource> sources;
        private int y_iter;
        private int x_iter;
        
        private Gtk.Window window;

        public class DashletBreak : Dashlet {
            public DashletBreak( Dashboard dashboard_in ) {
                this.dashboard = dashboard_in;
                this.topic = null;
            }
            public override void build( Gtk.Box box ) {
                this.dashboard.x_iter += 1;
                this.dashboard.y_iter = 1;
            }
            public override void config( Json.Object config_obj ) {}
        }

        public Dashboard() {
            this.dashlets = new List<Dashlet>();
            this.sources = new HashTable<string, DashSource.DashSource>( str_hash, str_equal );
            this.window = new Gtk.Window();
            this.x_iter = 0;
            this.y_iter = 1;
        }

        public void config( string config_path ) {

            Gtk.CssProvider style = new Gtk.CssProvider();
            try {
                style.load_from_path( "circuits.css" );
            } catch( GLib.Error e ) {
                critical( "style error: %s", e.message );
            }
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                style,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION );

            Json.Parser parser = new Json.Parser();
            
            try {
                // TODO: Break up this try so a single source or dashlet can't
                //       block all subsequent configs.

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

                // Parse sources config first so dashlets can reference them.
                var config_sources = config_root.get_object_member( "sources" );
                foreach( var source_key in config_sources.get_members() ) {
                    var source_obj = config_sources.get_object_member( source_key );
                    DashSource.DashSource source_out = null;
        
                    debug( "source: %s", source_obj.get_string_member( "type" ) );
                    switch( source_obj.get_string_member( "type" ) ) {
                    case "mqtt":
                        source_out = new DashSourceMQTT( this, source_key );
                        break;
                    }
        
                    if( null != source_out ) {
                        // Source was successfully loaded.
                        source_out.config( source_obj );
                        this.sources[source_key] = source_out;
                    }
                }
               
                // Parse Dashlet config.
                var config_dashboard = config_root.get_array_member( "dashboard" );
                foreach( var dashlet_iter in config_dashboard.get_elements() ) {
                    var dashlet_obj = dashlet_iter.get_object();
                    Dashlet dashlet_out = null;
        
                    debug( "dashlet: %s", dashlet_obj.get_string_member( "type" ) );
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
                        dashlet_out.config( dashlet_obj );
                        dashlet_out.title = dashlet_obj.get_string_member( "title" );
                        dashlets.append( dashlet_out );
                    }
                }
        
            } catch( GLib.Error e ) {
                critical( "JSON error: %s", e.message );
            }
        }

        public void connect() {
            // Instruct all loaded sources to connect to their remote servers.
            this.sources.foreach( ( k, v ) => {
                v.connect();
            } );
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
                    label.set_halign( Gtk.Align.START );
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
    }
}
