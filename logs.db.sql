
-- Activity history
CREATE TABLE event_logs (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
	
	-- Serialized JSON
	content TEXT NOT NULL DEFAULT 
		'{ "label" : "", "body" : "" }' COLLATE NOCASE, 
	
	-- Log type
	label TEXT GENERATED ALWAYS AS ( 
		COALESCE( json_extract( content, '$.label' ), '' )
	) STORED NOT NULL,
	
	-- Main payload
	body TEXT GENERATED ALWAYS AS ( 
		COALESCE( json_extract( content, '$.body' ), '' )
	) STORED NOT NULL,
	
	-- Logs are not updated
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	expires DATETIME DEFAULT NULL
);-- --
CREATE INDEX idx_log_label ON event_logs ( label );-- --
CREATE INDEX idx_log_created ON event_logs ( created );-- --
CREATE INDEX idx_log_expires ON event_logs ( expires )
	WHERE expires IS NOT NULL;-- --

-- Internal application logs
CREATE TABLE app_logs(
	log_id INTEGER NOT NULL,
	
	-- Error/notice/warning code
	code INTEGER NOT NULL,
	
	-- Line in file
	line INTEGER NOT NULL,
	
	-- File or class name
	origin TEXT NOT NULL COLLATE NOCASE,
	
	CONSTRAINT fk_app_log
		FOREIGN KEY ( log_id ) 
		REFERENCES event_logs ( id )
		ON DELETE CASCADE
);
CREATE UNIQUE INDEX idx_app_log ON app_logs ( log_id );-- --
CREATE INDEX idx_log_code ON app_logs ( code );-- --
CREATE INDEX idx_log_line ON app_logs ( line );-- --
CREATE INDEX idx_log_origin ON app_logs ( origin )
	WHERE origin IS NOT '';-- --

-- Client HTTP request data
CREATE TABLE web_logs(
	log_id INTEGER NOT NULL,
	
	-- Domain/host
	realm TEXT NOT NULL COLLATE NOCASE,
	
	-- Client connection address
	ip TEXT NOT NULL COLLATE NOCASE,
	
	-- GET, HEAD, POST etc...
	method TEXT NOT NULL COLLATE NOCASE,
	
	-- Request path
	uri TEXT NOT NULL COLLATE NOCASE,
	
	-- Client browser info
	user_agent TEXT DEFAULT NULL COLLATE NOCASE,
	
	-- Sub URI parameters
	query_string TEXT NOT NULL COLLATE NOCASE,
	
	-- Client's preferred language by browser details
	language TEXT DEFAULT NULL COLLATE NOCASE,
	
	-- HTTP response code
	response INTEGER NOT NULL,
	
	CONSTRAINT fk_web_log
		FOREIGN KEY ( log_id ) 
		REFERENCES event_logs ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_web_log ON web_logs ( log_id );-- --
CREATE INDEX idx_log_realm ON web_logs ( realm );-- --
CREATE INDEX idx_log_ip ON web_logs ( ip );-- --
CREATE INDEX idx_log_method ON web_logs ( method );-- --
CREATE INDEX idx_log_uri ON web_logs ( uri )
	WHERE uri IS NOT '';-- --
CREATE INDEX idx_log_ua ON web_logs ( user_agent );-- --
CREATE INDEX idx_log_qs ON web_logs ( query_string )
	WHERE query_string IS NOT '';-- --
CREATE INDEX idx_log_lang ON web_logs ( language )
	WHERE language IS NOT NULL;-- --
CREATE INDEX idx_log_response ON web_logs ( response );-- --

CREATE TRIGGER app_error_insert AFTER INSERT ON event_logs FOR EACH ROW
WHEN NEW.label = 'error' OR NEW.label = 'notice' OR NEW.label = 'warning'
BEGIN
	INSERT INTO app_logs(
		log_id, code, line, origin
	) VALUES (
		NEW.id,
		CAST( COALESCE( json_extract( NEW.content, '$.code' ), 0 ) AS INTEGER ),
		CAST( COALESCE( json_extract( NEW.content, '$.line' ), 0 ) AS INTEGER ),
		COALESCE( json_extract( NEW.content, '$.origin' ), '' )
	);
END;-- --

CREATE TRIGGER web_request_insert AFTER INSERT ON event_logs FOR EACH ROW
WHEN NEW.label = 'request'
BEGIN
	INSERT INTO web_logs( 
		log_id, realm, ip, method, uri, user_agent, 
		query_string, language, response
	) VALUES (
		NEW.id,
		COALESCE( json_extract( NEW.content, '$.realm' ), 'unknown' ),
		COALESCE( json_extract( NEW.content, '$.ip' ), 'unknown' ),
		COALESCE( json_extract( NEW.content, '$.method' ), 'unknown' ),
		COALESCE( json_extract( NEW.content, '$.uri' ), '' ),
		COALESCE( json_extract( NEW.content, '$.user_agent' ), 'unknown' ),
		COALESCE( json_extract( NEW.content, '$.query_string' ), '' ),
		COALESCE( json_extract( NEW.content, '$.language' ), NULL ),
		CAST( COALESCE( json_extract( NEW.content, '$.response' ), 520 ) AS INTEGER )
	);
END;-- --


-- Log body searching
CREATE VIRTUAL TABLE log_search 
	USING fts4( body, tokenize=unicode61 );-- --


