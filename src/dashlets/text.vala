
// vi:syntax=cs

using Gtk;
using Json;

namespace Dashboard {
    public class DashletText : DashletRESTBase {
        private Gtk.Label updated_label;

        public DashletText( Dashboard dashboard_in ) {
            base( dashboard_in );
        }

        private void update_label( string topic, string msg ) {
            string msg_cleaned = null;
            string msg_out = null;

            // Grab the message from JSON if necessary.
            if( this.has_path() ) {
                try {
                    msg_out = this.parse_json_path( msg );
                } catch( DashletError e ) {
                    critical( "JSON parse error: %s", e.message );
                    return;
                }
            } else {
                msg_out = msg;
            }

            // Render the final message.
            msg_cleaned = this.parse_output_tokens( msg_out );
            this.updated_label.set_text( msg_cleaned );
        }

        public override void build( Gtk.Box box ) {
            base.build( box );
            
            this.updated_label = new Gtk.Label( "" );
            this.updated_label.set_halign( Gtk.Align.START );
            var context = this.updated_label.get_style_context();
            context.add_class( "circuits-text-text" );
            box.add( this.updated_label );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );
            
            this.dashboard.sources.foreach( ( k, v ) => {
                // Skip non-subscribed sources.
                if( k != this.source ) {
                    return;
                }

                debug( "connecting to source: %s", k );

                v.messaged.connect( this.update_label );
            } );
        }
    }
}
