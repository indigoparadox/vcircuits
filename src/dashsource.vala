
namespace DashSource {

    public abstract class DashSource {
        public abstract void config( Json.Object config_obj );
        public abstract void connect();
    }
}
