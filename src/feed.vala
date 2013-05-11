using Gee;

namespace XSRSS
{
	public class Feed : Object
	{
		public class Item
		{
			public string title = null;
			public string link = null;
			public string description = null;
			public string content = null;
			public DateTime pub_date = null;
			public string guid = null;
			public string author = null;
			public bool read = false;
		}
		public string title = null;
		public string link  = null;
		public string description = null;
		public DateTime pub_date = null;
		public DateTime last_build_date = null;
		public int update_interval = 60; // in minutes
		public string image_url = null;
		public string image_link = null;
		public string image_alt_text = null;
		public Gee.ArrayList<Item> items = new ArrayList<Item>((EqualDataFunc)item_equal_func);
		public string raw_feed_text = null;

		public bool update(string xml_text)
		{
			Xml.Doc *document = Xml.Parser.parse_doc(xml_text);
			Xml.Node *root = document->get_root_element();
			int update_frequency = 1; // <sy:updateFrequency>
			if(root == null)
			{
				stderr.printf("xml_text is empty!\n");
				delete document;
				return false;
			}
			// Selecting the <channel> tag
			Xml.Node *channel;
			for(channel = root->children;channel != null && channel->name != "channel";channel = channel->next);
			if(channel == null)
			{
				stderr.printf("Couldn't find channel tag!\n");
				delete document;
				return false;
			}
			Xml.Node *node;
			for(node = channel->children;node != null;node = node->next)
			{
				if(node->type != Xml.ElementType.ELEMENT_NODE)
				{
					continue;
				}
				string node_name = node->name;
				switch(node_name)
				{
					case "title":
						title = node->get_content();
						break;
					case "link":
						link = node->get_content();
						break;
					case "description":
						description = node->get_content();
						break;
					case "lastBuildDate":
						last_build_date = parse_text_date(node->get_content());
						break;
					case "updatePeriod":
						switch(node->get_content())
						{
							case "hourly":
								update_interval = 60;
								break;
							case "daily":
								update_interval = 60*24;
								break;
							case "weekly":
								update_interval = 60*24*7;
								break;
							case "monthly":
								update_interval = 60*24*30;
								break;
							case "yearly":
								update_interval = 60*24*365;
								break;
						}
						break;
					case "updateFrequency":
						update_frequency = int.parse(node->get_content());
						if(update_frequency > 0)
						{
							update_interval = update_interval / update_frequency;
						}
						break;
					case "item":
						stdout.printf("Found item!\n");
						Item item = new Item();
						for(Xml.Node *item_node = node->children;item_node != null;item_node = item_node->next)
						{
							string item_node_name = item_node->name;
							stdout.printf("item_node_name: %s\n",item_node_name);
							switch(item_node_name)
							{
								case "title":
									item.title = item_node->get_content();
									break;
								case "link":
									item.link = item_node->get_content();
									break;
								case "description":
									item.description = item_node->get_content();
									break;
								case "pubDate":
									item.pub_date = parse_text_date(item_node->get_content());
									break;
								case "guid":
									item.guid = item_node->get_content();
									break;
								case "encoded":
									item.content = item_node->get_content();
									break;
							}
						}
						if(!has_item_with_same_guid(item.guid))
						{
							items.add(item);
						}
						break;
				}
			}
			delete document;
			raw_feed_text = xml_text;
			return true;
		}

		public void print_data()
		{
			stdout.printf("title: %s\n",title);
			stdout.printf("description: %s\n",description);
			stdout.printf("link: %s\n",link);
			stdout.printf("lastBuildDate: %s\n",last_build_date.format("%F %T"));
			stdout.printf("update_interval: %d\n",update_interval);
			stdout.printf("\nItems:\n\n");
			foreach(Item item in items)
			{
				stdout.printf("\ttitle: %s\n",item.title);
				stdout.printf("\tlink: %s\n",item.link);
				stdout.printf("\tdescription: %s\n",item.description);
				stdout.printf("\tcontent:encoded: %s\n",item.content);
				stdout.printf("\tguid: %s\n",item.guid);
				stdout.printf("\tpubDate: %s\n",item.pub_date.format("%F %T"));
				stdout.printf("\n");
			}
		}

		// There's probably a library for this somewhere but I couldn't find it
		private DateTime? parse_text_date(string text_date)
		{
			DateTime date;
			int year, month, day, hour, minute, seconds;
			// For the sake of simplicity we'll not care about timezones and
			// just store everything as UTC
			Regex regex = null;
			MatchInfo match_info;
			try
			{
				regex = new Regex("([0-9]+) ([A-Za-z]+) ([0-9]+) ([0-9]+):([0-9]+):([0-9]+)");
			} catch(Error e)
			{
				stderr.printf("Exception while creating regex: %s\n",e.message);
				Posix.exit(1);
			}
			if(regex.match(text_date,0,out match_info))
			{
				assert(match_info.get_match_count() >= 7);
				day = int.parse(match_info.fetch(1));
				year = int.parse(match_info.fetch(3));
				hour = int.parse(match_info.fetch(4));
				minute = int.parse(match_info.fetch(5));
				seconds = int.parse(match_info.fetch(6));
				month = 0;
				switch(match_info.fetch(2).down())
				{
					case "jan":
						month = 1;
						break;
					case "feb":
						month = 2;
						break;
					case "mar":
						month = 3;
						break;
					case "apr":
						month = 4;
						break;
					case "may":
						month = 5;
						break;
					case "jun":
						month = 6;
						break;
					case "jul":
						month = 7;
						break;
					case "aug":
						month = 8;
						break;
					case "sep":
						month = 9;
						break;
					case "oct":
						month = 10;
						break;
					case "nov":
						month = 11;
						break;
					case "dec":
						month = 12;
						break;
				}
				date = new DateTime.utc(year,month,day,hour,minute,seconds);
				return date;
			} else
			{
				return null;
			}
		}
		
		private bool item_equal_func(Item a,Item b)
		{
			return a.guid == b.guid;
		}

		private bool has_item_with_same_guid(string guid)
		{
			foreach(Item item in items)
			{
				if(item.guid == guid)
				{
					return true;
				}
			}
			return false;
		}
	}
}
