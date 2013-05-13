using Gee;

namespace XSRSS
{
	public class Database : Object
	{
		public Sqlite.Database database;
		
		public Database()
		{
			// Making sure the database exists
			if(!FileUtils.test("xsrss.db",FileTest.EXISTS))
			{
				stderr.printf("Database does not exist! Create it manually first.\n");
				Posix.exit(1);
			}
			int result = Sqlite.Database.open("xsrss.db",out database);
			if(result != Sqlite.OK)
			{
				stderr.printf("Could not open database! %s\n",database.errmsg());
				Posix.exit(1);
			}
			run_sql("PRAGMA foreign_keys = ON;");
			// We should check if the database is sane here
		}

		public bool run_sql(string sql)
		{
			stdout.printf("Running SQL:\n\t%s\n",sql);
			string err_msg;
			int result = database.exec(sql,null,out err_msg);
			if(result != Sqlite.OK)
			{
				stderr.printf("Couldn't run SQL statement! %s\n",err_msg);
				return false;
			} else
			{
				stdout.printf("Success!\n");
				return true;
			}
		}
	}
}

