PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS feeds;
DROP TABLE IF EXISTS items;

CREATE TABLE feeds (
	id INTEGER PRIMARY KEY,
	user_name TEXT NOT NULL,
	feed_url TEXT NOT NULL,
	title TEXT,
	description TEXT,
	link TEXT,
	image_url TEXT,
	image_link TEXT,
	image_alt_text TEXT,
	update_interval INTEGER NOT NULL
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
	author TEXT,
	read INTEGER NOT NULL
);
