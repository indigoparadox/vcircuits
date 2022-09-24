
using Mosquitto;
using Gtk;
using Json;
using Secret;

namespace Dashboard {

    public class PasswordHolder {
        public Secret.Schema schema;
        public GLib.HashTable<string, string> attribs;
        public string password;
        public string label;

        public PasswordHolder() {
            this.schema = null;
            this.attribs = new GLib.HashTable<string, string>( str_hash, str_equal );
            this.password = null;
            this.label = null;
        }

        public void config_password( string title ) {
            Secret.password_lookupv.begin(
                this.schema, this.attribs, null,
                ( obj, async_res ) => {
                    try {
                        this.password = Secret.password_lookup.end( async_res );
                    } catch( GLib.Error e ) {
                        warning( "unable to retrieve password %s: %s",
                            this.label, e.message );
                    }
                    if( null != this.password ) {
                        return;
                    }

                    // Build password entry dialog.
                    var pass_window = new Gtk.Window();
                    var pass_grid = new Gtk.Grid();
                    pass_grid.set_row_spacing( 10 );

                    var pass_lbl = new Gtk.Label( "Please enter the password for %s:".printf( title ) );
                    pass_grid.attach( pass_lbl, 0, 0, 4, 1 );

                    var pass_txt = new Gtk.Entry();
                    pass_grid.attach( pass_txt, 0, 1, 4, 1 );

                    var ok_btn = new Gtk.Button();
                    ok_btn.set_label( "OK" );
                    ok_btn.clicked.connect( ( b ) => {
                        this.password = pass_txt.get_text();
                        Secret.password_storev.begin(
                            this.schema, this.attribs, Secret.COLLECTION_DEFAULT,
                            this.label, this.password, null,
                            ( obj, async_res ) => {
                                try {
                                    if( !Secret.password_store.end( async_res ) ) {
                                        critical( "unable to store password!" );
                                    }
                                } catch( GLib.Error e ) {
                                    critical( "unable to store password %s: %s",
                                        this.label, e.message );
                                }
                            } );
                        pass_window.destroy();
                    } );
                    pass_grid.attach( ok_btn, 1, 2, 1, 1 );

                    var cancel_btn = new Gtk.Button();
                    cancel_btn.set_label( "Cancel" );
                    cancel_btn.clicked.connect( ( b ) => {
                        pass_window.destroy();
                    } );
                    pass_grid.attach( cancel_btn, 2, 2, 1, 1 );

                    pass_window.set_title( title );
                    pass_window.add( pass_grid );
                    pass_window.show_all();
                }
            );
        }
    }
}
