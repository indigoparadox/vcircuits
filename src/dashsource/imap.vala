
using Gtk;
using Json;
using Curl;
using Secret;
using Dashboard;

namespace DashSource {

    size_t on_imap_list( char* buf, size_t size, size_t nmemb, ref StringBuilder up ) {
        //debug( "imap %" + size_t.FORMAT + " of %" + size_t.FORMAT, (long)size, (long)nmemb );
        assert( null != buf );
        up.append( (string)buf );
        return size * nmemb;
    }

    public class DashSourceIMAP : DashSource {

        int frequency = 0;
        bool busy = false;

        public DashSourceIMAP( Dashboard.Dashboard dashboard_in, string source_in ) {
            base( dashboard_in, source_in );
        }

        private bool poll_messages() {
            foreach( var dashlet in this.dashboard.dashlets ) {
                if( dashlet.source != this.source ) {
                    continue;
                }

                if( null == this.password.password ) {
                    warning( "%s@%s:%d: no password found!", this.user, this.host, this.port );
                    return true;
                }

                if( this.busy ) {
                    warning( "poller busy!" );
                    return true;
                }

                debug( "polling IMAP %s@%s:%d/%s...", this.user, this.host, this.port, dashlet.topic );

                // Fetch inbox.
                this.busy = true;
                var handle = new EasyHandle();
                handle.setopt( Option.URL, "imaps://%s:%d/%s".printf( this.host, this.port, dashlet.topic ) );
                handle.setopt( Option.USERPWD, "%s:%s".printf( this.user, this.password.password ) );
                handle.setopt( Option.CUSTOMREQUEST, "SEARCH SINCE 21-Sep-2022" );
                //handle.setopt( Option.VERBOSE, 1 );
                //handle.setopt( Option.STDERR, 1 );

                StringBuilder response = new StringBuilder();
                handle.setopt( Option.WRITEFUNCTION, on_imap_list );
                handle.setopt( Option.WRITEDATA, ref response );
                handle.perform();

                // Parse message list.
                var response_arr = response.str.split( " " );
                if( "*" != response_arr[0] && "SEARCH" != response_arr[1] ) {
                    warning( "invalid IMAP response: %s", response.str );
                    this.busy = false;
                    return true;
                }

                for( var i = 2 ; i < response_arr.length - 4 ; i++ ) {
                    debug( response_arr[i] );
                    handle = new EasyHandle();
                    handle.setopt( Option.URL, "imaps://%s:%d/%s".printf(
                        this.host, this.port, dashlet.topic ) );
                    handle.setopt( Option.USERPWD, "%s:%s".printf( this.user, this.password.password ) );
                    handle.setopt( Option.CUSTOMREQUEST,
                        "UID FETCH %s (FLAGS BODY[HEADER.FIELDS (Subject)])".printf( response_arr[i] ) );
                    //handle.setopt( Option.VERBOSE, 1 );

                    StringBuilder msg_response = new StringBuilder();
                    //handle.setopt( Option.HEADERFUNCTION, on_imap_list );
                    //handle.setopt( Option.HEADERDATA, ref msg_response );
                    handle.setopt( Option.WRITEFUNCTION, on_imap_list );
                    handle.setopt( Option.WRITEDATA, ref msg_response );
                    handle.perform();

                    // TODO

                    debug( msg_response.str );
                }

                this.busy = false;
                
                this.messaged( dashlet.topic, response.str );
            }

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
