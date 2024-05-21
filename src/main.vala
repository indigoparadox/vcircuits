
// vi:syntax=cs

using Mosquitto;
using Gtk;
using Json;
using Dashboard;

Dashboard.Dashboard dashboard;

public static int main( string[] args ) {

    Gtk.init( ref args );
    Mosquitto.init();

    dashboard = new Dashboard.Dashboard();

    dashboard.config( "circuits.json" );

    dashboard.connect_sources();

    dashboard.build();

    Gtk.main();

    return 0;
}
