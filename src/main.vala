
using Mosquitto;
using Gtk;
using Json;

public void on_message_tickets( Client m, void* data, Mosquitto.Message msg ) {
    //stdout.printf( "%s\n", msg.payload );

    var parser = new Json.Parser();

    try {
        parser.load_from_data( msg.payload, -1 );
        var msg_root = parser.get_root().get_object();
        var msg_results = msg_root.get_array_member( "results" );

        foreach( var ticket_iter in msg_results.get_elements() ) {
            var ticket_obj = ticket_iter.get_object();
            stdout.printf( "%s\n", ticket_obj.get_string_member( "subject" ) );
        }

    } catch( GLib.Error e ) {
        stderr.printf( "JSON error!\n" );
    }
}

public void on_connect( Client m, void* data, int res ) {
    stdout.printf( "connected\n" );
    m.subscribe( 0, "test", 0 );
}

public static int main( string[] args ) {

    var mqtt_host = "";
    int64 mqtt_port = 0;
    var mqtt_user = "";
    var mqtt_pass = "";

    Gtk.init( ref args );
    Mosquitto.init();

    var parser = new Json.Parser();

    try {
        parser.load_from_file( "circuits.json" );
        var config_root = parser.get_root().get_object();
        var config_mqtt = config_root.get_object_member( "mqtt" );
        
        mqtt_host = config_mqtt.get_string_member( "host" );
        mqtt_port = config_mqtt.get_int_member( "port" );
        mqtt_user = config_mqtt.get_string_member( "user" );
        mqtt_pass = config_mqtt.get_string_member( "pass" );
    } catch( GLib.Error e ) {
        stderr.printf( "JSON error!\n" );
    }

    // Mosquitto setup.
    // TODO: Set client UID from config.
    var m = new Client( "circ_test_123", true, null );
    m.connect_callback_set( on_connect );
    m.message_callback_set( on_message_tickets );
    m.username_pw_set( mqtt_user, mqtt_pass );
    m.connect( mqtt_host, (int)mqtt_port, 60 );
    //m.user_data_set( tickets )

    // Window setup.
    var window = new Window();
    var grid = new Grid();

    var tickets = new Label( "xxx" );
    grid.attach( tickets, 0, 0, 2, 1 );

    // Update Mosquitto every couple seconds. 
    GLib.Timeout.add( 2000, () => {
        var rc = m.loop( -1, 1 );
        if( 0 != rc ){
            stderr.printf( "connection error!\n" );
            m.reconnect();
        }
        return true;
    }, 0 );

    // Show the window.
    window.destroy.connect( Gtk.main_quit );
    window.show();

    Gtk.main();

    return 0;
}
