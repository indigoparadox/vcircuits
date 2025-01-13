
// vi:syntax=cs

using Gtk;
using Json;
using DashSource;

namespace Dashboard {

    public interface DashletBuilder : GLib.Object {
        public abstract void build_in_box( Dashlet child );
    }

    public class Dashboard : GLib.Object, DashletBuilder {

        public List<Dashlet> dashlets;
        public HashTable<string, Json.Array> lists;
        public HashTable<string, DashSource.DashSource> sources;
        
        private Gtk.Window window;
        
        protected Gtk.Box rows;
        protected Gtk.Box current_column;

        public class DashletBreak : Dashlet {
            public DashletBreak( Dashboard dashboard_in ) {
                base( dashboard_in );
            }
            public override void build( Gtk.Box box ) {
                this.dashboard.current_column = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
                this.dashboard.rows.add( this.dashboard.current_column );
            }
            public override void config( Json.Object config_obj ) {}
        }

        public Dashboard() {
            this.dashlets = new List<Dashlet>();
            this.sources = new HashTable<string, DashSource.DashSource>( str_hash, str_equal );
            this.lists = new HashTable<string, Json.Array>( str_hash, str_equal );
            this.window = new Gtk.Window();
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

                if( !source_obj.get_boolean_member( "enabled" ) ) {
                    continue;
                }
    
                debug( "source: %s", source_obj.get_string_member( "type" ) );
                switch( source_obj.get_string_member( "type" ) ) {
                case "mqtt":
                    source_out = new DashSourceMQTT( this, source_key );
                    break;

                case "rest":
                    source_out = new DashSourceREST( this, source_key );
                    break;

                case "rss":
                    source_out = new DashSourceRSS( this, source_key );
                    break;
            
                case "imap":
                    source_out = new DashSourceIMAP( this, source_key );
                    break;
                }
    
                if( null != source_out ) {
                    // Source was successfully loaded.
                    source_out.config( source_obj );
                    this.sources[source_key] = source_out;
                }
            }

            // Parse lists config so dashlets can reference them.
            var config_lists = config_root.get_object_member( "lists" );
            foreach( var list_key in config_lists.get_members() ) {
               debug( "storing list: %s", list_key );
               this.lists[list_key] =
                  config_lists.get_array_member( list_key );
            }

            var config_dashboard = config_root.get_array_member( "dashboard" );
            foreach( var dashlet_iter in config_dashboard.get_elements() ) {
                this.config_dashlet( dashlet_iter.get_object() );
            }
        }

        public Dashlet config_dashlet( Json.Object dashlet_obj ) {
               
            // Parse Dashlet config.
            Dashlet dashlet_out = null;

            debug( "dashlet: %s", dashlet_obj.get_string_member( "type" ) );
            switch( dashlet_obj.get_string_member( "type" ) ) {
            case "zendesk":
                dashlet_out = new DashletZendesk( this );
                break;
            
            case "rest-io":
                dashlet_out = new DashletRESTIO( this );
                break;

            case "mail":
                dashlet_out = new DashletMail( this );
                break;

            case "notebook":
                dashlet_out = new DashletNotebook( this );
                break;
            
            case "break":
                dashlet_out = new DashletBreak( this );
                break;
            }

            if( null != dashlet_out ) {
                debug( "adding dashlet to dashboard..." );
                dashlet_out.builder = this;
                dashlets.append( dashlet_out );

                // Make sure notebook is appended above before its children.
                dashlet_out.config( dashlet_obj );
            }

            return dashlet_out;
        }

        public void connect_sources() {
            // Instruct all loaded sources to connect to their remote servers.
            this.sources.foreach( ( k, v ) => {
                debug( "connecting source: %s", k );
                v.connect_source();
            } );
        }

        public void build_title( Dashlet child ) {
        }

        public void build_in_box( Dashlet child ) {
            // Draw dashlet using its individual drawing method.
            debug( "building box for: %s", child.title );
            Gtk.Box box = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
            this.current_column.add( box );
            child.build( box );
        }

        public void build() {
            // Window setup.
            this.rows = new Gtk.Box( Gtk.Orientation.HORIZONTAL, 1 );
            this.current_column = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
            this.rows.add( this.current_column );

            foreach( var dashlet in dashlets ) {
                dashlet.builder.build_in_box( dashlet );
            }

            this.window.add( this.rows );
            this.window.destroy.connect( Gtk.main_quit );
            this.window.show_all();
        }
    }
}
