
using Mosquitto;
using Gtk;
using Json;
using Secret;
using DashSource;

namespace Dashboard {
    
    public class DashletNotebookTab : GLib.Object, DashletBuilder {
        
        public string title;
        public Gtk.Box notebook_page = null;
        public Gtk.Label label;

        public void build_title( Dashboard.Dashlet child ) {
            var label = new Label( child.title );
            this.notebook_page.add( label );
            var context = label.get_style_context();
            context.add_class( "circuits-dashlet-title" );
            label.set_halign( Gtk.Align.START );
        }

        public void build_in_box( Dashboard.Dashlet child ) {
            // Draw dashlet using its individual drawing method.
            debug( "building notebook box for: %s", child.title );
            Gtk.Box box = new Gtk.Box( Gtk.Orientation.VERTICAL, 1 );
            assert( null != this.notebook_page );
            this.notebook_page.add( box );
            child.build( box );
            var context = box.get_style_context();
            context.add_class( "circuits-dashlet-box" );
            this.notebook_page.show_all();
        }
    }

    public class DashletNotebook : Dashboard.Dashlet {

        public List<DashletNotebookTab> tabs;
        public Gtk.Notebook notebook;

        public DashletNotebook( Dashboard dashboard_in ) {
            this.dashboard = dashboard_in;
            this.tabs = new List<DashletNotebookTab>();
        }

        public override void build( Gtk.Box box ) {
            this.notebook = new Gtk.Notebook();

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
