
using Gtk;
using Json;
using Dashboard;

namespace DashSource {

    public class DashSourceREST : DashSource {

        int frequency = 0;

        public DashSourceREST( Dashboard.Dashboard dashboard_in, string source_in ) {
            base( dashboard_in, source_in );
        }

        public override void connect_source() {

            debug( "starting up REST polling for %s@%s:%d", this.user, this.host, this.port );

            this.ask_password();

            GLib.Timeout.add( this.frequency, () => {
                this.poll_topics( ( topic, response ) => {
                    this.messaged( topic, response );
                }, null );
                return true;
            } );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            this.frequency = (int)config_obj.get_int_member( "frequency" );

            debug( "REST source: %s@%s:%d, every %d ms", this.user, this.host, this.port, this.frequency );
        }
    }
}
