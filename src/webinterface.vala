using Gee;

namespace XSRSS
{
	public class WebInterface : Object
	{
		private Soup.Server server;

		public WebInterface()
		{
			server = new Soup.Server("port",9889);
			server.request_read.connect((msg, client) => 
			{
				msg.request_headers.foreach((name, value) =>
				{
					stdout.printf("< %s: %s\n",name,value);
				});
			});
			server.add_handler("/",root_handler);
			server.add_handler("/home",home_handler);
			server.add_handler("/feeds",list_feeds);
			server.add_handler("/allfeeds",list_all_items);
			server.add_handler("/managefeeds",manage_feeds);
			server.add_handler("/static",static_files);
			server.add_handler("/feed",show_feed);
			server.add_handler("/update",update_feed);
			server.add_handler("/markasread",mark_item_as_read);
			server.add_handler("/markallasread",mark_all_items_as_read);
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
						msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"File not found".data);
					}
				} catch(Error e)
				{
					stderr.printf("Error opening file %s\n",filename);
					msg.set_status(Soup.KnownStatusCode.NOT_FOUND);
					msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"File not found".data);
				}
			} else
			{
				msg.set_status(Soup.KnownStatusCode.NOT_FOUND);
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"File not found".data);
			}
		}

		private void manage_feeds(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			Template template = new Template("manage_feeds");
			template.define_variable("title","Manage subscriptions");
			if(msg.method == "POST")
			{
				HashTable<string,string> form_data = Soup.Form.decode((string)msg.request_body.data);
				if(form_data.contains("feed_url") && form_data["feed_url"] != null && form_data["feed_url"] != "")
				{
					if(Instance.feed_manager.add_new_feed(form_data["feed_url"]))
					{
						template.define_variable("error_message","Subscription added successfully.");
					} else
					{
						template.define_variable("error_message","Failed to add feed.");
					}
				} else
				{
					template.define_variable("error_message","Please type a valid URL.");
				}
			} else
			{
				template.define_variable("error_message","");
			}
			LinkedList<HashMap<string,string>> feeds = new LinkedList<HashMap<string,string>>();
			foreach(Feed feed in Instance.feed_manager.feeds)
			{
				HashMap<string,string> variables = new HashMap<string,string>();
				variables["feed"] = feed.user_name;
				variables["feedurl"] = Uri.escape_string(feed.user_name);
				feeds.add(variables);
			}
			template.define_foreach("feed_list_manager",feeds);
			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,template.render().data);
		}

		private void home_handler(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			Template template = new Template("home");
			template.define_variable("title","Home");
			
			LinkedList<HashMap<string,string>> new_items = new LinkedList<HashMap<string,string>>();
			foreach(Feed feed in Instance.feed_manager.feeds)
			{
				feed.items.sort((CompareDataFunc<Feed.Item>)compare_item_by_reverse_pub_date);
				int unread = 0;
				foreach(Feed.Item item in feed.items)
				{
					if(!item.read)
					{
						unread++;
					}
				}
				HashMap<string,string> variables = new HashMap<string,string>();
				variables["link"] = feed.items[0].link == null ? "#" : feed.items[0].link;
				variables["title"] = feed.items[0].title == null ? "(no title)" : feed.items[0].title;
				variables["content"] = feed.items[0].description == null ? "" : feed.items[0].description;
				variables["feed_name"] = feed.user_name;
				variables["feed_unread"] = unread.to_string();
				new_items.add(variables);
			}
			template.define_foreach("home_new_list",new_items);

			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,template.render().data);
		}

		private void root_handler(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			if(path == "/")
			{
				msg.set_redirect(Soup.KnownStatusCode.FOUND,"/home");
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"<a href=\"/home\">Click here</a>".data);
			} else
			{
				// Dynamic page not found!
				msg.set_status(Soup.KnownStatusCode.NOT_FOUND);
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"Dynamic page not found!".data);
			}
		}

		private void update_feed(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			string feed_name = path.substring(8); // /update/
			stdout.printf("feed_name: %s\n",feed_name);
			bool found = false;
			if(feed_name == "")
			{
				found = true;
				foreach(Feed feed in Instance.feed_manager.feeds)
				{
					if(!feed.updating)
					{
						feed.update();
					}
				}
			} else
			{
				foreach(Feed feed in Instance.feed_manager.feeds)
				{
					if(feed.user_name == feed_name)
					{
						found = true;
						if(!feed.updating)
						{
							feed.update();
						}
						break;
					}
				}
			}
			if(found)
			{
				msg.set_status(Soup.KnownStatusCode.OK);
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"Update queued! Check back in 5-10 seconds, tops.".data);
			} else
			{
				msg.set_status(Soup.KnownStatusCode.OK);
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"Couldn't find a feed with that name!".data);
			}
		}

		private void mark_all_items_as_read(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			string feed_name = Uri.unescape_string(path.substring(15)); // /markallasread/
			stdout.printf("feed_name: %s\n",feed_name);
			bool found_feed = false;
			if(feed_name == "")
			{
				found_feed = true;
				foreach(Feed feed in Instance.feed_manager.feeds)
				{
					foreach(Feed.Item item in feed.items)
					{
						item.read = true;
					}
				}
			} else
			{
				foreach(Feed feed in Instance.feed_manager.feeds)
				{
					if(feed.user_name == feed_name)
					{
						foreach(Feed.Item item in feed.items)
						{
							item.read = true;
						}
						feed.save_data_to_database();
						found_feed = true;
						break;
					}
				}
			}
			msg.set_status(Soup.KnownStatusCode.OK);
			if(found_feed)
			{
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"All items from feed %s were marked as read successfully.".printf(feed_name).data);
			} else
			{
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"Couldn't find a feed with name %s!".printf(feed_name).data);
			}
		}

		private void mark_item_as_read(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			string item_guid = Uri.unescape_string(path.substring(12)); // /markasread/
			stdout.printf("item_guid: \"%s\"\n",item_guid);
			bool found_item = false;
			foreach(Feed feed in Instance.feed_manager.feeds)
			{
				foreach(Feed.Item item in feed.items)
				{
					if(item.guid == item_guid)
					{
						item.read = true;
						feed.save_data_to_database();
						found_item = true;
						break;
					}
				}
				if(found_item)
				{
					break;
				}
			}
			msg.set_status(Soup.KnownStatusCode.OK);
			if(found_item)
			{
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"Item marked as read successfully.".data);
			} else
			{
				msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,"Item not found!".data);
			}
		}

		private void list_all_items(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			LinkedList<Feed.Item> items = assemble_item_list(null);
			Template template = new Template("feed");
			if(items != null)
			{
				LinkedList<HashMap<string,string>> items_list = new LinkedList<HashMap<string,string>>();
				foreach(Feed.Item item in items)
				{
					HashMap<string,string> variables = new HashMap<string,string>();
					variables["title"] = item.title;
					variables["unread"] = item.read ? "" : " unread";
					variables["markasread"] = item.read ? "" : " - <a href=\"/markasread/%s\">Mark as read</a>".printf(Uri.escape_string(item.guid));
					variables["pubdate"] = item.pub_date != null ? item.pub_date.format("%F %T") : "";
					variables["link"] = item.link != null ? "<a href=\"%s\">".printf(item.link) : "";
					variables["endlink"] = item.link != null ? "</a>" : "";
					variables["text"] = item.content != null ? item.content : (item.description != null ? item.description : "");
					items_list.add(variables);
				}
				template.define_foreach("item",items_list);
			}
			template.define_variable("title","All items");
			template.define_variable("feed","Showing all items");
			if(items == null)
			{
				template.define_variable("noitems","<span class=\"noitems\">There are no items in the database.</span>");
			}
			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,template.render().data);
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
			msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,template.render().data);
		}

		private void show_feed(Soup.Server server,Soup.Message msg,string? path,HashTable<string,string>? query,Soup.ClientContext client)
		{
			string feed_name = path.substring(6);
			LinkedList<Feed.Item> items = assemble_item_list(feed_name);
			Template template = new Template("feed");
			if(items != null)
			{
				LinkedList<HashMap<string,string>> items_list = new LinkedList<HashMap<string,string>>();
				foreach(Feed.Item item in items)
				{
					HashMap<string,string> variables = new HashMap<string,string>();
					variables["title"] = item.title;
					variables["unread"] = item.read ? "" : " unread";
					variables["markasread"] = item.read ? "" : " - <a href=\"/markasread/%s\">Mark as read</a>".printf(Uri.escape_string(item.guid));
					variables["pubdate"] = item.pub_date != null ? item.pub_date.format("%F %T") : "";
					variables["link"] = item.link != null ? "<a href=\"%s\">".printf(item.link) : "";
					variables["endlink"] = item.link != null ? "</a>" : "";
					variables["text"] = item.content != null ? item.content : (item.description != null ? item.description : "");
					items_list.add(variables);
				}
				template.define_foreach("item",items_list);
			}
			bool feed_updated = true;
			foreach(Feed feed in Instance.feed_manager.feeds)
			{
				if(feed.user_name == feed_name)
				{
					feed_updated = !feed.updating;
					break;
				}
			}
			template.define_variable("title",feed_name);
			template.define_variable("feed",feed_name);
			template.define_variable("feed_uriescaped",Uri.escape_string(feed_name));
			template.define_variable("updating_text",feed_updated ? "" : "Feed is updating");
			if(items == null)
			{
				template.define_variable("noitems","<span class=\"noitems\">There are no items in this feed.</span>");
			}
			msg.set_status(Soup.KnownStatusCode.OK);
			msg.set_response("text/html; charset=UTF-8",Soup.MemoryUse.COPY,template.render().data);
		}

		private LinkedList<Feed.Item>? assemble_item_list(string? feed_name)
		{
			LinkedList<Feed.Item> item_list = new LinkedList<Feed.Item>();
			if(feed_name == null)
			{
				// Assemble the list with all items from all feeds
				foreach(Feed feed in Instance.feed_manager.feeds)
				{
					foreach(Feed.Item item in feed.items)
					{
						item_list.add(item);
					}
				}
			} else
			{
				bool found_feed = false;
				foreach(Feed feed in Instance.feed_manager.feeds)
				{
					if(feed.user_name == feed_name)
					{
						found_feed = true;
						foreach(Feed.Item item in feed.items)
						{
							item_list.add(item);
						}
						break;
					}
				}
				if(!found_feed)
				{
					return null;
				}
			}
			item_list.sort((CompareDataFunc<Feed.Item>)compare_item_by_reverse_pub_date);
			return item_list;
		}

		private static int compare_item_by_reverse_pub_date(Feed.Item a,Feed.Item b)
		{
			return -a.pub_date.compare(b.pub_date);
		}

	}
}
