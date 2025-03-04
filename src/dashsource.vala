
// vi:syntax=cs

using Dashboard;
using Curl;

namespace DashSource {

    size_t write_curl( char* buf, size_t size, size_t nmemb, ref StringBuilder up ) {
        assert( null != buf );
        up.append( (string)buf );
        return size * nmemb;
    }

    public enum AuthType {
        PASSWORD,
        BEARER,
    }

    public errordomain UpdateError {
        OTHER,
        UNAUTHORIZED,
        NOT_FOUND,
        TIMEOUT
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
        protected AuthType auth_type = AuthType.PASSWORD;
        protected string? time_fmt = null;
        
        protected delegate void ProcessFunction(
            string topic, string response );

        public signal void messaged( string topic, string message );
        
        public abstract void connect_source();

        protected DashSource(
            Dashboard.Dashboard dashboard_in, string source_in
        ) {
            this.dashboard = dashboard_in;
            this.source = source_in;
        }

        protected string fetch_curl(
            string url, string? custom_request, string? post_data,
            string? accept, string? content_type, long timeout
        ) throws UpdateError {
            var handle = new EasyHandle();
            unowned Curl.SList headers = null;
            string bearer_str = null;
            string accept_str = null;
            string content_type_str = null;
            string post_proc = null;

            // Fill out CURL options.
            handle.setopt( Option.URL, url );
            handle.setopt( Option.NOPROGRESS, 1L );
            if( AuthType.PASSWORD == this.auth_type && null != this.user ) {
                handle.setopt( Option.USERPWD, "%s:%s".printf(
                    this.user, this.password.password ) );
            } else if( AuthType.BEARER == this.auth_type ) {
                // Format the bearer string into a header.
                bearer_str = "Authorization: Bearer %s".printf(
                    this.password.password );
                headers = Curl.SList.append( headers, bearer_str );
            }
            if( null != accept ) {
                accept_str = "Accept: %s".printf( accept );
                headers = Curl.SList.append( headers, accept_str );
            }
            if( null != content_type ) {
                content_type_str = "Content-Type: %s".printf( content_type );
                headers = Curl.SList.append( headers, content_type_str );
            }
            if( null != post_data ) {
                  if( null != this.time_fmt ) {
                      // Sub in date tokens to POST data.
                      var now = new DateTime.now_local();
                      post_proc = post_data.replace( "<now>",
                          now.format( this.time_fmt ) );
                      var now_minus_one = now.add_minutes( -1 );
                      post_proc = post_proc.replace( "<now_minus_one>",
                          now_minus_one.format( this.time_fmt ) );
                      debug( "post_proc: %s", post_proc );
                  } else {
                      post_proc = post_data;
                  }

                  handle.setopt( Option.POSTFIELDS, post_proc );
            }
            if( null != custom_request ) {
                handle.setopt( Option.CUSTOMREQUEST, custom_request );
            }
            if( null != headers ) {
                handle.setopt( Option.HTTPHEADER, headers );
            }
            if( 0 < timeout ) {
                handle.setopt( Option.TIMEOUT, timeout );
            }

            StringBuilder response = new StringBuilder();
            handle.setopt( Option.WRITEFUNCTION, write_curl );
            handle.setopt( Option.WRITEDATA, ref response );

            // TODO: Make this configurable.
            handle.setopt( Option.SSL_VERIFYPEER, false );
            handle.setopt( Option.SSL_VERIFYHOST, false );
            
            handle.perform();

            debug( "performed!" );

            if( null != headers ) {
                headers.free_all();
            }

            // Handle possible protocol error.
            long res = 0;
            handle.getinfo( Curl.Info.RESPONSE_CODE, out res );
            if( 0 == res ) {
                throw new UpdateError.TIMEOUT( "timeout!" );
            } else if( 200 != res ) {
                throw new UpdateError.OTHER( "%ld: %s", res, response.str );
            }

            return response.str;
        }

        protected void poll_topics(
            DashSource.ProcessFunction proc_func, string? custom_request
        ) {
            // I don't like having this in the DashSource base class, but
            // things like RSS and IMAP use it and it helps reduce redundant
            // code.

            // Things that are totally irrelevant and have their own polling
            // mechanisms, like MQTT, can just totally override it and call
            // those.

            foreach( var dashlet in this.dashboard.dashlets ) {
                // Don't update irrelevant dashlets.
                if( dashlet.source != this.source ) {
                    continue;
                }

                debug( "polling %s://%s@%s:%d/%s...",
                    this.protocol, this.user, this.host, this.port,
                     dashlet.topic );

                /* if( null == this.password.password ) {
                    warning( "%s@%s:%d: no password found!",
                        this.user, this.host, this.port );
                    return;
                } */

                // Busy lock.
                if( this.busy ) {
                    warning( "poller busy!" );
                    return;
                }
                this.busy = true;

                // Use CURL to fetch the response and then feed it to the
                // dashlet's processor function.
                try {
                    var response = this.fetch_curl(
                        "%s://%s:%d/%s".printf(
                            this.protocol, this.host, this.port,
                                dashlet.topic ),
                            custom_request, dashlet.get_source_post(),
                            dashlet.get_accept_type(),
                            dashlet.get_content_type(), dashlet.get_timeout() );

                    debug( "response: %s", response );

                    proc_func( dashlet.topic, response );
                } catch( UpdateError ex ) {
                    warning( "error while updating: %s", ex.message );
                }

                // Busy unlock.
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
            // TODO: Handle no user.
            this.user = config_obj.get_string_member( "user" );
            this.time_fmt = config_obj.get_string_member( "time_fmt" );
            var auth_type = config_obj.get_string_member( "auth" );
            if( "bearer" == auth_type ) {
                debug( "using bearer authentication!" );
                this.auth_type = AuthType.BEARER;
            }
        }

        public virtual void send( string topic, string message ) {
            debug( "send not implemented: %s: %s", topic, message );
        }
    }
}
