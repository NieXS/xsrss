using Gee;

namespace XSRSS
{
	public class FeedManager : Object
	{
		public LinkedList<Feed> feeds = new LinkedList<Feed>();

		public FeedManager()
		{
			// Loading feeds from the database
		}

		private void load_feeds_from_database()
		{
			string sql = "SELECT user_name, feed_url FROM feeds;";
			string err_msg;
			int result = Instance.db_connection.database.exec(sql,(n_columns,values,column_names) => {
				Feed feed = new Feed(values[0],values[1]);
				feeds.add(feed);
				return 0;
			},out err_msg);
			if(!(result == Sqlite.OK || result == Sqlite.ROW))
			{
				stderr.printf("Error loading feeds from database: %s\n",err_msg);
				Posix.exit(1);
			}
		}
	}
}
