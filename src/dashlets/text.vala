
// vi:syntax=cs

using Gtk;
using Json;

namespace Dashboard {
    public class DashletText : Dashlet {
        private Gtk.Label updated_label;

        public DashletText( Dashboard dashboard_in ) {
            base( dashboard_in );
        }

        private void parse_tickets( string topic, string msg ) {
            this.updated_label.set_text( msg );
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

                v.messaged.connect( this.parse_tickets );
            } );
        }
    }
}
