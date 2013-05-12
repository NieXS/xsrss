#!/bin/sh
valac --pkg gee-0.8 --pkg libxml-2.0 --pkg posix --pkg gio-2.0 --pkg libsoup-2.4 --vapidir=../vapi -g feed.vala main.vala 
