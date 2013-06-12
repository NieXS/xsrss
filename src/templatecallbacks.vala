using Gee;

namespace XSRSS
{
	public class TemplateCallbacks : Object
	{
		public class Callback
		{
			public delegate string TemplateCallback();
			public TemplateCallback callback;
			
			public Callback(owned TemplateCallback callback)
			{
				this.callback = (owned)callback;
			}
		}
		public HashMap<string,Callback> callbacks = new HashMap<string,Callback>();

		public TemplateCallbacks()
		{
			register_callback("feed_list",feed_list);
			register_callback("unread_feed_items",total_unread_items);
		}

		public void register_callback(string name,Callback.TemplateCallback callback)
		{
			Callback callback_wrapper = new Callback(callback);
			callbacks[name] = callback_wrapper;
		}

		private static string total_unread_items()
		{
			int unread = 0;
			foreach(Feed feed in Instance.feed_manager.feeds)
			{
				foreach(Feed.Item item in feed.items)
				{
					if(!item.read)
					{
						unread++;
					}
				}
			}
			return "(%d)".printf(unread);
		}

		private static string feed_list()
		{
			LinkedList<HashMap<string,string>> variables = new LinkedList<HashMap<string,string>>();
			foreach(Feed feed in Instance.feed_manager.feeds)
			{
				HashMap<string,string> feed_info = new HashMap<string,string>();
				feed_info["feedurl"] = Uri.escape_string(feed.user_name);
				feed_info["feed"] = feed.user_name;
				int unread = 0;
				foreach(Feed.Item item in feed.items)
				{
					if(!item.read)
					{
						unread++;
					}
				}
				if(unread > 0)
				{
					feed_info["unread_items"] = "(%d)".printf(unread);
				} else
				{
					feed_info["unread_items"] = "";
				}
				variables.add(feed_info);
			}
			variables.sort((CompareDataFunc<Feed>)compare_feeds_by_name);
			Template template = new Template("feed_list",false);
			template.define_foreach("feed_list_item",variables);
			return template.render();
		}

		private static int compare_feeds_by_name(Feed a,Feed b)
		{
			return a.user_name.collate(b.user_name);
		}
	}
}
