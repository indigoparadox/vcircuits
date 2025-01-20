
// vi:syntax=cs

using Gtk;
using Json;

namespace Dashboard {

    public errordomain DashletError {
        OTHER,
        PARSE_MSG,
        UPDATE
    }

    public class DashletRESTBase : Dashlet {
        private Json.Path? path = null;
        private long max_len = 0;
        private string? template = null;
        public string? source_post = null;
        public string? accept = null;
        public string? content_type = null;

        public DashletRESTBase( Dashboard dashboard_in ) {
            base( dashboard_in );
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );

            if( config_obj.has_member( "path" ) ) {
                this.path = new Json.Path();
                bool res = false;
                try {
                    res = path.compile(
                        config_obj.get_string_member( "path" ) );
                } catch( GLib.Error e ) {
                    critical( "problem compiling path: %s: %s",
                        config_obj.get_string_member( "path" ), e.message );
                }
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

            if( config_obj.has_member( "max_len" ) ) {
                this.max_len = (long)config_obj.get_int_member( "max_len" );
            }

            if( config_obj.has_member( "source_post" ) ) {
                this.source_post =
                    config_obj.get_string_member( "source_post" );
            }
        }

        public override string? get_accept_type() {
            return this.accept;
        }

        public override string? get_content_type() {
            return this.content_type;
        }
 
        public override string? get_source_post() {
            return this.source_post;
        }
 
        protected string parse_json_path( string msg ) throws DashletError {

            debug( "parsing response: %s", msg );

            Json.Parser parser = new Json.Parser();
            try {
                parser.load_from_data( msg );
            } catch( GLib.Error e ) {
                throw new 
                    DashletError.PARSE_MSG(
                        "Invalid JSON response type: %s", e.message );
            }
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
                throw new 
                    DashletError.PARSE_MSG( "Invalid JSON response type!" );
            }

            return this.template.printf( msg_token );
        }

        protected string truncate_max_len( string msg ) {
            if( 0 < this.max_len && msg.length > this.max_len ) {
                // Limit subject length.
                return msg.substring( 0, this.max_len );
            }
            return msg;
        }

        public bool has_path() {
            return null != this.path ? true : false;
        }
    }
}
