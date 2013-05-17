using Gee;

namespace XSRSS
{
	namespace Instance
	{
		public Database db_connection;
		public MainLoop main_loop;
		public FeedManager feed_manager;
		public WebInterface web_interface;
		public TemplateCallbacks template_callbacks;
	}
	int main(string[] args)
	{
		// GLib main loop will be here, with timeoutsources to get updated
		// feeds, store stuff to database, etc
		Xml.Parser.init();
		Instance.db_connection = new Database();
		Instance.main_loop = new MainLoop();
		Instance.feed_manager = new FeedManager();
		Instance.template_callbacks = new TemplateCallbacks();
		Instance.web_interface = new WebInterface();
		Instance.main_loop.run();
		return 0;
	}
}
