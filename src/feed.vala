using Gee;

namespace XSRSS
{
	public class Feed
	{
		public class Item
		{
			public string title = null;
			public string link = null;
			public string description = null;
			public string pub_date = null;
			public string guid = null;
			public string author = null;
			public bool read = false;
		}
		public string title = null;
		public string link  = null;
		public string description = null;
		public string pub_date = null;
		public string last_build_date = null;
		public int ttl = -1;
		public string image_url = null;
		public string image_link = null;
		public string image_alt_text = null;
		public Gee.ArrayList<Item> items = new ArrayList<Item>((EqualDataFunc)item_equal_func);
		public string raw_feed_text = null;

		public bool update(string xml_text)
		{
			Xml.Doc *document = Xml.Parser.parse_doc(xml_text);
			Xml.Node *root = document->get_root_element();
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
						last_build_date = node->get_content();
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
									item.pub_date = item_node->get_content();
									break;
								case "guid":
									item.guid = item_node->get_content();
									break;
							}
						}
						if(!has_item_with_same_guid(item.guid))
						{
							items.insert(0,item);
						}
						break;
				}
			}
			delete document;
			return true;
		}

		public void print_data()
		{
			stdout.printf("title: %s\n",title);
			stdout.printf("description: %s\n",description);
			stdout.printf("link: %s\n",link);
			stdout.printf("\nItems:\n\n");
			foreach(Item item in items)
			{
				stdout.printf("\ttitle: %s\n",item.title);
				stdout.printf("\tlink: %s\n",item.link);
				stdout.printf("\tdescription: %s\n",item.description);
				stdout.printf("\tguid: %s\n",item.guid);
				stdout.printf("\n");
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

	int main(string[] args)
	{
		Xml.Parser.init();
		Feed feed = new Feed();
		string xml_feed;
		if(FileUtils.get_contents("test.xml",out xml_feed,null))
		{
			feed.update(xml_feed);
		}
		if(FileUtils.get_contents("test2.xml",out xml_feed,null))
		{
			feed.update(xml_feed);
			feed.print_data();
		}
		return 0;
	}
}
