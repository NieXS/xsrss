xsrss
=====
xsrss is an RSS reader with the aim of being a Google Reader clone that you run
on your machine instead of accessing it from the cloud, though by virtue of
having a web frontend this could change in the future. Still very much a work-
in-progress and you probably shouldn't use this as your primary reader if you
care about your RSS history (yet).

Installation
============
xsrss is written in Vala, and it depends on Vala (for compilation only),
libgee, libsoup, libxml2, sqlite3, glib, and Python (also only during
compilation).

Building it is the same as building most other waf-using programs:
	$ ./waf configure
	$ ./waf build
There is no install target yet.

Running
=======
Firstly, create the sqlite database, which should be in the current working
directory when running the app:
	$ sqlite3 xsrss.db < schema.sql
Secondly, run the application:
	$ build/src/xsrss
Finally, access it by opening `http://localhost:9889` on your web browser. The
port is not configurable at this time.
