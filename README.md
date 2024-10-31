# Pub.db
For common publishing tasks

A set of tables and views in patterns that I tend to reuse often in my own projects with slight modifications. The syntax is specific to [SQLite](https://www.sqlite.org/), however, most of it can be adapted to other database software.

## Content
* pub.db.sql - Main database SQL file
* sessions.db.sql - Optional sessions database SQL file for logins, cookies and similar
* logs.db.sql - Optional event log database SQL file for recording ongoing activity
* cache.db.sql - Optional temporary database SQL file for storing non-critical generated content
* install.nix.sh - Helper script to create the main database or backup on \*nix platforms
* install.win.ps1 - Helper script alternative for Windows PowerShell
