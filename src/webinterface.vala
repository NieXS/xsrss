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
			server.add_handler("/static",static_files);
			server.add_handler("/feed",show_feed);
			server.run_async();
		}

		private void static_files(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			// We should probably sanitize the path here to make sure it
			// doesn't go anywhere above static/
			string filename = path.substring(1);
			if(FileUtils.test(filename,FileTest.EXISTS))
			{
				// This probably only handles smallish files that can be read
				// fully into memory
				try
				{
					uint8[] file_data;
					if(FileUtils.get_data(filename,out file_data))
					{
						bool result_uncertain;
						string mime_type = ContentType.guess(filename,file_data,out result_uncertain);
						stdout.printf("mime-type: %s%s\n",mime_type,result_uncertain ? ", guessed" : "");
						msg.set_status(Soup.KnownStatusCode.OK);
						msg.set_response(mime_type,Soup.MemoryUse.COPY,file_data);
					} else
					{
						stderr.printf("Could not read file %s\n",filename);
						msg.set_status(Soup.KnownStatusCode.NOT_FOUND);
						msg.set_response("text/html",Soup.MemoryUse.COPY,"File not found".data);
					}
				} catch(Error e)
				{
					stderr.printf("Error opening file %s\n",filename);
					msg.set_status(Soup.KnownStatusCode.NOT_FOUND);
					msg.set_response("text/html",Soup.MemoryUse.COPY,"File not found".data);
				}
			} else
			{
				msg.set_status(Soup.KnownStatusCode.NOT_FOUND);
				msg.set_response("text/html",Soup.MemoryUse.COPY,"File not found".data);
			}
		}

		private void list_feeds(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			Template template = new Template("list_feeds");
			template.define_variable("title","All feeds");
			template.define_variable("numfeeds",Instance.feed_manager.feeds.size.to_string());
			StringBuilder feed_list = new StringBuilder();
			foreach(Feed feed in Instance.feed_manager.feeds)
			{
				feed_list.append("<li><a href=\"/feed/%s\">%s</a></li>\n".printf(feed.user_name,feed.user_name));
			}
			template.define_variable("feeds",feed_list.str);
			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html",Soup.MemoryUse.COPY,template.render().data);
		}

		private void show_feed(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			string feed_name = path.substring(6);

			Template template = new Template("feed");
			template.define_variable("title",feed_name);
			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html",Soup.MemoryUse.COPY,template.render().data);
		}
	}
}
