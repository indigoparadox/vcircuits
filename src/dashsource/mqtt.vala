
using Mosquitto;
using Gtk;
using Json;
using Dashboard;

namespace DashSource {

    public class DashSourceMQTT : DashSource {

        string mqtt_uid;
        bool mqtt_connected = false;
        public Mosquitto.Client m;

        public DashSourceMQTT( Dashboard.Dashboard dashboard_in, string source_in ) {
            base( dashboard_in, source_in );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            // Parse MQTT config.
            this.mqtt_uid = config_obj.get_string_member( "uid" );
            debug( "configured MQTT: %s@%s:%d",
                this.user, this.host, this.port );
        }

        public override void connect_source() {
            
            debug( "connecting MQTT: %s@%s:%d",
                this.user, this.host, this.port );

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
                //debug( "%s message received on topic %s: %s",
                //    mqtt.source, msg.topic, msg.payload );
                mqtt.messaged( msg.topic, msg.payload );
            } );

            this.ask_password();

            // Update Mosquitto every couple seconds. 
            GLib.Timeout.add( 2000, () => {
                var rc = this.m.loop( -1, 1 );
                if( 0 == rc ){
                    return true;
                }

                // Connection failure or not connected!
                warning( "MQTT connection failed!" );
                if( null == this.user || null != this.password.password ) {
                    info( "MQTT reconnecting (%s, %s, %d)...",
                        this.user, this.host, this.port );
                    if( this.mqtt_connected ) {
                        // Reconnecting after failure. Params already in place.
                        this.m.reconnect();
                    } else {
                        // First time connection.
                        this.m.username_pw_set( this.user, this.password.password );
                        this.m.connect( this.host, (int)this.port, 60 );
                    }
                }

                return true;
            }, 0 );
        }
    }
}
