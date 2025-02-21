
// vi:syntax=cs

using Json;
using Dashboard;

namespace DashSource {

    public class DashSourceIMAP : DashSource {

        int frequency = 0;

        public DashSourceIMAP( Dashboard.Dashboard dashboard_in, string source_in ) {
            base( dashboard_in, source_in );
        }

        private bool poll_messages() {
            this.poll_topics( ( topic, response ) => {

                // Parse message list.
                var response_arr = response.split( " " );
                if( "*" != response_arr[0] && "SEARCH" != response_arr[1] ) {
                    warning( "invalid IMAP response: %s", response );
                    this.busy = false;
                    return;
                }

                for( var i = 2 ; i < response_arr.length - 4 ; i++ ) {
                    debug( response_arr[i] );
                    var msg_header = this.fetch_curl(
                        "%s://%s:%d/%s".printf(
                            this.protocol, this.host, this.port, topic ),
                        "UID FETCH %s (FLAGS BODY[HEADER.FIELDS (Subject)])"
                            .printf( response_arr[i] ),
                        // TODO: Configure timeout.
                        null, null, null, 30 );

                    // TODO

                    debug( msg_header );
                }
            // TODO: Don't hardcode date!
            }, "SEARCH SINCE 21-Sep-2022" );

            return true;
        }

        public override void connect_source() {

            debug( "starting up IMAP polling for %s@%s:%d", this.user, this.host, this.port );

            this.ask_password();

            GLib.Timeout.add( this.frequency, this.poll_messages );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            this.frequency = (int)config_obj.get_int_member( "frequency" );

            debug( "IMAP source: %s@%s:%d, every %d ms", this.user, this.host, this.port, this.frequency );
        }
    }
}
