using Gee;

namespace XSRSS
{
	public class FeedManager : Object
	{
		public LinkedList<Feed> feeds = new LinkedList<Feed>();

		public FeedManager()
		{
			load_feeds_from_database();
		}

		private void load_feeds_from_database()
		{
			string sql = "SELECT feed_url FROM feeds;";
			string err_msg;
			int result = Instance.db_connection.database.exec(sql,(n_columns,values,column_names) => {
				Feed feed = new Feed(values[0]);
				feeds.add(feed);
				return 0;
			},out err_msg);
			if(!(result == Sqlite.OK || result == Sqlite.ROW))
			{
				stderr.printf("Error loading feeds from database: %s\n",err_msg);
				Posix.exit(1);
			}
			foreach(Feed feed in feeds)
			{
				feed.update();
			}
		}

		public void add_new_feed(string feed_url)
		{
			Feed feed = new Feed(feed_url);
			feeds.add(feed);
			feed.update();
		}
	}
}
