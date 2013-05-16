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
			server.run_async();
		}

		private void list_feeds(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			Template template = new Template("list_feeds");
			template.define_variable("title","All feeds");
			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html",Soup.MemoryUse.COPY,template.render().data);
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
	}
}
