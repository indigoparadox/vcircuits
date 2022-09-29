
using Gtk;
using Json;
using Curl;
using Dashboard;

namespace DashSource {

    size_t on_rest_list( char* buf, size_t size, size_t nmemb, ref StringBuilder up ) {
        //debug( "%s", (string)buf );
        debug( "rest %" + size_t.FORMAT + " of %" + size_t.FORMAT, (long)size, (long)nmemb );
        assert( null != buf );
        up.append( (string)buf );
        return size * nmemb;
    }

    public class DashSourceREST : DashSource {

        int frequency = 0;
        bool busy = false;

        public DashSourceREST( Dashboard.Dashboard dashboard_in, string source_in ) {
            base( dashboard_in, source_in );
        }

        private bool poll_topics() {
            debug( "polling REST %s:%d for %s...", this.host, this.port, this.user );

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

                this.busy = true;
                var handle = new EasyHandle();
                // TODO: Handle https.
                handle.setopt( Option.URL, "http://%s:%d/%s".printf( this.host, this.port, dashlet.topic ) );
                handle.setopt( Option.NOPROGRESS, 1L );
                handle.setopt( Option.USERPWD, "%s:%s".printf( this.user, this.password.password ) );

                StringBuilder response = new StringBuilder();
                handle.setopt( Option.WRITEFUNCTION, on_rest_list );
                handle.setopt( Option.WRITEDATA, ref response );
                
                handle.perform();

                this.messaged( dashlet.topic, response.str );

                this.busy = false;
            }

            return true;
        }

        public override void connect_source() {

            debug( "starting up REST polling for %s@%s:%d", this.user, this.host, this.port );

            this.ask_password();

            GLib.Timeout.add( this.frequency, this.poll_topics );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            this.frequency = (int)config_obj.get_int_member( "frequency" );

            debug( "REST source: %s@%s:%d, every %d ms", this.user, this.host, this.port, this.frequency );
        }
    }
}
