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
		public string user_name;
		public string feed_url;
		public int id;
		public string title = null;
		public string link  = null;
		public string description = null;
		public DateTime pub_date = null;
		public DateTime last_build_date = null;
		public int update_interval = 1;
		public string image_url = null;
		public string image_link = null;
		public string image_alt_text = null;
		public Gee.ArrayList<Item> items = new ArrayList<Item>((EqualDataFunc)item_equal_func);
		public string raw_feed_text = null;
		private Soup.Session soup_session;
		public bool updating = false;
		private TimeoutSource update_source = null;

		public Feed(string feed_url)
		{
			user_name = null;
			this.feed_url = feed_url;
			soup_session = new Soup.SessionAsync();
			Soup.Logger logger = new Soup.Logger(Soup.LoggerLogLevel.HEADERS,-1);
			soup_session.add_feature(logger);
			soup_session.add_feature_by_type(typeof(Soup.ProxyResolverDefault));
			if(!load_database_data())
			{
				stdout.printf("Feed \"%s\" has no data in database!\n",feed_url);
			}
			update_timeout_source();
		}

		~Feed()
		{
			if(update_source != null)
			{
				update_source.destroy();
			}
		}

		private void update_timeout_source()
		{
			if(update_source != null)
			{
				update_source.destroy();
			}
			update_source = new TimeoutSource.seconds(update_interval*60);
			update_source.set_callback(() =>
			{
				// Just checking if we should be alive or not
				if(!Instance.feed_manager.feeds.contains(this))
				{
					stdout.printf("We should be dead, quitting\n");
					return false;
				}
				stdout.printf("Updating feed %s\n",user_name);
				update();
				return true;
			});
			update_source.attach(null);
		}

		private bool load_database_data()
		{
			string sql = "SELECT title, description, link, image_url, image_link, image_alt_text, update_interval, id FROM feeds WHERE feed_url = '%s';".printf(feed_url);
			bool has_data = false;
			string err_msg;
			int id = -1;
			int result = Instance.db_connection.database.exec(sql,(n_columns,values,column_names) => {
				has_data = true;
				title = values[0];
				description = values[1];
				link = values[2];
				image_url = values[3];
				image_link = values[4];
				image_alt_text = values[5];
				update_interval = int.parse(values[6]);
				id = values[7] != null ? int.parse(values[7]) : 60;
				return 0;
			},out err_msg);
			if(!(result == Sqlite.OK || result == Sqlite.ROW))
			{
				stderr.printf("Error running query! D: %s\n",err_msg);
				return false;
			}
			sql = "SELECT guid, title, description, link, content, pub_date, author, read FROM items WHERE feed_id = '%d'".printf(id);
			result = Instance.db_connection.database.exec(sql,(n_columns,values,column_names) => {
				Item item = new Item();
				item.guid = values[0];
				item.title = values[1];
				item.description = values[2];
				item.link = values[3];
				item.content = values[4];
				string[] split_date = values[5].split(" ");
				if(split_date != null)
				{
					string[] date = split_date[0].split("-");
					string[] time = split_date[1].split(":");
					item.pub_date = new DateTime.utc(int.parse(date[0]),int.parse(date[1]),int.parse(date[2]),int.parse(time[0]),int.parse(time[1]),int.parse(time[2]));
				} else
				{
					item.pub_date = null;
				}
				item.author = values[6];
				item.read = int.parse(values[7]) == 1;
				if(!has_item_with_same_guid(item.guid))
				{
					items.add(item);
				} else
				{
					stdout.printf("Item with same guid \"%s\" already in memory\n",item.guid);
				}
				return 0;
			},out err_msg);
			if(!(result == Sqlite.OK || result == Sqlite.ROW))
			{
				stderr.printf("Error while loading items! %s\n",err_msg);
				return false;
			}
			return has_data;
		}

		public bool save_data_to_database()
		{
			string sql = "SELECT * FROM feeds WHERE user_name = '%s';".printf(user_name);
			bool has_data = false;
			string err_msg;
			int result = Instance.db_connection.database.exec(sql,(n_columns,values,column_names) => {
				has_data = true;
				return 0;
			},out err_msg);
			if(!(result == Sqlite.OK || result == Sqlite.ROW))
			{
				stderr.printf("Error running query! D: %s\n",err_msg);
				return false;
			}
			if(has_data)
			{
				sql = "UPDATE feeds SET user_name = ?, feed_url = ?, title = ?, description = ?, link = ?, update_interval = ? WHERE user_name = '%s';".printf(user_name);
			} else
			{
				sql = "INSERT INTO feeds (user_name, feed_url, title, description, link, update_interval) VALUES (?,?,?,?,?,?);";
			}
			Sqlite.Statement statement;
			if(Instance.db_connection.database.prepare_v2(sql,-1,out statement) == Sqlite.OK)
			{
				statement.bind_text(1,user_name,-1);
				statement.bind_text(2,feed_url,-1);
				statement.bind_text(3,title,-1);
				statement.bind_text(4,description,-1);
				statement.bind_text(5,link,-1);
				statement.bind_int(6,update_interval);
				stdout.printf("Running SQL:\n\t%s\n",statement.sql());
				switch(statement.step())
				{
					case Sqlite.ROW:
					case Sqlite.DONE:
						stdout.printf("Saved feed information successfully.\n");
						save_items_to_database();
						return true;
						break;
					case Sqlite.MISUSE:
						stderr.printf("Sqlite.MISUSE happened!\n");
						Posix.exit(1);
						break;
					default:
						stderr.printf("Something went wrong! %s\n",Instance.db_connection.database.errmsg());
						return false;
						break;
				}
			} else
			{
				stderr.printf("Error saving data! %s\n",Instance.db_connection.database.errmsg());
				Posix.exit(1);
			}
			return true;
		}

		private void save_items_to_database()
		{
			// Since this is being called from save_data_to_database we are
			// guaranteed to have a row in the feeds table
			string sql = "SELECT id FROM feeds WHERE user_name = '%s';".printf(user_name);
			int id = -1;
			string err_msg;
			int result = Instance.db_connection.database.exec(sql,(n_columns,values,column_names) => {
				id = int.parse(values[0]);
				return 0;
			},out err_msg);
			if(!(result == Sqlite.OK || result == Sqlite.ROW))
			{
				stderr.printf("Error running query! D: %s\n",err_msg);
				Posix.exit(1);
			}
			stdout.printf("Our database id: %d\n",id);
			foreach(Item item in items)
			{
				sql = "SELECT guid, read FROM items WHERE guid = '%s';".printf(item.guid);
				bool found = false;
				bool read = false;
				result = Instance.db_connection.database.exec(sql,(n_columns,values,column_names) => {
					found = true;
					read = int.parse(values[1]) == 1 ? true : false;
					return 0;
				},out err_msg);
				if(!(result == Sqlite.OK || result == Sqlite.ROW))
				{
					stderr.printf("Error running query! D: %s\n",err_msg);
					Posix.exit(1);
				}
				if(found)
				{
					if(item.read != read)
					{
						sql = "UPDATE items SET guid = ?, feed_id = ?, title = ?, link = ?, description = ?, content = ?, pub_date = ?, author = ?, read = ? WHERE guid = ?;";
						Sqlite.Statement statement;
						if(Instance.db_connection.database.prepare_v2(sql,-1,out statement) == Sqlite.OK)
						{
							statement.bind_text(1,item.guid,-1);
							statement.bind_int(2,id);
							statement.bind_text(3,item.title,-1);
							statement.bind_text(4,item.link,-1);
							statement.bind_text(5,item.description,-1);
							statement.bind_text(6,item.content,-1);
							statement.bind_text(7,item.pub_date.format("%F %T"),-1);
							statement.bind_text(8,item.author,-1);
							statement.bind_int(9,item.read ? 1 : 0);
							statement.bind_text(10,item.guid,-1);
							switch(statement.step())
							{
								case Sqlite.ROW:
								case Sqlite.DONE:
									stdout.printf("Updated item with guid \"%s\" successfully.\n",item.guid);
									break;
								case Sqlite.MISUSE:
									stderr.printf("Sqlite.MISUSE happened!\n");
									Posix.exit(1);
									break;
								default:
									stderr.printf("Something went wrong! %s\n",Instance.db_connection.database.errmsg());
									return;
									break;
							}
						} else
						{
							stderr.printf("Error preparing statement! %s\n",Instance.db_connection.database.errmsg());
							Posix.exit(1);
						}
					} else
					{
						stdout.printf("Skipping up to date item with guid %s\n",item.guid);
					}
				} else
				{
					sql = "INSERT INTO items (guid, feed_id, title, link, description, content, pub_date, author, read) VALUES (?,?,?,?,?,?,?,?,?);";
					Sqlite.Statement statement;
					if(Instance.db_connection.database.prepare_v2(sql,-1,out statement) == Sqlite.OK)
					{
						statement.bind_text(1,item.guid,-1);
						statement.bind_int(2,id);
						statement.bind_text(3,item.title,-1);
						statement.bind_text(4,item.link,-1);
						statement.bind_text(5,item.description,-1);
						statement.bind_text(6,item.content,-1);
						statement.bind_text(7,item.pub_date.format("%F %T"),-1);
						statement.bind_text(8,item.author,-1);
						statement.bind_int(9,item.read ? 1 : 0);
						switch(statement.step())
						{
							case Sqlite.ROW:
							case Sqlite.DONE:
								stdout.printf("Saved item with guid \"%s\" successfully.\n",item.guid);
								break;
							case Sqlite.MISUSE:
								stderr.printf("Sqlite.MISUSE happened!\n");
								Posix.exit(1);
								break;
							default:
								stderr.printf("Something went wrong! %s\n",Instance.db_connection.database.errmsg());
								return;
								break;
						}
					} else
					{
						stderr.printf("Error preparing statement! %s\n",Instance.db_connection.database.errmsg());
						Posix.exit(1);
					}
				}
			}
		}

		private bool parse_xml(string xml_text)
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
						user_name = node->get_content();
						// This is supposed to be temporary since we shouldn't need
						// a name for subscriptions, only the feed url
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
						if(item.guid == null)
						{
							item.guid = item.link;
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

		public void update()
		{
			updating = true;
			Soup.Message message = new Soup.Message("GET",feed_url);
			soup_session.queue_message(message,process_message);
		}

		public bool sync_update()
		{
			Soup.Session sync_session = new Soup.Session();
			Soup.Message message = new Soup.Message("GET",feed_url);
			uint status_code = sync_session.send_message(message);
			if(status_code == Soup.KnownStatusCode.OK)
			{
				stdout.printf("Got message, trying to parse now\n");
				if(parse_xml((string)message.response_body.data))
				{
					stdout.printf("XML parsed successfully, we're good\n");
					return true;
				} else
				{
					stderr.printf("Couldn't parse XML!\n");
					return false;
				}
			} else
			{
				stderr.printf("Got non-200 status code: %d\n",(int)status_code);
				return false;
			}
		}

		private void process_message(Soup.Session session,Soup.Message message)
		{
			if(message.status_code == Soup.KnownStatusCode.OK)
			{
				stdout.printf("Success!\n");
				Soup.MessageBody message_body = message.response_body;
				parse_xml((string)message_body.data);
				updating = false;
				save_data_to_database();
			} else
			{
				stdout.printf("Failed! reason_phrase: %s\n",message.reason_phrase);
				updating = false;
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
