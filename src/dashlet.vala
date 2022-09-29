
using Gtk;
using Json;

namespace Dashboard {

    public abstract class Dashlet : GLib.Object {
        public string title = null;
        public Dashboard dashboard;
        public string topic = null;
        public string source = null;
        public DashletBuilder builder = null;

        public Dashlet( Dashboard dashboard_in ) {
            this.dashboard = dashboard_in;
        }

        public virtual void build( Gtk.Box box ) {
            var context = box.get_style_context();
            context.add_class( "circuits-dashlet-box" );

            if( null != this.title ) {
                // Add title to box.
                var label = new Label( this.title );
                box.add( label );
                context = label.get_style_context();
                context.add_class( "circuits-dashlet-title" );
                label.set_halign( Gtk.Align.START );
            }
        }

        public virtual void config( Json.Object config_obj ) {
            this.title = config_obj.get_string_member( "title" );
            this.topic = config_obj.get_string_member( "topic" );
            this.source = config_obj.get_string_member( "source" );
        }
    }
}
