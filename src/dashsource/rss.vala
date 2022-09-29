
using Json;
using Dashboard;
using Xml;

namespace DashSource {

    public class DashSourceRSS : DashSource {

        int frequency = 0;

        public DashSourceRSS( Dashboard.Dashboard dashboard_in, string source_in ) {
            base( dashboard_in, source_in );
        }

        public bool poll_feed() {
            this.poll_topics( ( topic, response ) => {
                // TODO: Parse RSS.
                this.messaged( topic, response );
            }, null );
            return true;
        }

        public override void connect_source() {

            debug( "starting up RSS polling for %s@%s:%d", this.user, this.host, this.port );

            this.ask_password();

            GLib.Timeout.add( this.frequency, this.poll_feed );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            this.frequency = (int)config_obj.get_int_member( "frequency" );

            debug( "RSS source: %s@%s:%d, every %d ms", this.user, this.host, this.port, this.frequency );
        }
    }
}
