#!/bin/sh

# Helper script on *.nix create or backup the pub.db database in the /data folder


# Data folder
FD=data

# Database name
DB=$FD/pub.db

# SQL File
SQL=pub.db.sql

# Log file
LOG=$FD/install.log

# Timestamp
DATE=`date +%Y-%m-%d-%H-%M-%S`

mkdir -p $FD
touch $LOG

# Backup to data folder, if pub.db already exists
if [ -f $DB ]; then
	sqlite3 $DB .dump > $DB.$DATE.sql
 	MSG="- Backed up $DB $DATE"
	echo $MSG >> $LOG
 	echo $MSG
else
	sqlite3 $DB < $SQL
 	MSG="- Created $DB $DATE"
 	echo $MSG >> $LOG
	echo $MSG
fi
