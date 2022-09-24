
namespace DashSource {

    public abstract class DashSource {
        public Dashboard.Dashboard dashboard;
        public string source;

        public signal void messaged( string topic, string message );
        
        public abstract void config( Json.Object config_obj );
        public abstract void connect();
    }
}
