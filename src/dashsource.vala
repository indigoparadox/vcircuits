
using Dashboard;
using Curl;

namespace DashSource {

    size_t write_curl( char* buf, size_t size, size_t nmemb, ref StringBuilder up ) {
        assert( null != buf );
        up.append( (string)buf );
        return size * nmemb;
    }

    public abstract class DashSource {
        protected Dashboard.Dashboard dashboard;
        protected string source;
        protected string host;
        protected int port;
        protected string user;
        protected string protocol;
        protected Dashboard.PasswordHolder password;
        protected bool busy = false;
        
        protected delegate void ProcessFunction( string topic, string response );

        public signal void messaged( string topic, string message );
        
        public abstract void connect_source();

        public DashSource( Dashboard.Dashboard dashboard_in, string source_in ) {
            this.dashboard = dashboard_in;
            this.source = source_in;
        }

        protected string fetch_curl( string url, string custom_request ) {
            var handle = new EasyHandle();
            handle.setopt( Option.URL, url );
            handle.setopt( Option.NOPROGRESS, 1L );
            handle.setopt( Option.USERPWD, "%s:%s".printf( this.user, this.password.password ) );

            if( null != custom_request ) {
                handle.setopt( Option.CUSTOMREQUEST, custom_request );
            }

            StringBuilder response = new StringBuilder();
            handle.setopt( Option.WRITEFUNCTION, write_curl );
            handle.setopt( Option.WRITEDATA, ref response );
            
            handle.perform();

            // TODO: Handle protocol error.

            return response.str;
        }

        protected void poll_topics( ProcessFunction proc_func, string? custom_request ) {
            debug( "polling %s://%s@%s:%d...", this.protocol, this.user, this.host, this.port );

            foreach( var dashlet in this.dashboard.dashlets ) {
                if( dashlet.source != this.source ) {
                    continue;
                }

                if( null == this.password.password ) {
                    warning( "%s@%s:%d: no password found!", this.user, this.host, this.port );
                    return;
                }

                if( this.busy ) {
                    warning( "poller busy!" );
                    return;
                }

                this.busy = true;
                var response = this.fetch_curl(
                    "%s://%s:%d/%s".printf( this.protocol, this.host, this.port, dashlet.topic ),
                    custom_request );

                proc_func( dashlet.topic, response );

                this.busy = false;
            }
        }

        protected void ask_password() {
            // Get credentials and start the connection process.
            this.password = new PasswordHolder();
            this.password.schema = new Secret.Schema(
                "info.interfinitydynamics.circuits", Secret.SchemaFlags.NONE,
                "host", Secret.SchemaAttributeType.STRING,
                "port", Secret.SchemaAttributeType.STRING,
                "user", Secret.SchemaAttributeType.STRING
            );
            this.password.attribs["host"] = this.host;
            this.password.attribs["port"] = this.port.to_string();
            this.password.attribs["user"] = this.user;
            this.password.label = "%s:%d:%s".printf( this.host, this.port, this.user );

            this.password.config_password( "Dashboard Source %s@%s:%d".printf(
                this.user, this.host, this.port ) );
        }

        public virtual void config( Json.Object config_obj ) {
            this.protocol = config_obj.get_string_member( "protocol" );
            this.host = config_obj.get_string_member( "host" );
            this.port = (int)config_obj.get_int_member( "port" );
            this.user = config_obj.get_string_member( "user" );
        }
    }
}
