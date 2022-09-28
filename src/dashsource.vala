
using Dashboard;

namespace DashSource {

    public abstract class DashSource {
        protected Dashboard.Dashboard dashboard;
        protected string source;
        protected string host;
        protected int port;
        protected string user;
        protected Dashboard.PasswordHolder password;

        public signal void messaged( string topic, string message );
        
        public abstract void connect_source();

        public DashSource( Dashboard.Dashboard dashboard_in, string source_in ) {
            this.dashboard = dashboard_in;
            this.source = source_in;
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
            this.host = config_obj.get_string_member( "host" );
            this.port = (int)config_obj.get_int_member( "port" );
            this.user = config_obj.get_string_member( "user" );
        }
    }
}
