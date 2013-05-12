using Gee;

namespace XSRSS
{
	int main(string[] args)
	{
		// GLib main loop will be here, with timeoutsources to get updated
		// feeds, store stuff to database, etc
		Xml.Parser.init();
		Feed test = new Feed("Ars Technica","http://feeds.arstechnica.com/arstechnica/index/");
		MainLoop main_loop = new MainLoop();
		test.update();
		main_loop.run();
		return 0;
	}
}
