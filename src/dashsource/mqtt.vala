
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
        string mqtt_uid;
        private Dashboard.PasswordHolder mqtt_pass;
        bool mqtt_connected = false;
        public Mosquitto.Client m;

        public DashSourceMQTT( Dashboard.Dashboard dashboard_in, string source_in ) {
            this.dashboard = dashboard_in;
            this.source = source_in;
        }

        public override void config( Json.Object config_obj ) {
            // Parse MQTT config.
            this.mqtt_uid = config_obj.get_string_member( "uid" );
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
            this.m = new Client( this.mqtt_uid, true, null );
            this.m.user_data_set( this );
            this.m.connect_callback_set( ( m, data, res ) => {
                DashSourceMQTT mqtt = (DashSourceMQTT)data;
                debug( "%s connected", mqtt.source );
                foreach( var dashlet in mqtt.dashboard.dashlets ) {
                    if( dashlet.source == mqtt.source ) {
                        mqtt.m.subscribe( 0, dashlet.topic, 0 );
                    }
                }
            } );
            this.m.message_callback_set( ( m, data, msg ) => {
                DashSourceMQTT mqtt = (DashSourceMQTT)data;
                debug( "%s message received on topic %s: %s",
                    mqtt.source, msg.topic, msg.payload );
                mqtt.messaged( msg.topic, msg.payload );
            } );

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
