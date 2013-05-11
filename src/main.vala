using Gee;

namespace XSRSS
{
	int main(string[] args)
	{
		// GLib main loop will be here, with timeoutsources to get updated
		// feeds, store stuff to database, etc
		Xml.Parser.init();
		Feed test = new Feed();
		string xml;
		try
		{
			if(FileUtils.get_contents("test.xml",out xml))
			{
				test.update(xml);
				test.print_data();
			}
		} catch(Error e) {}
		return 0;
	}
}
