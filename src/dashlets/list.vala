
// vi:syntax=cs

using Gtk;
using Json;

namespace Dashboard {
    public class DashletList : Dashlet {
        public Gtk.ListBox listbox;
        public string item_class;
        private List<string> fields;
        private List<string> class_fields;
        private long max_len = 0;

        public DashletList( Dashboard dashboard_in ) {
            base( dashboard_in );
            this.fields = new List<string>();
            this.class_fields = new List<string>();
        }

        private void parse_items( string topic, string msg ) {
            
            if( this.topic != topic ) {
                return;
            }

            var parser = new Json.Parser();

            // Clear this widget's listbox before starting.
            foreach( var child in this.listbox.get_children() ) {
                child.destroy();
            }

            //try {
            parser.load_from_data( msg, -1 );
            var msg_root = parser.get_root().get_array();

            foreach( Json.Node item_iter in msg_root.get_elements() ) {
                // Get item properties.
                var item_obj = item_iter.get_object();
                StringBuilder item_subject = new StringBuilder( "" );

                /*
                item_subject.printf(
                    "[%d] %s",
                    (int)item_obj.get_int_member( "id" ),
                    item_obj.get_string_member( "subject" )
                        .replace( "\n", " " )
                        .replace( "\r", " " ) );
                */
                foreach( string field in this.fields ) {
                    string field_cts = item_obj.get_string_member( field );
                    if(
                        0 < this.max_len &&
                        field_cts.length > this.max_len
                    ) {
                        // Limit subject length.
                        field_cts = field_cts.substring( 0, this.max_len );
                    }
                    item_subject.append( field_cts );
                }
                debug( "found item: %s", item_subject.str );

                // Add even non-displayed fields as classes for styling.
                Label subject_lbl = new Label( item_subject.str );
                var context = subject_lbl.get_style_context();
                /* foreach( string field in item_obj.get_members() ) {
                   StringBuilder field_class = new StringBuilder();
                   field_class.printf( "circuits-list-field-%s", field );
                   context.add_class( field_class.str );
                } */
                foreach( string field in this.class_fields ) {
                    StringBuilder field_class = new StringBuilder( "" );
                    string field_cts = item_obj.get_string_member( field );
                    field_class.printf(
                        "circuits-list-field-%s-%s", field, field_cts );
                    context.add_class( field_class.str.ascii_down() );
                    debug( "found class: %s", field_class.str );
                }

                // Add item to listbox.
                subject_lbl.set_halign( Gtk.Align.START );
                this.listbox.add( subject_lbl );
                this.listbox.show_all();
            }

            /*
            } catch( GLib.Error e ) {
                critical( "JSON error: %s", e.message );
            }
            */
        }

        public override void build( Gtk.Box box ) {
            base.build( box );
            
            this.listbox = new ListBox();
            var context = this.listbox.get_style_context();
            context.add_class( "circuits-list-items" );
            context.add_class( this.item_class );
            box.add( this.listbox );
        }

        private void load_list(
            Json.Array list_in, ref List<string> list_out
        ) {
            foreach( Json.Node input_iter in list_in.get_elements() ) {
                string field = input_iter.dup_string();
                debug( "field iter: %s", field );
                list_out.append( field );
            }
        }

        public override void config( Json.Object config_obj ) {
            base.config( config_obj );
            
            debug( "topic: %s", this.topic );

            this.item_class = config_obj.get_string_member( "item_class" );

            this.max_len = (long)config_obj.get_int_member( "max_len" );

            // TODO: Handle stored list.
            this.load_list(
                config_obj.get_array_member( "fields" ),
                ref this.fields );

            // TODO: Handle stored list.
            this.load_list(
                config_obj.get_array_member( "class_fields" ),
                ref this.class_fields );

            this.dashboard.sources.foreach( ( k, v ) => {
                // Skip non-subscribed sources.
                if( k != this.source ) {
                    return;
                }

                v.messaged.connect( this.parse_items );
            } );
        }
    }
}
