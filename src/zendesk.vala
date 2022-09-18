
using Mosquitto;
using Gtk;
using Json;

namespace Dashboard {
    public class DashletZendesk : Dashlet {
        public string topic;
        public ListBox listbox;

        public DashletZendesk( Dashboard dashboard_in ) {
            this.dashboard = dashboard_in;
        }

        private void parse_tickets( string msg ) {

            var parser = new Json.Parser();

            // Clear this widget's listbox before starting.
            foreach( var child in this.listbox.get_children() ) {
                child.destroy();
            }

            try {
                parser.load_from_data( msg, -1 );
                var msg_root = parser.get_root().get_object();
                var msg_results = msg_root.get_array_member( "results" );

                foreach( var ticket_iter in msg_results.get_elements() ) {
                    // Get ticket properties.
                    var ticket_obj = ticket_iter.get_object();
                    var ticket_subject = ticket_obj.get_string_member( "subject" );
                    stdout.printf( "%s\n", ticket_subject );

                    // Add ticket to listbox.
                    // TODO: Limit subject length.
                    var subject_lbl = new Label( ticket_subject );
                    subject_lbl.set_alignment( 0, 0 );
                    this.listbox.add( subject_lbl );
                    this.listbox.show_all();
                }

            } catch( GLib.Error e ) {
                stderr.printf( "JSON error: %s\n", e.message );
            }
        }

        public override void build( Gtk.Grid grid, Gtk.CssProvider style ) {
            this.listbox = new ListBox();
            this.listbox.get_style_context().add_provider( style, Gtk.STYLE_PROVIDER_PRIORITY_USER );
            grid.attach( this.listbox, this.dashboard.x_iter, this.dashboard.y_iter, 2, 2 );
            this.dashboard.y_iter += 2;
        }

        public override void config( Json.Object config_obj ) {
            this.topic = config_obj.get_string_member( "topic" );
            stdout.printf( "topic: %s\n", this.topic );
        }

        public override void mqtt_connect( Mosquitto.Client m ) {
            stdout.printf( "subscribing to: %s\n", this.topic );
            m.subscribe( 0, this.topic, 0 );
        }

        public override void mqtt_message( Mosquitto.Client m, Mosquitto.Message msg ) {

            if( this.topic != msg.topic ) {
                return;
            }

            this.parse_tickets( msg.payload );
        }
    }
}
