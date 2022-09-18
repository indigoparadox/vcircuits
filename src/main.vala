
using Mosquitto;
using Gtk;
using Json;

List<Dashlet> dashlets = null;

public class Dashlet {
    public string title;
    public string background;
    public string foreground;
}

public class DashletZendesk : Dashlet {
    public string topic;
    public ListBox listbox;
}

public void parse_tickets( string msg, DashletZendesk dashlet_zd ) {

    var parser = new Json.Parser();

    // Clear this widget's listbox before starting.
    foreach( var child in dashlet_zd.listbox.get_children() ) {
        child.destroy();
    }

    try {
        parser.load_from_data( msg, -1 );
        var msg_root = parser.get_root().get_object();
        var msg_results = msg_root.get_array_member( "results" );

        foreach( var ticket_iter in msg_results.get_elements() ) {
            // Get ticket properties.
            var ticket_obj = ticket_iter.get_object();
            var ticket_subject = ticket_obj.get_string_member( "subject" );
            stdout.printf( "%s\n", ticket_subject );

            // Add ticket to listbox.
            dashlet_zd.listbox.add( new Label( ticket_subject ) );
            dashlet_zd.listbox.show_all();
        }

    } catch( GLib.Error e ) {
        stderr.printf( "JSON error: %s\n", e.message );
    }
}

public void on_message_tickets( Client m, void* data, Mosquitto.Message msg ) {
    foreach( var dashlet in dashlets ) {
        if( dashlet is DashletZendesk ) {
            DashletZendesk dashlet_zd = dashlet as DashletZendesk;
            if( dashlet_zd.topic != msg.topic ) {
                continue;
            }

            parse_tickets( msg.payload, dashlet_zd );
        }
    }
}

public void on_connect( Client m, void* data, int res ) {
    stdout.printf( "connected\n" );
    foreach( var dashlet in dashlets ) {
        if( dashlet is DashletZendesk ) {
            DashletZendesk dashlet_zd = dashlet as DashletZendesk;
            stdout.printf( "subscribing to: %s\n", dashlet_zd.topic );
            m.subscribe( 0, dashlet_zd.topic, 0 );
        }
    }
}

public Gtk.Window build_dashboard( Gtk.Window window ) {
    // Window setup.
    var grid = new Grid();
    int y_iter = 0;

    foreach( var dashlet in dashlets ) {
        var label = new Label( dashlet.title );
        grid.attach( label, 0, y_iter, 2, 1 );
        y_iter++;
        var style = new Gtk.CssProvider();
        try {
            style.load_from_data( "* {background: %s; color: %s}".printf(
                dashlet.background, dashlet.foreground ) );
        } catch( GLib.Error e ) {
            stderr.printf( "style error: %s\n", e.message );
        }

        // Dashlet-specific widgets.
        if( dashlet is DashletZendesk ) {
            DashletZendesk dashlet_zd = dashlet as DashletZendesk;
            dashlet_zd.listbox = new ListBox();
            dashlet_zd.listbox.get_style_context().add_provider( style, Gtk.STYLE_PROVIDER_PRIORITY_USER );
            grid.attach( dashlet_zd.listbox, 0, y_iter, 2, 2 );
            y_iter += 2;
        }
    }

    window.add( grid );
    window.destroy.connect( Gtk.main_quit );

    return window;
}

public static int main( string[] args ) {

    var mqtt_host = "";
    int64 mqtt_port = 0;
    var mqtt_user = "";
    var mqtt_pass = "";
    var background_str = "";
    Gtk.Window window = null;
    
    dashlets = new List<Dashlet>();

    Gtk.init( ref args );
    Mosquitto.init();

    var parser = new Json.Parser();

    window = new Gtk.Window();

    try {
        parser.load_from_file( "circuits.json" );
        var config_root = parser.get_root().get_object();

        // Parse general config.
        var config_options = config_root.get_object_member( "options" );
        int dash_w = (int)config_options.get_int_member( "width" );
        int dash_h = (int)config_options.get_int_member( "height" );
        window.set_default_size( dash_w, dash_h );

        background_str = config_options.get_string_member( "background" );
        
        // Parse Dashlet config.
        var config_dashboard = config_root.get_array_member( "dashboard" );
        foreach( var dashlet_iter in config_dashboard.get_elements() ) {
            var dashlet_obj = dashlet_iter.get_object();
            Dashlet dashlet_out = null;

            stdout.printf( "dashlet: %s\n", dashlet_obj.get_string_member( "type" ) );
            switch( dashlet_obj.get_string_member( "type" ) ) {
            case "zendesk":
                dashlet_out = new DashletZendesk();
                DashletZendesk dashlet_out_zd = dashlet_out as DashletZendesk;
                dashlet_out_zd.topic = dashlet_obj.get_string_member( "topic" );
                stdout.printf( "topic: %s\n", dashlet_out_zd.topic );
                dashlets.append( dashlet_out );
                break;
            }

            if( null != dashlet_out ) {
                dashlet_out.title = dashlet_obj.get_string_member( "title" );
                dashlet_out.background = dashlet_obj.get_string_member( "background" );
                dashlet_out.foreground = dashlet_obj.get_string_member( "foreground" );
            }
        }

        // Parse MQTT config.
        var config_mqtt = config_root.get_object_member( "mqtt" );
        mqtt_host = config_mqtt.get_string_member( "host" );
        mqtt_port = config_mqtt.get_int_member( "port" );
        mqtt_user = config_mqtt.get_string_member( "user" );
        mqtt_pass = config_mqtt.get_string_member( "pass" );
    } catch( GLib.Error e ) {
        stderr.printf( "JSON error: %s\n", e.message );
    }

    // Mosquitto setup.
    // TODO: Set client UID from config.
    var m = new Client( "circ_test_123", true, null );
    m.connect_callback_set( on_connect );
    m.message_callback_set( on_message_tickets );
    m.username_pw_set( mqtt_user, mqtt_pass );
    m.connect( mqtt_host, (int)mqtt_port, 60 );

    // Update Mosquitto every couple seconds. 
    GLib.Timeout.add( 2000, () => {
        var rc = m.loop( -1, 1 );
        if( 0 != rc ){
            stderr.printf( "connection error!\n" );
            m.reconnect();
        }
        return true;
    }, 0 );

    build_dashboard( window );

    try {
        var style = new Gtk.CssProvider();
        style.load_from_data( "* {background: %s}".printf(
            background_str ) );
        window.get_style_context().add_provider( style, Gtk.STYLE_PROVIDER_PRIORITY_USER );
    } catch( GLib.Error e ) {
        stderr.printf( "style error: %s\n", e.message );
    }
    
    //window.set_decorated( false );
    window.show_all();

    Gtk.main();

    return 0;
}
