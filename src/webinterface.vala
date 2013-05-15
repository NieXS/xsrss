using Gee;

namespace XSRSS
{
	public class WebInterface : Object
	{
		private Soup.Server server;

		public WebInterface()
		{
			server = new Soup.Server("port",9889);
			server.add_handler("/",(server, msg, path, query, client) =>
			{
				msg.set_status(Soup.KnownStatusCode.OK);
				string body = "<a href=\"/feeds\">List feeds</a>";
				msg.set_response("text/html",Soup.MemoryUse.COPY,body.data);
			});
			server.add_handler("/feeds",list_feeds);
			server.run_async();
		}

		private void list_feeds(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			Template template = new Template("list_feeds");
			template.define_variable("title","All feeds");
			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html",Soup.MemoryUse.COPY,template.render().data);
		}
	}
}
