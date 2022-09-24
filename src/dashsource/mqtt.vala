
using Mosquitto;
using Gtk;
using Json;
using Secret;
using Dashboard;

namespace DashSource {

    public class DashSourceMQTT : DashSource {

        string mqtt_host;
        int mqtt_port;
        string mqtt_user;
        private Dashboard.PasswordHolder mqtt_pass;
        bool mqtt_connected = false;
        public Mosquitto.Client m;

        public static void on_message_tickets( Mosquitto.Client m, void* data, Mosquitto.Message msg ) {
            foreach( var dashlet in dashboard.dashlets ) {
                dashlet.mqtt_message( m, msg );
            }
        }

        public static void on_connect( Mosquitto.Client m, void* data, int res ) {
            info( "MQTT connected" );
            foreach( var dashlet in dashboard.dashlets ) {
                dashlet.mqtt_connect( m );
            }
        }

        public override void config( Json.Object config_obj ) {
            // Parse MQTT config.
            this.mqtt_host = config_obj.get_string_member( "host" );
            this.mqtt_port = (int)config_obj.get_int_member( "port" );
            this.mqtt_user = config_obj.get_string_member( "user" );
            debug( "configured MQTT: %s@%s:%d",
                this.mqtt_user, this.mqtt_host, this.mqtt_port );
        }

        public override void connect() {
            
            debug( "connecting MQTT: %s@%s:%d",
                this.mqtt_user, this.mqtt_host, this.mqtt_port );

            // Mosquitto setup.
            // TODO: Set client UID from config.
            this.m = new Client( "circ_test_123", true, null );
            this.m.connect_callback_set( DashSourceMQTT.on_connect );
            this.m.message_callback_set( DashSourceMQTT.on_message_tickets );

            // Get credentials and start the connection process.
            this.mqtt_pass = new PasswordHolder();
            this.mqtt_pass.schema = new Secret.Schema(
                "info.interfinitydynamics.circuits.mqtt", Secret.SchemaFlags.NONE,
                "host", Secret.SchemaAttributeType.STRING,
                "port", Secret.SchemaAttributeType.STRING,
                "user", Secret.SchemaAttributeType.STRING
            );
            this.mqtt_pass.attribs["host"] = this.mqtt_host;
            this.mqtt_pass.attribs["port"] = this.mqtt_port.to_string();
            this.mqtt_pass.attribs["user"] = this.mqtt_user;
            this.mqtt_pass.label = "%s:%d:%s".printf( this.mqtt_host, this.mqtt_port, this.mqtt_user );

            this.mqtt_pass.config_password( "MQTT Server" );

            // Update Mosquitto every couple seconds. 
            GLib.Timeout.add( 2000, () => {
                var rc = this.m.loop( -1, 1 );
                if( 0 == rc ){
                    return true;
                }

                // Connection failure or not connected!
                warning( "MQTT connection failed!" );
                if( null == this.mqtt_user || null != this.mqtt_pass.password ) {
                    info( "MQTT reconnecting (%s, %s, %d)...",
                        this.mqtt_user, this.mqtt_host, this.mqtt_port );
                    if( this.mqtt_connected ) {
                        // Reconnecting after failure. Params already in place.
                        this.m.reconnect();
                    } else {
                        // First time connection.
                        this.m.username_pw_set( this.mqtt_user, this.mqtt_pass.password );
                        this.m.connect( this.mqtt_host, (int)this.mqtt_port, 60 );
                    }
                }

                return true;
            }, 0 );
        }
    }
}
