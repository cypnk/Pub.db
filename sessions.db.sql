

-- Generate a random unique string
-- Usage:
-- SELECT id FROM rnd;
CREATE VIEW rnd AS 
SELECT lower( hex( randomblob( 16 ) ) ) AS id;-- --

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
	UPDATE sessions SET session_id = ( SELECT id FROM rnd )
		WHERE id = NEW.id;
END;-- --

CREATE TRIGGER session_update AFTER UPDATE ON sessions
BEGIN
	UPDATE sessions SET updated = CURRENT_TIMESTAMP 
		WHERE id = NEW.id;
END;-- --

