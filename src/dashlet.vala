
// vi:syntax=cs

using Gtk;
using Json;
using Curl;

namespace Dashboard {

    public abstract class Dashlet : GLib.Object {
        public string title = null;
        public Dashboard dashboard;
        public string topic = null;
        public string source = null;
        public DashletBuilder builder = null;
        protected long timeout = 0;

        protected Dashlet( Dashboard dashboard_in ) {
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
            if( config_obj.has_member( "timeout" ) ) {
                this.timeout = (long)config_obj.get_int_member( "timeout" );
            } else {
                this.timeout = -1;
            }

        }

        public virtual string? get_accept_type() {
            return null;
        }

        public virtual string? get_content_type() {
            return null;
        }

        public virtual string? get_source_post() {
            return null;
        }

        public virtual long get_timeout() {
            return this.timeout;
        }

        protected string parse_output_tokens( string msg ) {
            return msg.replace( "<br />", "\n" );
        }
    }
}
