
// vi:syntax=cs

using Gtk;
using Json;
using DashSource;

namespace Dashboard {
    
    public class DashletNotebookTab : GLib.Object, DashletBuilder {
        
        public string title;
        public Gtk.Box notebook_page = null;
        public Gtk.Label label;

        public void build_in_box( Dashlet child ) {
            // Draw dashlet using its individual drawing method.
            debug( "building notebook box for: %s", child.title );
            Gtk.Box box = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
            assert( null != this.notebook_page );
            this.notebook_page.add( box );
            child.build( box );
            this.notebook_page.show_all();
        }
    }

    public class DashletNotebook : Dashlet {

        public List<DashletNotebookTab> tabs;
        public Gtk.Notebook notebook;
        public bool expand;

        public DashletNotebook( Dashboard dashboard_in ) {
            base( dashboard_in );

            this.expand = false;
            this.tabs = new List<DashletNotebookTab>();
        }

        public override void build( Gtk.Box box ) {
            base.build( box );

            this.notebook = new Gtk.Notebook();
            var context = this.notebook.get_style_context();
            context.add_class( "circuits-dashlet-notebook" );
            this.notebook.hexpand = this.expand;

            foreach( var tab in this.tabs ) {
                debug( "creating notebook page for: %s", tab.title );
                tab.notebook_page = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
                tab.label = new Gtk.Label( tab.title );
                this.notebook.append_page( tab.notebook_page, tab.label );
            }

            box.add( this.notebook );

            this.notebook.show_all();
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            this.expand = config_obj.get_boolean_member( "expand" );

            var config_tabs = config_obj.get_object_member( "contents" );
            foreach( var tab_key in config_tabs.get_members() ) {

                debug( "creating notebook tab \"%s\"...", tab_key );
                DashletNotebookTab tab = new DashletNotebookTab();
                tab.title = tab_key;
                this.tabs.append( tab );

                // Load the dashlets on this tab.
                var config_tab = config_tabs.get_array_member( tab_key );
                foreach( var dashlet_iter in config_tab.get_elements() ) {
                    var dashlet_out = this.dashboard.config_dashlet( dashlet_iter.get_object() );
                    dashlet_out.builder = tab;
                }
            }
        }
    }
}
