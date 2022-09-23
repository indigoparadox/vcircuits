
using Mosquitto;
using Gtk;
using Json;
using Dashboard;

Dashboard.Dashboard dashboard;

public void on_message_tickets( Mosquitto.Client m, void* data, Mosquitto.Message msg ) {
    foreach( var dashlet in dashboard.dashlets ) {
        dashlet.mqtt_message( m, msg );
    }
}

public void on_connect( Mosquitto.Client m, void* data, int res ) {
    info( "MQTT connected" );
    foreach( var dashlet in dashboard.dashlets ) {
        dashlet.mqtt_connect( m );
    }
}

public static int main( string[] args ) {

    Gtk.init( ref args );
    Mosquitto.init();

    dashboard = new Dashboard.Dashboard();

    dashboard.config( "circuits.json" );    

    dashboard.mqtt_connect();

    dashboard.build();

    Gtk.main();

    return 0;
}
