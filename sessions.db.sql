
-- GUID/UUID generator helper
-- Usage:
-- SELECT id FROM uuid;
CREATE VIEW uuid AS SELECT lower(
	hex( randomblob( 4 ) ) || '-' || 
	hex( randomblob( 2 ) ) || '-' || 
	'4' || substr( hex( randomblob( 2 ) ), 2 ) || '-' || 
	substr( 'AB89', 1 + ( abs( random() ) % 4 ) , 1 )  ||
	substr( hex( randomblob( 2 ) ), 2 ) || '-' || 
	hex( randomblob( 6 ) )
) AS id;-- --

-- Sessions based on currently visiting site
CREATE TABLE sessions(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	basename TEXT NOT NULL COLLATE NOCASE,
	session_id TEXT DEFAULT NULL COLLATE NOCASE,
	session_data TEXT DEFAULT NULL COLLATE NOCASE,
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	expires DATETIME NOT NULL
);-- --
CREATE UNIQUE INDEX idx_session ON sessions( basename, session_id );-- --
CREATE INDEX idx_session_site ON sessions( basename );-- --
CREATE INDEX idx_session_created ON sessions ( created ASC );-- --
CREATE INDEX idx_session_expires ON sessions ( expires ASC );-- --

CREATE TRIGGER session_id_insert AFTER INSERT ON sessions FOR EACH ROW
WHEN NEW.session_id IS NULL
BEGIN
	UPDATE sessions SET session_id = ( SELECT id FROM uuid )
		WHERE id = NEW.id;
END;-- --

CREATE TRIGGER session_update AFTER UPDATE ON sessions
BEGIN
	UPDATE sessions SET updated = CURRENT_TIMESTAMP 
		WHERE id = NEW.id;
END;-- --

