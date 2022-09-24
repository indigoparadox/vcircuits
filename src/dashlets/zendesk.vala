
using Mosquitto;
using Gtk;
using Json;

namespace Dashboard {
    public class DashletZendesk : Dashboard.Dashlet {
        public Gtk.ListBox listbox;
        public string ticket_class;
        private Gtk.Label updated_label;

        public DashletZendesk( Dashboard dashboard_in ) {
            this.dashboard = dashboard_in;
        }

        private void parse_tickets( string topic, string msg ) {
            
            if( this.topic != topic ) {
                return;
            }

            var parser = new Json.Parser();

            // Clear this widget's listbox before starting.
            foreach( var child in this.listbox.get_children() ) {
                child.destroy();
            }

            try {
                parser.load_from_data( msg, -1 );
                var msg_root = parser.get_root().get_object();

                int updated_unix = (int)msg_root.get_int_member( "updated" );
                Time updated_time = Time.local( updated_unix );
                debug( "updated at %s", updated_time.to_string() );
                this.updated_label.set_text( updated_time.to_string() );

                var msg_results = msg_root.get_array_member( "results" );

                foreach( var ticket_iter in msg_results.get_elements() ) {
                    // Get ticket properties.
                    var ticket_obj = ticket_iter.get_object();
                    StringBuilder ticket_subject = new StringBuilder( "" );
                    ticket_subject.printf(
                        "[%d] %s",
                        (int)ticket_obj.get_int_member( "id" ),
                        ticket_obj.get_string_member( "subject" ) );
                    debug( "found ticket: %s", ticket_subject.str );

                    // Add ticket to listbox.
                    // TODO: Limit subject length.
                    var subject_lbl = new Label( ticket_subject.str );
                    subject_lbl.set_halign( Gtk.Align.START );
                    this.listbox.add( subject_lbl );
                    this.listbox.show_all();
                }

            } catch( GLib.Error e ) {
                critical( "JSON error: %s", e.message );
            }
        }

        public override void build( Gtk.Box box ) {
            this.updated_label = new Gtk.Label( "" );
            this.updated_label.set_halign( Gtk.Align.START );
            var context = this.updated_label.get_style_context();
            context.add_class( "circuits-zendesk-updated" );
            box.add( this.updated_label );

            this.listbox = new ListBox();
            context = this.listbox.get_style_context();
            context.add_class( "circuits-zendesk-tickets" );
            context.add_class( this.ticket_class );
            box.add( this.listbox );
        }

        public override void config( Json.Object config_obj ) {
            this.topic = config_obj.get_string_member( "topic" );
            debug( "topic: %s", this.topic );
            this.ticket_class = config_obj.get_string_member( "ticketclass" );

            this.source = config_obj.get_string_member( "source" );

            this.dashboard.sources.foreach( ( k, v ) => {
                // Skip non-subscribed sources.
                if( k != this.source ) {
                    return;
                }

                v.messaged.connect( this.parse_tickets );
            } );
        }
    }
}
