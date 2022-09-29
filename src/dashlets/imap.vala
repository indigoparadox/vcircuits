
using Gtk;

namespace Dashboard {
    public class DashletIMAP : Dashlet {
        public Gtk.ListBox listbox;
        public string ticket_class;
        private Gtk.Label updated_label;

        public DashletIMAP( Dashboard dashboard_in ) {
            base( dashboard_in );
        }

        private void parse_msg_list( string topic, string msg ) {
            
          
        }

        public override void build( Gtk.Box box ) {
            base.build( box );
            
            this.updated_label = new Gtk.Label( "" );
            this.updated_label.set_halign( Gtk.Align.START );
            var context = this.updated_label.get_style_context();
            context.add_class( "circuits-imap-updated" );
            box.add( this.updated_label );

            this.listbox = new ListBox();
            context = this.listbox.get_style_context();
            context.add_class( "circuits-imap-messages" );
            context.add_class( this.ticket_class );
            box.add( this.listbox );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            this.dashboard.sources.foreach( ( k, v ) => {
                // Skip non-subscribed sources.
                if( k != this.source ) {
                    return;
                }

                v.messaged.connect( this.parse_msg_list );
            } );
        }
    }
}
