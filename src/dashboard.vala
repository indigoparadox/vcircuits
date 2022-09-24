
using Mosquitto;
using Gtk;
using Json;
using Secret;
using DashSource;

namespace Dashboard {

    public interface DashletBuilder : GLib.Object {
        public abstract void build_title( Dashboard.Dashlet child );
        public abstract void build_in_box( Dashboard.Dashlet child );
    }

    public class Dashboard : GLib.Object, DashletBuilder {

        public abstract class Dashlet : GLib.Object {
            public string title = null;
            public Dashboard dashboard;
            public string topic = null;
            public string source = null;
            public DashletBuilder builder = null;
    
            public abstract void build( Gtk.Box box );
            public abstract void config( Json.Object config_obj );
        }
        public List<Dashlet> dashlets;
        public HashTable<string, DashSource.DashSource> sources;
        private int y_iter;
        private int x_iter;
        
        private Gtk.Window window;
        private Gtk.Grid grid;

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
            
            Json.Object config_root = null;
            try {
                // TODO: Break up this try so a single source or dashlet can't
                //       block all subsequent configs.

                parser.load_from_file( config_path );
                config_root = parser.get_root().get_object();
            } catch( GLib.Error e ) {
                critical( "JSON error: %s", e.message );
            }

            if( null == config_root ) {
                return;
            }
        
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

            var config_dashboard = config_root.get_array_member( "dashboard" );
            foreach( var dashlet_iter in config_dashboard.get_elements() ) {
                this.config_dashlet( dashlet_iter.get_object() );
            }
        }

        public Dashboard.Dashlet config_dashlet( Json.Object dashlet_obj ) {
               
            // Parse Dashlet config.
            Dashlet dashlet_out = null;

            debug( "dashlet: %s", dashlet_obj.get_string_member( "type" ) );
            switch( dashlet_obj.get_string_member( "type" ) ) {
            case "zendesk":
                dashlet_out = new DashletZendesk( this );
                break;
            
            case "rest":
                dashlet_out = new DashletREST( this );
                break;

            case "notebook":
                dashlet_out = new DashletNotebook( this );
                break;
            
            case "break":
                dashlet_out = new DashletBreak( this );
                break;
            }

            if( null != dashlet_out ) {
                dashlet_out.builder = this;
                dashlet_out.title = dashlet_obj.get_string_member( "title" );
                dashlets.append( dashlet_out );

                // Make sure notebook is appended above before its children.
                dashlet_out.config( dashlet_obj );
            }

            return dashlet_out;
        }

        public void connect_sources() {
            // Instruct all loaded sources to connect to their remote servers.
            this.sources.foreach( ( k, v ) => {
                v.connect();
            } );
        }

        public void build_title( Dashboard.Dashlet child ) {
            var label = new Label( child.title );
            this.grid.attach( label, this.x_iter, this.y_iter, 1, 1 );
            this.y_iter++;
            var context = label.get_style_context();
            context.add_class( "circuits-dashlet-title" );
            label.set_halign( Gtk.Align.START );
        }

        public void build_in_box( Dashboard.Dashlet child ) {
            // Draw dashlet using its individual drawing method.
            debug( "building box for: %s", child.title );
            Gtk.Box box = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
            this.grid.attach( box, this.x_iter, this.y_iter, 1, 1 );
            this.y_iter++;
            child.build( box );
            var context = box.get_style_context();
            context.add_class( "circuits-dashlet-box" );
        }

        public void build() {
            // Window setup.
            this.grid = new Grid();

            this.grid.set_row_spacing( 3 );

            foreach( var dashlet in dashlets ) {
                // Create dashlet title.
                if( null != dashlet.title ) {
                    dashlet.builder.build_title( dashlet );
                }

                dashlet.builder.build_in_box( dashlet );
            }

            this.window.add( this.grid );
            this.window.destroy.connect( Gtk.main_quit );
            this.window.show_all();
        }
    }
}
