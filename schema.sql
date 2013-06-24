PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS feeds;
DROP TABLE IF EXISTS items;

CREATE TABLE feeds (
	id INTEGER PRIMARY KEY,
	user_name TEXT NOT NULL,
	feed_url TEXT NOT NULL,
	title TEXT,
	description TEXT,
	link TEXT
);

CREATE TABLE items (
	id INTEGER PRIMARY KEY,
	guid TEXT UNIQUE NOT NULL,
	feed_id INTEGER NOT NULL REFERENCES feeds(id),
	title TEXT,
	link TEXT,
	description TEXT,
	content TEXT,
	pub_date TEXT,
	read INTEGER NOT NULL
);
