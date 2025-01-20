
// vi:syntax=cs

using Gtk;
using Json;

namespace Dashboard {
    public class DashletText : Dashlet {
        private Gtk.Label updated_label;
        private Json.Path path = null;
        private string template = null;

        public DashletText( Dashboard dashboard_in ) {
            base( dashboard_in );
        }

        private void update_label( string topic, string msg ) {
            string msg_cleaned = null;
            string msg_out = null;

            // Grab the message from JSON if necessary.
            if( null != this.path ) {
                debug( "parsing response: %s", msg );
                Json.Parser parser = new Json.Parser();
                parser.load_from_data( msg );
                // TODO: Handle parse failure.
                Json.Node msg_root = parser.get_root();
                Json.Array msg_array = this.path.match( msg_root ).get_array();
                Json.Node msg_node = msg_array.get_element( 0 );
                Type msg_type = msg_node.get_value_type();

                // TODO: Handle match failure.

                string msg_token = null;
                if( typeof( string ) == msg_type ) {
                    debug( "value type: string" );
                    msg_token = msg_node.get_string();
                } else if( typeof( double ) == msg_type ) {
                    debug( "value type: double" );
                    msg_token = "%f".printf( msg_node.get_double() );
                } else if( typeof( int ) == msg_type ) {
                    debug( "value type: int" );
                    msg_token = "%lld".printf( msg_node.get_int() );
                } else {
                    warning( "invalid type" );
                    return;
                }
                //debug( "XXX: %s", msg_node.type_name() );

                msg_out = this.template.printf( msg_token );
                debug( "msg: %s", msg_out );
            } else {
                msg_out = msg;
            }

            msg_cleaned = msg_out.replace( "<br />", "\n" );

            // Render the final message.
            this.updated_label.set_text( msg_cleaned );
        }

        public override void build( Gtk.Box box ) {
            base.build( box );
            
            this.updated_label = new Gtk.Label( "" );
            this.updated_label.set_halign( Gtk.Align.START );
            var context = this.updated_label.get_style_context();
            context.add_class( "circuits-text-text" );
            box.add( this.updated_label );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );
            
            if( config_obj.has_member( "path" ) ) {
                this.path = new Json.Path();
                var res = path.compile(
                    config_obj.get_string_member( "path" ) );
                if( !res ) {
                    error( "failed to compile path!" );
                }
            }

            if( config_obj.has_member( "accept" ) ) {
                this.accept = config_obj.get_string_member( "accept" );
            }

            if( config_obj.has_member( "content_type" ) ) {
                this.content_type =
                    config_obj.get_string_member( "content_type" );
            }

            if( config_obj.has_member( "template" ) ) {
                this.template = config_obj.get_string_member( "template" );
            }

            this.dashboard.sources.foreach( ( k, v ) => {
                // Skip non-subscribed sources.
                if( k != this.source ) {
                    return;
                }

                debug( "connecting to source: %s", k );

                v.messaged.connect( this.update_label );
            } );
        }
    }
}
