
-- Helper views

-- Generate a random unique string
-- Usage:
-- SELECT id FROM rnd;
CREATE VIEW rnd AS 
SELECT lower( hex( randomblob( 16 ) ) ) AS id;-- --


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




-- Core information

-- Repeatable model settings
CREATE TABLE settings(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	label TEXT NOT NULL COLLATE NOCASE,
	
	-- Serialized JSON
	info TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE
);-- --
CREATE UNIQUE INDEX idx_settings_label ON settings( label );-- --


-- List of languages
CREATE TABLE languages (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	label TEXT NOT NULL COLLATE NOCASE,
	iso_code TEXT NOT NULL COLLATE NOCASE,
	
	-- English name
	eng_name TEXT NOT NULL COLLATE NOCASE,
	lang_group TEXT DEFAULT NULL COLLATE NOCASE,
	
	-- Referenced preset settings
	setting_id INTEGER DEFAULT NULL,
	
	-- Custom settings serialized JSON
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_lang_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_lang_label ON languages ( label );-- --
CREATE UNIQUE INDEX idx_lang_iso ON languages ( iso_code );-- --
CREATE UNIQUE index idx_lang_eng ON languages( eng_name );-- --
CREATE INDEX idx_lang_group ON languages ( lang_group );-- --
CREATE INDEX idx_lang_settings ON languages ( setting_id ) 
	WHERE setting_id IS NOT NULL;-- --

-- Performant metadata and generated info that doesn't change the content
CREATE TABLE lang_meta(
	language_id INTEGER NOT NULL,
	
	-- Default interface language
	is_default INTEGER NOT NULL DEFAULT 0,
	sort_order INTEGER NOT NULL DEFAULT 0,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_lang_meta
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_lang_meta ON lang_meta ( language_id );-- --
CREATE INDEX idx_lang_default ON lang_meta ( is_default );-- --
CREATE INDEX idx_lang_sort ON lang_meta ( sort_order );-- --
CREATE INDEX idx_lang_status ON lang_meta ( status );-- --

CREATE TRIGGER lang_insert AFTER INSERT ON languages FOR EACH ROW
BEGIN
	INSERT INTO lang_meta( language_id ) VALUES ( NEW.id );
END;-- --

-- Unset previous default language if new default is set
CREATE TRIGGER lang_default_update BEFORE UPDATE ON lang_meta FOR EACH ROW 
WHEN NEW.is_default <> 0 AND NEW.is_default IS NOT NULL
BEGIN
	UPDATE languages SET is_default = 0 
		WHERE is_default IS NOT 0 AND id IS NOT NEW.id;
END;-- --


-- Regional content interface replacement data
CREATE TABLE translations (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
	locale TEXT NOT NULL COLLATE NOCASE,
	language_id INTEGER NOT NULL,
	
	-- Replacement match patterns
	definitions TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	-- Default locale for the language
	is_default INTEGER NOT NULL DEFAULT 0,
	
	CONSTRAINT fk_translation_language
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_translation_local ON translations( locale );-- --
CREATE INDEX idx_translation_lang ON translations( language_id );-- --
CREATE INDEX idx_translation_default ON translations( is_default );-- --

-- Unset any previous default language locales if new default is set
CREATE TRIGGER locale_default_insert BEFORE INSERT ON 
	translations FOR EACH ROW 
WHEN NEW.is_default <> 0 AND NEW.is_default IS NOT NULL
BEGIN
	UPDATE translations SET is_default = 0 
		WHERE is_default IS NOT 0 AND language_id = NEW.language_id;
END;-- --

CREATE TRIGGER locale_default_update BEFORE UPDATE ON 
	translations FOR EACH ROW 
WHEN NEW.is_default <> 0 AND NEW.is_default IS NOT NULL
BEGIN
	UPDATE translations SET is_default = 0 
		WHERE is_default IS NOT 0 AND id IS NOT NEW.id 
			AND language_id = OLD.language_id;
END;-- --

CREATE VIEW locale_view AS SELECT
	t.id AS id,
	l.label AS label,
	l.iso_code AS iso_code,
	l.is_default AS is_lang_default,
	l.eng_name AS lang_eng_name,
	l.lang_group AS lang_group,
	t.locale AS locale,
	t.is_default AS is_locale_default,
	t.definitions AS definitions
	
	FROM translations t
	JOIN languages l ON t.language_id = l.id;-- --

-- Localized date presentation formats
CREATE TABLE date_formats(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
	language_id INTEGER NOT NULL,
	locale_id INTEGER NOT NULL,
	
	 -- Excluding pipe ( | )
	render TEXT NOT NULL COLLATE NOCASE,
		
	CONSTRAINT fk_date_language
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE CASCADE,
	
	CONSTRAINT fk_date_locale
		FOREIGN KEY ( locale_id ) 
		REFERENCES translations ( id )
		ON DELETE CASCADE
);-- --
CREATE INDEX idx_date_lang ON date_formats( language_id );-- --
CREATE INDEX idx_date_locales ON date_formats( locale_id );-- --




-- Domain realms
CREATE TABLE sites(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	title TEXT NOT NULL COLLATE NOCASE,
	
	-- Domain name
	basename TEXT NOT NULL COLLATE NOCASE,
	
	-- Relative path
	basepath TEXT NOT NULL COLLATE NOCASE, 
	
	is_active INTEGER NOT NULL DEFAULT 1,
	is_maintenance INTEGER NOT NULL DEFAULT 0,
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_site_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_site_title ON sites ( title );-- --
-- E.G.: example.com, portal = example.com/portal
CREATE UNIQUE INDEX idx_site_uri ON sites ( basename, basepath );-- --
CREATE INDEX idx_site_basename ON sites ( basename );-- --
CREATE INDEX idx_site_basepath ON sites( basepath );-- --
CREATE INDEX idx_site_settings ON sites ( setting_id )
	WHERE setting_id IS NOT NULL;-- --

-- Mirrored sites
CREATE TABLE site_aliases (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	site_id INTEGER NOT NULL,
	basename TEXT NOT NULL COLLATE NOCASE,
	
	CONSTRAINT fk_alias_site 
		FOREIGN KEY ( site_id ) 
		REFERENCES sites ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_site_alias ON site_aliases ( site_id, basename );-- --

CREATE TABLE site_meta(
	site_id INTEGER NOT NULL,
	url TEXT NOT NULL COLLATE NOCASE,
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_site_meta
		FOREIGN KEY ( site_id ) 
		REFERENCES sites ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_site_meta ON site_meta ( site_id );-- --
CREATE UNIQUE INDEX idx_site_url ON site_meta ( url );-- --
CREATE INDEX idx_site_created ON site_meta ( created );-- --
CREATE INDEX idx_site_updated ON site_meta ( updated );-- --
CREATE INDEX idx_site_status ON site_meta ( status );-- --

-- Site and content path searching
CREATE VIRTUAL TABLE path_search 
	USING fts4( 
		url, tokenize=unicode61 "tokenchars=-_" "separators=/*" 
	);-- --


CREATE TRIGGER site_insert AFTER INSERT ON sites FOR EACH ROW
BEGIN
	INSERT INTO site_meta( site_id, url ) 
		VALUES (
			NEW.id, 
			(
				trim( NEW.basename, '/' ) || '/' || 
				trim( NEW.basepath, '/' )
			)
		);
END;-- --

CREATE TRIGGER site_update AFTER UPDATE ON sites FOR EACH ROW
BEGIN
	UPDATE site_meta SET 
		updated	= CURRENT_TIMESTAMP, 
		url	= (
			trim( NEW.basename, '/' ) || '/' || 
			trim( NEW.basepath, '/' )
		) 
		WHERE site_id = NEW.id;
END;-- --

CREATE VIEW sites_enabled AS SELECT 
	s.id AS id, 
	s.label AS label, 
	s.basename AS basename, 
	s.basepath AS basepath, 
	s.is_active AS is_active,
	s.is_maintenance AS is_maintenance,
	GROUP_CONCAT( DISTINCT a.basename ) AS base_alias,
	COALESCE( sg.info, '{}' ) AS settings,
	s.settings_override AS settings_override, 
	sm.uri AS uri,
	sm.created AS created,
	sm.updated AS updated
	
	FROM sites s 
	INNER JOIN site_meta sm ON s.id = sm.site_id 
	LEFT JOIN settings sg ON s.settings_id = sg.id 
	LEFT JOIN site_aliases a ON s.id = a.site_id;-- --





-- Sessions based on currently visiting site
CREATE TABLE sessions(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	site_id INTEGER NOT NULL,
	session_id TEXT DEFAULT NULL COLLATE NOCASE,
	session_data TEXT DEFAULT NULL COLLATE NOCASE,
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	expires DATETIME NOT NULL,
	
	CONSTRAINT fk_session_site 
		FOREIGN KEY ( site_id )
		REFERENCES sites( id ) 
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_session_id ON sessions( session_id );-- --
CREATE INDEX idx_session_site ON sessions( site_id );-- --
CREATE INDEX idx_session_created ON sessions ( created ASC );-- --
CREATE INDEX idx_session_expires ON sessions ( expires ASC );-- --

-- Site specific cached content
CREATE TABLE caches (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
	site_id INTEGER NOT NULL,
	
	-- Cache identifier, unique per site
	cache_id TEXT NOT NULL COLLATE NOCASE, 
	ttl INTEGER NOT NULL, 
	content TEXT NOT NULL COLLATE NOCASE, 
	expires DATETIME DEFAULT NULL,
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, 
	updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	
	CONSTRAINT fk_cache_site 
		FOREIGN KEY ( site_id )
		REFERENCES sites( id ) 
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_caches ON caches ( site_id, cache_id );-- --
CREATE INDEX idx_cache_site ON caches ( site_id );-- --
CREATE INDEX idx_caches_on_expires ON caches ( expires DESC )
	WHERE expires IS NOT NULL;-- --
CREATE INDEX idx_caches_on_created ON caches ( created ASC );-- --
CREATE INDEX idx_caches_on_updated ON caches ( updated );-- --

CREATE TRIGGER cache_after_insert AFTER INSERT ON caches FOR EACH ROW 
BEGIN
	-- Generate expiration
	UPDATE caches SET 
		expires = datetime( 
			( strftime( '%s','now' ) + NEW.ttl ), 
			'unixepoch' 
		) WHERE rowid = NEW.rowid;
	
	-- Clear expired data
	DELETE FROM caches WHERE 
		strftime( '%s', expires ) < 
		strftime( '%s', updated ) AND expires IS NOT NULL;
END;-- --

-- Change only update period when TTL is empty
CREATE TRIGGER cache_after_update AFTER UPDATE ON caches FOR EACH ROW 
WHEN NEW.updated < OLD.updated AND NEW.ttl = 0
BEGIN
	UPDATE caches SET updated = CURRENT_TIMESTAMP 
		WHERE rowid = NEW.rowid;
END;-- --

-- Change expiration period when TTL exists
CREATE TRIGGER cache_after_update_ttl AFTER UPDATE ON caches FOR EACH ROW 
WHEN NEW.updated < OLD.updated AND NEW.ttl <> 0
BEGIN
	-- Change expiration
	UPDATE caches SET updated = CURRENT_TIMESTAMP, 
		expires = datetime( 
			( strftime( '%s','now' ) + NEW.ttl ), 
			'unixepoch' 
		) WHERE rowid = NEW.rowid;
END;-- --




-- Users access
CREATE TABLE users (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	username TEXT NOT NULL COLLATE NOCASE,
	password TEXT NOT NULL,
	
	-- Normalized, lowercase, and stripped of spaces
	user_clean TEXT NOT NULL COLLATE NOCASE,
	
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_user_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_users_username ON users ( username );-- --
CREATE UNIQUE INDEX idx_user_clean ON users ( user_clean );-- --
CREATE INDEX idx_user_settings ON users ( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TABLE user_meta(
	user_id INTEGER NOT NULL,
	
	-- Anonymous token, other than username, when publicly referenced
	reference TEXT DEFAULT NULL COLLATE NOCASE,
	
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_user_meta
		FOREIGN KEY ( user_id ) 
		REFERENCES users ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_user_meta ON user_meta ( user_id );-- --
CREATE UNIQUE INDEX idx_user_ref ON user_meta ( reference )
	WHERE reference IS NOT NULL;-- --
CREATE INDEX idx_user_created ON user_meta ( created );-- --
CREATE INDEX idx_user_updated ON user_meta ( updated );-- --
CREATE INDEX idx_user_status ON user_meta ( status );-- --

-- User search
CREATE VIRTUAL TABLE user_search 
	USING fts4( username, tokenize=unicode61 );-- --


-- Web form based logins (requires session)
CREATE TABLE logins(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	user_id INTEGER NOT NULL,
	lookup TEXT NOT NULL COLLATE NOCASE,
	updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	hash TEXT DEFAULT NULL COLLATE NOCASE,
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_logins_user 
		FOREIGN KEY ( user_id ) 
		REFERENCES users ( id )
		ON DELETE CASCADE,
	
	CONSTRAINT fk_login_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_login_lookup ON logins( lookup );-- --
CREATE UNIQUE INDEX idx_login_user ON logins( user_id );-- --
CREATE INDEX idx_login_updated ON logins( updated );-- --
CREATE INDEX idx_login_hash ON logins( hash )
	WHERE hash IS NOT NULL;-- --
-- If a (random)hash exists, then the user is allowed to login 
-- with the specified cookie info. This is a way to force logout

CREATE INDEX idx_login_settings ON logins ( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TRIGGER user_insert AFTER INSERT ON users FOR EACH ROW
BEGIN
	INSERT INTO user_meta( user_id, reference ) 
		VALUES ( NEW.id, ( SELECT id FROM rnd ) );
	INSERT INTO logins( user_id ) VALUES ( NEW.id );
END;-- --

CREATE TRIGGER user_update AFTER UPDATE ON users FOR EACH ROW
BEGIN
	UPDATE user_meta SET updated = CURRENT_TIMESTAMP 
		WHERE user_id = NEW.id;
END;-- --



-- User roles, and permissions
CREATE TABLE roles(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_role_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_role_settings ON roles ( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TABLE role_meta(
	role_id INTEGER NOT NULL,
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_role_meta
		FOREIGN KEY ( role_id ) 
		REFERENCES roles ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_role_meta ON role_meta( role_id );-- --
CREATE INDEX idx_role_created ON role_meta( created );-- --
CREATE INDEX idx_role_updated ON role_meta( updated );-- --
CREATE INDEX idx_role_status ON role_meta( status );-- --

CREATE TABLE role_desc(
	role_id INTEGER NOT NULL,
	label TEXT NOT NULL COLLATE NOCASE,
	description TEXT DEFAULT NULL COLLATE NOCASE,
	language_id INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_role_desc
		FOREIGN KEY ( role_id ) 
		REFERENCES roles ( id )
		ON DELETE CASCADE,
		
	CONSTRAINT fk_role_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_role_desc ON role_desc ( role_id );-- --
CREATE INDEX idx_role_name ON role_desc ( label );-- --
CREATE INDEX idx_role_lang ON role_desc ( language_id )
	WHERE language_id IS NOT NULL;-- --

CREATE TRIGGER role_insert AFTER INSERT ON roles FOR EACH ROW
BEGIN
	INSERT INTO role_meta( role_id ) VALUES ( NEW.id );
END;-- --

CREATE TRIGGER role_update AFTER UPDATE ON roles FOR EACH ROW
BEGIN
	UPDATE role_meta SET updated = CURRENT_TIMESTAMP
		WHERE role_id = NEW.id;
END;-- --

CREATE TABLE user_roles(
	role_id INTEGER NOT NULL REFERENCES roles ( id ) 
		ON DELETE CASCADE,
	user_id INTEGER NOT NULL REFERENCES users ( id ) 
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_user_roles ON user_roles ( role_id, user_id );-- --


-- Role action privileges
CREATE TABLE role_permissions(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	role_id INTEGER NOT NULL,
	settings_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_permission_role 
		FOREIGN KEY ( role_id ) 
		REFERENCES roles ( id )
		ON DELETE CASCADE, 
	
	CONSTRAINT fk_role_settings
		FOREIGN KEY ( settings_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_permission_role ON role_permissions( role_id );-- --
CREATE INDEX idx_permission_settings ON role_permissions ( settings_id )
	WHERE settings_id IS NOT NULL;-- --

-- Role based user permission view
CREATE VIEW user_permission_view AS 
SELECT 
	user_id AS id, 
	GROUP_CONCAT( 
		COALESCE( pg.info, '{}' ), ',' 
	) AS role_settings,
	GROUP_CONCAT( 
		COALESCE( roles.settings_override, '{}' ), ',' 
	) AS role_settings_override,
	GROUP_CONCAT( 
		COALESCE( sp.info, '{}' ), ',' 
	) AS permission_settings,
	GROUP_CONCAT( 
		COALESCE( rp.settings_override, '{}' ), ',' 
	) AS permission_settings_override
	
	FROM user_roles
	JOIN roles ON user_roles.role_id = roles.id
	LEFT JOIN settings pg ON roles.settings_id = rg.id
	LEFT JOIN role_permissions rp ON roles.id = rp.role_id
	LEFT JOIN settings sp ON rp.settings_id = sp.id;-- --





-- Secondary identity providers for future use E.G. two-factor
CREATE TABLE id_providers( 
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	label TEXT NOT NULL COLLATE NOCASE,
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_id_provider_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_id_provider_label ON id_providers( label );-- --
CREATE INDEX idx_id_provider_settings ON id_providers( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TABLE id_provider_meta(
	provider_id INTEGER NOT NULL,
	uuid TEXT DEFAULT NULL COLLATE NOCASE,
	sort_order INTEGER NOT NULL DEFAULT 0,
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_id_provider_meta
		FOREIGN KEY ( provider_id ) 
		REFERENCES id_providers( id ) 
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_provider ON id_provider_meta ( provider_id );-- --
CREATE INDEX idx_provider_sort ON id_provider_meta( sort_order );-- --
CREATE INDEX idx_provider_created ON id_provider_meta( created );-- --
CREATE INDEX idx_provider_updated ON id_provider_meta( updated );-- --
CREATE INDEX idx_provider_status ON id_provider_meta( status );-- --

CREATE TRIGGER id_provider_insert AFTER INSERT ON id_providers FOR EACH ROW
BEGIN
	INSERT INTO id_provider_meta( provider_id, uuid ) 
		VALUES ( NEW.id, ( SELECT id FROM uuid ) );
END;-- --

CREATE TRIGGER id_provider_update AFTER UPDATE ON id_providers FOR EACH ROW
BEGIN
	UPDATE id_provider_meta SET updated = CURRENT_TIMESTAMP
		WHERE provider_id = NEW.id;
END;-- --

-- User authentication and activity metadata
CREATE TABLE user_auth(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	user_id INTEGER NOT NULL,
	provider_id INTEGER DEFAULT NULL,
	email TEXT DEFAULT NULL COLLATE NOCASE,
	mobile_pin TEXT DEFAULT NULL COLLATE NOCASE,
	
	-- Activity
	last_ip TEXT DEFAULT NULL COLLATE NOCASE,
	last_ua TEXT DEFAULT NULL COLLATE NOCASE,
	last_active DATETIME DEFAULT NULL,
	last_login DATETIME DEFAULT NULL,
	last_pass_change DATETIME DEFAULT NULL,
	last_lockout DATETIME DEFAULT NULL,
	last_session_id TEXT DEFAULT NULL,
	
	-- Auth status,
	is_approved INTEGER NOT NULL DEFAULT 0,
	is_locked INTEGER NOT NULL DEFAULT 0,
	
	-- Authentication tries
	failed_attempts INTEGER NOT NULL DEFAULT 0,
	failed_last_start DATETIME DEFAULT NULL,
	failed_last_attempt DATETIME DEFAULT NULL,
	
	created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	expires DATETIME DEFAULT NULL,
	
	-- Per auth settings
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_auth_session 
		FOREIGN KEY ( last_session_id )
		REFERENCES sessions( session_id )
		ON DELETE SET NULL,
	
	CONSTRAINT fk_auth_user 
		FOREIGN KEY ( user_id ) 
		REFERENCES users ( id )
		ON DELETE CASCADE, 
		
	CONSTRAINT fk_auth_provider
		FOREIGN KEY ( provider_id ) 
		REFERENCES id_providers ( id )
		ON DELETE SET NULL,
	
	CONSTRAINT fk_id_provider_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_user_email ON user_auth( email )
	WHERE email IS NOT NULL;-- --
CREATE INDEX idx_user_auth_user ON user_auth( user_id );-- --
CREATE INDEX idx_user_auth_provider ON user_auth( provider_id )
	WHERE provider_id IS NOT NULL;-- --
CREATE INDEX idx_user_pin ON user_auth( mobile_pin ) 
	WHERE mobile_pin IS NOT NULL;-- --
CREATE INDEX idx_user_ip ON user_auth( last_ip )
	WHERE last_ip IS NOT NULL;-- --
CREATE INDEX idx_user_ua ON user_auth( last_ua )
	WHERE last_ua IS NOT NULL;-- --
CREATE INDEX idx_user_active ON user_auth( last_active )
	WHERE last_active IS NOT NULL;-- --
CREATE INDEX idx_user_login ON user_auth( last_login )
	WHERE last_login IS NOT NULL;-- --
CREATE INDEX idx_user_session ON user_auth( last_session_id )
	WHERE last_session_id IS NOT NULL;-- --
CREATE INDEX idx_user_auth_approved ON user_auth( is_approved );-- --
CREATE INDEX idx_user_auth_locked ON user_auth( is_locked );-- --
CREATE INDEX idx_user_failed_last ON user_auth( failed_last_attempt )
	WHERE failed_last_attempt IS NOT NULL;-- --
CREATE INDEX idx_user_auth_created ON user_auth( created );-- --
CREATE INDEX idx_user_auth_expires ON user_auth( expires )
	WHERE expires IS NOT NULL;-- --
CREATE INDEX idx_user_auth_settings ON user_auth( setting_id )
	WHERE setting_id IS NOT NULL;-- --



-- Secrity views

-- User auth last activity
CREATE VIEW auth_activity AS 
SELECT user_id, 
	provider_id,
	is_approved,
	is_locked,
	last_ip,
	last_ua,
	last_active,
	last_login,
	last_lockout,
	last_pass_change,
	last_session_id,
	failed_attempts,
	failed_last_start,
	failed_last_attempt
	
	FROM user_auth;-- --


-- Auth activity helpers
CREATE TRIGGER user_last_login INSTEAD OF 
	UPDATE OF last_login ON auth_activity
BEGIN 
	UPDATE user_auth SET 
		last_ip			= NEW.last_ip,
		last_ua			= NEW.last_ua,
		last_session_id		= NEW.last_session_id,
		last_login		= CURRENT_TIMESTAMP, 
		last_active		= CURRENT_TIMESTAMP,
		failed_attempts		= 0
		WHERE id = OLD.id;
END;-- --

CREATE TRIGGER user_last_ip INSTEAD OF 
	UPDATE OF last_ip ON auth_activity
BEGIN 
	UPDATE user_auth SET 
		last_ip			= NEW.last_ip, 
		last_ua			= NEW.last_ua,
		last_session_id		= NEW.last_session_id,
		last_active		= CURRENT_TIMESTAMP 
		WHERE id = OLD.id;
END;-- --

CREATE TRIGGER user_last_active INSTEAD OF 
	UPDATE OF last_active ON auth_activity
BEGIN 
	UPDATE user_auth SET last_active = CURRENT_TIMESTAMP
		WHERE id = OLD.id;
END;-- --

CREATE TRIGGER user_last_lockout INSTEAD OF 
	UPDATE OF is_locked ON auth_activity
	WHEN NEW.is_locked = 1
BEGIN 
	UPDATE user_auth SET 
		is_locked	= 1,
		last_lockout	= CURRENT_TIMESTAMP 
		WHERE id = OLD.id;
END;-- --

CREATE TRIGGER user_failed_last_attempt INSTEAD OF 
	UPDATE OF failed_last_attempt ON auth_activity
BEGIN 
	UPDATE user_auth SET 
		last_ip			= NEW.last_ip, 
		last_ua			= NEW.last_ua,
		last_session_id		= NEW.last_session_id,
		last_active		= CURRENT_TIMESTAMP,
		failed_last_attempt	= CURRENT_TIMESTAMP, 
		failed_attempts		= ( failed_attempts + 1 ) 
		WHERE id = OLD.id;
	
	-- Update current start window if it's been 24 hours since 
	-- last window
	UPDATE user_auth SET failed_last_start = CURRENT_TIMESTAMP 
		WHERE id = OLD.id AND ( 
		failed_last_start IS NULL OR ( 
		strftime( '%s', 'now' ) - 
		strftime( '%s', 'failed_last_start' ) ) > 86400 );
END;-- --


-- Login view
-- Usage:
-- SELECT * FROM login_view WHERE lookup = :lookup;
-- SELECT * FROM login_view WHERE name = :username;
CREATE VIEW login_view AS SELECT 
	logins.id AS id,
	logins.user_id AS user_id, 
	users.uuid AS uuid, 
	logins.lookup AS lookup, 
	logins.hash AS hash, 
	logins.updated AS updated, 
	users.status AS status, 
	users.username AS name, 
	users.password AS password, 
	us.info AS user_settings,
	users.settings_override AS user_settings_override, 
	ua.is_approved AS is_approved, 
	ua.is_locked AS is_locked, 
	ua.expires AS expires, 
	ls.info AS login_settings,
	logins.settings_override AS login_settings_override,
	ts.info AS auth_settings,
	ua.settings_override AS auth_settings_override
	
	FROM logins
	JOIN users ON logins.user_id = users.id
	LEFT JOIN user_auth ua ON users.id = ua.user_id
	LEFT JOIN settings us ON users.setting_id = us.id
	LEFT JOIN settings ts ON ua.setting_id = ts.id
	LEFT JOIN settings ls ON logins.setting_id = ls.id;-- --

-- Post-login user data
CREATE VIEW user_view AS SELECT 
	users.id AS id, 
	users.uuid AS uuid, 
	users.status AS status, 
	users.username AS username, 
	users.password AS password, 
	users.hash AS hash,
	ua.is_approved AS is_approved, 
	ua.is_locked AS is_locked, 
	ua.expires AS expires, 
	us.created AS created, 
	us.updated AS updated, 
	us.info AS settings, 
	users.settings_override AS settings_override, 
	ts.info AS auth_settings,
	ua.settings_override AS auth_settings_override
	
	FROM users
	LEFT JOIN user_auth ua ON users.id = ua.user_id
	LEFT JOIN user_stats us ON users.id = us.user_id
	LEFT JOIN settings ts ON ua.setting_id = ts.id
	LEFT JOIN settings us ON users.setting_id = us.id;-- --
	


-- Login regenerate. Not intended for SELECT
-- Usage:
-- UPDATE logout_view SET lookup = '' WHERE user_id = :user_id;
CREATE VIEW logout_view AS 
SELECT user_id, lookup FROM logins;-- --

-- Reset the lookup string to force logout a user
CREATE TRIGGER user_logout INSTEAD OF UPDATE OF lookup ON logout_view
BEGIN
	UPDATE logins SET lookup = ( SELECT id FROM rnd ), 
		updated = CURRENT_TIMESTAMP
		WHERE user_id = NEW.user_id;
END;-- --






-- URL Routing and page handling
CREATE TABLE route_markers(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	pattern TEXT NOT NULL COLLATE NOCASE,
	replacement TEXT NOT NULL COLLATE NOCASE
);-- --
CREATE UNIQUE INDEX idx_route_marker_pattern ON route_markers( pattern );-- --

-- Application handlers
CREATE TABLE handlers(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	site_id INTEGER NOT NULL,
	
	-- GET, POST, HEAD etc..
	verb TEXT NOT NULL COLLATE NOCASE,
	
	-- URL pattern
	pattern TEXT NOT NULL COLLATE NOCASE,
	
	-- Handler function/class
	controller TEXT NOT NULL COLLATE NOCASE,
	sort_order INTEGER NOT NULL DEFAULT 0,
	
	-- Content create/update/delete settings
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_handler_site
		FOREIGN KEY ( site_id ) 
		REFERENCES site ( id )
		ON DELETE CASCADE,
	
	CONSTRAINT fk_handler_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_handler_pattern ON 
	handlers( site_id, verb, pattern );-- --
CREATE INDEX idx_handler_verb ON handlers( verb );-- --
CREATE INDEX idx_handler_order ON handlers( sort_order );-- --
CREATE INDEX idx_handler_settings ON handlers( setting_id )
	WHERE setting_id IS NOT NULL;-- --






-- ATOM-inspired CMS


-- Content sections and relationships
CREATE TABLE workspaces (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	parent_id INTEGER DEFAULT NULL REFERENCES workspaces( id )
		ON DELETE SET NULL,
	
	-- Layouts, formatting, special permissions etc...
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_workspace_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_workspace_parent ON workspaces( parent_id )
	WHERE parent_id IS NOT NULL;-- --
CREATE INDEX idx_workspace_settings ON workspaces( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TABLE workspace_meta(
	workspace_id INTEGER NOT NULL,
	urn TEXT NOT NULL COLLATE NOCASE,
	created DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME DEFAULT CURRENT_TIMESTAMP,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_workspace_meta
		FOREIGN KEY ( workspace_id ) 
		REFERENCES workspaces ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_workspace_meta ON workspace_meta ( workspace_id );-- --
CREATE UNIQUE INDEX idx_workspaces_urn ON workspace_meta ( urn );-- --
CREATE INDEX idx_workspace_created ON workspace_meta( created );-- --
CREATE INDEX idx_workspace_updated ON workspace_meta( updated );-- --
CREATE INDEX idx_workspace_status ON workspace_meta( status );-- --

CREATE TABLE workspace_desc (
	workspace_id INTEGER NOT NULL,
	title TEXT NOT NULL COLLATE NOCASE,
	description TEXT DEFAULT NULL COLLATE NOCASE,
	language_id INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_workspace_desc
		FOREIGN KEY ( workspace_id ) 
		REFERENCES workspaces ( id )
		ON DELETE CASCADE,
		
	CONSTRAINT fk_workspace_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_workspace_desc ON workspace_desc ( workspace_id );-- --
CREATE INDEX idx_workspace_title ON workspace_desc ( title );-- --
CREATE INDEX idx_workspace_language ON workspace_desc ( language_id )
	WHERE language_id IS NOT NULL;-- --


-- New workspace, generate UUID and set meta
CREATE TRIGGER workspace_insert AFTER INSERT ON workspaces FOR EACH ROW 
BEGIN
	INSERT INTO workspace_meta ( workspace_id, urn ) 
		VALUES ( NEW.id, ( SELECT id FROM uuid ) );
END;-- --

CREATE TRIGGER workspace_update AFTER UPDATE on workspaces FOR EACH ROW
BEGIN
	UPDATE workspace_meta SET updated = CURRENT_TIMESTAMP 
		WHERE workspace_id = NEW.id;
END;-- --

-- Site workspaces
CREATE TABLE site_workspaces(
	site_id INTEGER NOT NULL REFERENCES sites ( id ) 
		ON DELETE CASCADE,
	workspace_id INTEGER NOT NULL REFERENCES workspaces ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_work_sites 
	ON site_workspaces ( site_id, workspace_id );-- --



-- Site entry collections
CREATE TABLE collections (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	workspace_id INTEGER NOT NULL,
	
	-- Items per page, rendering, themes etc...
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_collection_workspace
		FOREIGN KEY ( workspace_id ) 
		REFERENCES workspaces ( id )
		ON DELETE RESTRICT,
		
	CONSTRAINT fk_collection_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_collection_workspace ON collections ( workspace_id );-- --
CREATE INDEX idx_colleciton_settings ON collections ( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TABLE collection_meta (
	collection_id INTEGER NOT NULL,
	urn TEXT NOT NULL COLLATE NOCASE,
	
	-- Content type count
	category_count INTEGER DEFAULT 0,
	-- Total items
	entry_count INTEGER DEFAULT 0,
	
	created DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME DEFAULT CURRENT_TIMESTAMP,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_collection_meta
		FOREIGN KEY ( collection_id ) 
		REFERENCES collections ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_collection_meta ON collection_meta ( collection_id );-- --
CREATE UNIQUE INDEX idx_collection_urn ON collection_meta ( urn );-- --
CREATE INDEX idx_collection_created ON collection_meta( created );-- --
CREATE INDEX idx_collection_updated ON collection_meta( updated );-- --
CREATE INDEX idx_collection_status ON collection_meta( status );-- --

CREATE TABLE collection_desc (
	collection_id INTEGER NOT NULL,
	title TEXT NOT NULL COLLATE NOCASE,
	description TEXT DEFAULT NULL COLLATE NOCASE,
	language_id INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_collection_desc
		FOREIGN KEY ( collection_id ) 
		REFERENCES collections ( id )
		ON DELETE CASCADE,
		
	CONSTRAINT fk_collection_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_collection_desc ON collection_desc ( collection_id );-- --
CREATE INDEX idx_collection_title ON collection_desc ( title );-- --
CREATE INDEX idx_collection_language ON collection_desc ( language_id )
	WHERE language_id IS NOT NULL;-- --

-- New collection, generate UUID
CREATE TRIGGER collection_insert AFTER INSERT ON collections FOR EACH ROW 
BEGIN
	INSERT INTO collection_meta ( collection_id, urn ) 
		VALUES ( NEW.id, ( SELECT id FROM uuid ) );
END;-- --

CREATE TRIGGER collection_update AFTER UPDATE ON collections FOR EACH ROW
BEGIN
	UPDATE collection_meta SET updated = CURRENT_TIMESTAMP
		WHERE collection_id = NEW.id;
END;-- --


-- Collection accept types
CREATE TABLE accept (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	mime_type TEXT NOT NULL COLLATE NOCASE,
	collection_id INTEGER NOT NULL,
	
	CONSTRAINT fk_accept_collection
		FOREIGN KEY ( collection_id ) 
		REFERENCES collections ( id ) 
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_accept_mime ON accept( collection_id, mime_type );-- --
CREATE INDEX idx_accept_collection ON accept ( collection_id );-- --




-- Collection types
CREATE TABLE categories (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	parent_id INTEGER DEFAULT NULL REFERENCES categories( id ) 
		ON DELETE SET NULL,
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_category_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_category_parent ON categories( parent_id )
	WHERE parent_id IS NOT NULL;-- --
CREATE INDEX idx_category_settings ON categories ( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TABLE category_meta(
	category_id INTEGER NOT NULL,
	urn TEXT NOT NULL COLLATE NOCASE,
	created DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME DEFAULT CURRENT_TIMESTAMP,
	sort_order INTEGER DEFAULT 0,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_category_meta
		FOREIGN KEY ( category_id ) 
		REFERENCES categories( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_category_meta ON category_meta ( category_id );-- --
CREATE UNIQUE INDEX idx_category_urn ON category_meta ( urn );-- --
CREATE INDEX idx_category_created ON category_meta ( created );-- --
CREATE INDEX idx_category_updated ON category_meta ( updated );-- --
CREATE INDEX idx_category_sort ON category_meta ( sort_order );-- --

CREATE TABLE category_desc (
	category_id INTEGER NOT NULL,
	term TEXT NOT NULL COLLATE NOCASE,
	label TEXT DEFAULT NULL COLLATE NOCASE,
	language_id INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_category_desc
		FOREIGN KEY ( category_id ) 
		REFERENCES categories ( id )
		ON DELETE CASCADE,
		
	CONSTRAINT fk_category_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_category_desc ON category_desc ( category_id );-- --
CREATE INDEX idx_category_term ON category_desc ( term );-- --
CREATE INDEX idx_category_label ON category_desc ( label );-- --
CREATE INDEX idx_category_language ON category_desc ( language_id )
	WHERE language_id IS NOT NULL;-- --

-- Content category searching
CREATE VIRTUAL TABLE category_search 
	USING fts4( content, tokenize=unicode61 );-- --

-- New category, generate UUID
CREATE TRIGGER category_insert AFTER INSERT ON categories FOR EACH ROW 
BEGIN
	INSERT INTO category_meta ( category_id, urn ) 
		VALUES ( NEW.id, ( SELECT id FROM uuid ) );
END;-- --

-- Category update
CREATE TRIGGER category_update AFTER UPDATE ON categories FOR EACH ROW
BEGIN
	UPDATE category_meta SET updated = CURRENT_TIMESTAMP
		WHERE category_id = NEW.id;
END;-- --

CREATE TABLE category_collections(
	category_id INTEGER NOT NULL REFERENCES categories( id )
		ON DELETE CASCADE,
	collection_id INTEGER NOT NULL REFERENCES collections( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_category_collections
	ON category_collections ( category_id, collection_id );-- --


CREATE TRIGGER cat_collection_insert AFTER INSERT ON category_collections
FOR EACH ROW
BEGIN
	UPDATE category_collection SET category_count = ( category_count + 1 ) 
		WHERE collection_id = NEW.collection_id;
END;-- --

CREATE TRIGGER cat_collection_delete BEFORE DELETE ON category_collections
FOR EACH ROW
BEGIN
	UPDATE category_collection SET category_count = ( category_count - 1 ) 
		WHERE collection_id = OLD.collection_id;
END;-- --



CREATE TABLE entry_types(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	-- Should be type, but "type" may cause issues
	entry_type TEXT DEFAULT NULL COLLATE NOCASE,
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
		
	CONSTRAINT fk_entry_type_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_entry_type ON entry_types ( entry_type );-- --
CREATE INDEX idx_entry_type_settings ON entry_types ( setting_id )
	WHERE setting_id IS NOT NULL;-- --
	

-- Collection entries
CREATE TABLE entries (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	-- Optional direct parent
	parent_id INTEGER DEFAULT NULL 
		REFERENCES entries ( id ),
	type_id INTEGER NOT NULL,
	
	-- If true, don't publish regardless of pub date
	is_draft INTEGER NOT NULL DEFAULT 0,
	setting_id INTEGER DEFAULT NULL,
	settings_override TEXT NOT NULL DEFAULT '{}' COLLATE NOCASE,
	
	CONSTRAINT fk_entry_type
		FOREIGN KEY ( type_id ) 
		REFERENCES entry_type ( id )
		ON DELETE RESTRICT,
	
	CONSTRAINT fk_entry_settings
		FOREIGN KEY ( setting_id ) 
		REFERENCES settings ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_entry_parent ON entries ( parent_id )
	WHERE parent_id IS NOT NULL;-- --
CREATE INDEX idx_entry_draft ON entries ( is_draft );-- --
CREATE INDEX idx_entry_etype ON entries ( type_id );-- --
CREATE INDEX idx_entry_settings ON entries ( setting_id )
	WHERE setting_id IS NOT NULL;-- --

CREATE TABLE entry_meta(
	entry_id INTEGER NOT NULL,
	urn TEXT NOT NULL COLLATE NOCASE,
	created DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated DATETIME DEFAULT CURRENT_TIMESTAMP,
	published DATETIME DEFAULT NULL,
	sort_order INTEGER NOT NULL DEFAULT 0,
	status INTEGER NOT NULL DEFAULT 0,
	
	CONSTRAINT fk_entry_meta 
		FOREIGN KEY ( entry_id )
		REFERENCES entries ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_entry_meta ON entry_meta ( entry_id );-- --
CREATE UNIQUE INDEX idx_entry_urn ON entry_meta ( urn );-- --
CREATE INDEX idx_entry_created ON entry_meta ( created );-- --
CREATE INDEX idx_entry_updated ON entry_meta ( updated );-- --
CREATE INDEX idx_entry_pub ON entry_meta ( published ASC )
	WHERE published IS NOT NULL;-- --
CREATE INDEX idx_entry_sort ON entry_meta ( sort_order ASC );-- --
CREATE INDEX idx_entry_status ON entry_meta ( status );-- --

CREATE TABLE entry_desc (
	entry_id INTEGER NOT NULL,
	title TEXT NOT NULL DEFAULT '' COLLATE NOCASE,
	slug TEXT NOT NULL DEFAULT '' COLLATE NOCASE,
	summary TEXT DEFAULT NULL COLLATE NOCASE,
	rights TEXT DEFAULT NULL COLLATE NOCASE,
	language_id INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_entry_desc
		FOREIGN KEY ( entry_id ) 
		REFERENCES entries ( id )
		ON DELETE CASCADE,
		
	CONSTRAINT fk_entry_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_entry_desc ON entry_desc ( entry_id );-- --
CREATE INDEX idx_entry_title ON entry_desc ( title )
	WHERE title IS NOT '';-- --
CREATE INDEX idx_entry_slug ON entry_desc ( slug )
	WHERE slug IS NOT '';-- --
CREATE INDEX idx_entry_language ON entry_desc ( language_id )
	WHERE language_id IS NOT NULL;-- --

-- Entry description and title searching
CREATE VIRTUAL TABLE entry_desc_search 
	USING fts4( content, tokenize=unicode61 );-- --

-- Revision history
CREATE TABLE entry_content (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	entry_id INTEGER NOT NULL,
	language_id INTEGER DEFAULT NULL,
	created DATETIME DEFAULT CURRENT_TIMESTAMP,
	
	-- Content filtered and stripped of tags
	plain TEXT DEFAULT '' COLLATE NOCASE,
	-- Content exactly as entered
	content TEXT DEFAULT '' COLLATE NOCASE,
	
	CONSTRAINT fk_content_entry
		FOREIGN KEY ( entry_id ) 
		REFERENCES entries ( id )
		ON DELETE CASCADE,
		
	CONSTRAINT fk_content_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
-- Entry content is normally insert-only to preserve revisions
CREATE INDEX idx_entry_content_sort ON 
	entry_content ( created DESC, entry_id );-- --
CREATE INDEX idx_entry_content_language ON 
	entry_content ( language_id );-- --

-- Entry content body searching
CREATE VIRTUAL TABLE entry_content_search 
	USING fts4( content, tokenize=unicode61 );-- --




-- Entry description view
CREATE VIEW entry_view AS SELECT 
	e.id AS id, 
	
	em.urn AS urn, 
	em.created AS created, 
	em.updated AS updated, 
	em.published AS published, 
	em.sort_order AS sort_order, 
	em.status AS status, 
	
	ed.title AS title, 
	ed.slug AS slug, 
	ed.summary AS summary, 
	ed.rights AS rights,  
	ed.language_id AS language_id, 
	
	e.is_draft AS is_draft, 
	et.info AS type_settings, 
	t.settings_override AS type_settings_override, 
	es.settings AS entry_settings, 
	e.settings_override AS settings_override
	
	FROM entries e 
	INNER JOIN entry_meta em ON e.id = em.entry_id 
	INNER JOIN entry_types t ON e.type_id = t.id 
	LEFT JOIN entry_desc ed ON e.id = ed.entry_id 
	LEFT JOIN settings et ON t.settings_id = et.id 
	LEFT JOIN settings es ON e.settings_id = es.id;-- --


-- Content edit view
-- Usage:
-- SELECT * FROM entry_view WHERE entry_content.entry_id = :id
CREATE VIEW entry_content_view AS SELECT
	entry_content.id AS id,
	entries.id AS entry_id, 
	entries.title AS entry_title, 
	ec.content AS content,
	ec.language_id AS language_id
	
	FROM entry_content ec
	INNER JOIN entries ON ec.entry_id = entries.id
	ORDER BY ec.created DESC;-- --


-- Entry trigger actions
CREATE TABLE entry_collections(
	entry_id INTEGER NOT NULL REFERENCES entries ( id )
		ON DELETE CASCADE,
	collection_id INTEGER NOT NULL REFERENCES collections ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_entry_collection ON 
	entry_collections( entry_id, collection_id );-- --


-- New entry, generate UUID
CREATE TRIGGER entry_insert AFTER INSERT ON entries FOR EACH ROW
BEGIN
	INSERT INTO entry_meta( entry_id, urn ) 
		VALUES ( NEW.id, ( SELECT id FROM uuid ) );
END;-- --

-- Entry meta update
CREATE TRIGGER entry_update AFTER UPDATE ON entry_desc FOR EACH ROW
BEGIN
	-- Change last modified
	UPDATE entry_meta SET updated = CURRENT_TIMESTAMP
		WHERE entry_id = NEW.id;
END;-- --

-- Latest revision
CREATE TRIGGER entry_content_insert AFTER INSERT ON entry_content 
FOR EACH ROW
BEGIN
	UPDATE entry_meta SET updated = CURRENT_TIMESTAMP
		WHERE entry_id = NEW.id;
END;-- --


CREATE TRIGGER entry_collection_insert AFTER INSERT ON entry_collections
FOR EACH ROW
BEGIN
	UPDATE collection_meta SET entry_count = ( entry_count + 1 ) 
		WHERE collection_id = NEW.collection_id;
END;-- --

CREATE TRIGGER entry_collection_delete BEFORE DELETE ON entry_collections
FOR EACH ROW
BEGIN
	UPDATE collection_meta SET entry_count = ( entry_count - 1 ) 
		WHERE collection_id = OLD.collection_id;
END;-- --


-- Parent-child relationships
CREATE TABLE entry_sources (
	entry_id INTEGER NOT NULL REFERENCES entries ( id ) 
		ON DELETE CASCADE,
	source_entry_id INTEGER NOT NULL REFERENCES entries ( id ) 
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_entry_source ON 
	entry_sources ( entry_id, source_entry_id );-- --

-- Hierarchy
CREATE TRIGGER entry_parent AFTER INSERT ON entries FOR EACH ROW
WHEN entries.parent_id <> NULL
BEGIN
	INSERT INTO entry_sources ( entry_id, source_entry_id ) 
		VALUES ( NEW.rowid, NEW.parent_id );
END;-- --

-- ATOM user profiles
CREATE TABLE persons (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	urn TEXT DEFAULT NULL COLLATE NOCASE,
	user_id INTEGER NOT NULL,
	status INTEGER DEFAULT 0,
	
	CONSTRAINT fk_person_user
		FOREIGN KEY ( user_id )
		REFERENCES users ( id ) 
		ON DELETE CASCADE
);-- --
CREATE INDEX idx_persons_user ON persons ( user_id );-- --
CREATE INDEX idx_persons_status ON persons ( status );-- --

-- Region/locale specific profile content
CREATE TABLE person_desc (
	person_id INTEGER NOT NULL,
	title TEXT NOT NULL DEFAULT '' COLLATE NOCASE,
	name TEXT NOT NULL COLLATE NOCASE,
	uri TEXT DEFAULT NULL COLLATE NOCASE,
	bio TEXT DEFAULT NULL COLLATE NOCASE,
	contact TEXT DEFAULT NULL COLLATE NOCASE,
	language_id INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_eperson_desc
		FOREIGN KEY ( person_id ) 
		REFERENCES persons ( id )
		ON DELETE CASCADE,
		
	CONSTRAINT fk_person_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
CREATE INDEX idx_person_desc ON person_desc ( person_id );-- --
CREATE INDEX idx_person_name ON person_desc ( name );-- --
CREATE INDEX idx_person_title ON person_desc ( title )
	WHERE title IS NOT '';-- --
CREATE INDEX idx_person_contact ON person_desc ( contact )
	WHERE contact IS NOT NULL;-- --
CREATE INDEX idx_person_language ON person_desc ( language_id )
	WHERE language_id IS NOT NULL;-- --


CREATE TRIGGER person_insert AFTER INSERT ON persons FOR EACH ROW
BEGIN
	UPDATE pserons SET urn = ( SELECT id FROM uuid )
		WHERE id = NEW.id;
END;-- --

CREATE VIEW person_view AS SELECT 
	p.id AS id,
	p.urn AS urn,
	p.user_id AS user_id,
	p.status AS person_status,
	d.title AS title,
	d.name AS name,
	d.uri AS uri,
	d.bio AS bio,
	d.contact AS contact,
	d.language_id AS language_id

	FROM persons p
	LEFT JOIN person_desc d ON p.id = d.person_id;-- --


-- Editor ownership and collaboration
CREATE TABLE authors (
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	entry_id INTEGER NOT NULL,
	content_id INTEGER NOT NULL,
	person_id INTEGER NOT NULL,
	
	-- Currently editing
	checked_out INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_author_entry 
		FOREIGN KEY ( entry_id )
		REFERENCES entries ( id ) 
		ON DELETE CASCADE,
		
	CONSTRAINT fk_author_content 
		FOREIGN KEY ( content_id )
		REFERENCES entry_content ( id ) 
		ON DELETE CASCADE,
	
	CONSTRAINT fk_author_person 
		FOREIGN KEY ( person_id )
		REFERENCES persons ( id ) 
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_authors ON authors ( entry_id, content_id );-- --
CREATE INDEX idx_author_entry ON authors ( entry_id );-- --
CREATE INDEX idx_author_checked ON authors ( checked_out );-- --

CREATE TABLE author_meta(
	author_id INTEGER NOT NULL,
	updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	sort_order INTEGER DEFAULT 0, 
	
	CONSTRAINT fk_author_meta 
		FOREIGN KEY ( author_id )
		REFERENCES authors ( id ) 
		ON DELETE CASCADE
);-- --

-- Entry author meta
CREATE TRIGGER author_insert AFTER INSERT ON authors FOR EACH ROW
BEGIN
	INSERT INTO author_meta( author_id ) VALUES ( NEW.id );
END;-- --

-- Entry author meta update
CREATE TRIGGER author_update AFTER UPDATE ON authors FOR EACH ROW
BEGIN
	UPDATE author_meta SET updated = CURRENT_TIMESTAMP
		WHERE author_id = NEW.author_id;
END;-- --



-- Content locations
CREATE TABLE places(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
);-- --

-- Location plot
CREATE TABLE place_map(
	place_id INTEGER NOT NULL,
	
	-- Above/below sea level
	meters INTEGER NOT NULL DEFAULT 0,
	
	-- Coordinates
	geo_lat REAL NOT NULL DEFAULT 0, 
	geo_lon REAL NOT NULL DEFAULT 0,
	
	CONSTRAINT fk_map_place
		FOREIGN KEY ( place_id ) 
		REFERENCES places ( id )
		ON DELETE CASCADE
	
);-- --
CREATE INDEX idx_place_map ON place_map( place_id );-- --
CREATE UNIQUE INDEX idx_place_map_geo ON 
	place_map( geo_lat, geo_lon, meters );-- --

-- Region/locale specific place names
CREATE TABLE place_labels(
	place_id INTEGER INTEGER NOT NULL,
	label TEXT NOT NULL COLLATE NOCASE,
	language_id INTEGER DEFAULT NULL,
	
	CONSTRAINT fk_lang_place
		FOREIGN KEY ( place_id ) 
		REFERENCES places ( id )
		ON DELETE CASCADE,
	
	CONSTRAINT fk_place_lang
		FOREIGN KEY ( language_id ) 
		REFERENCES languages ( id )
		ON DELETE SET NULL
);-- --
CREATE UNIQUE INDEX idx_place ON place_labels ( place_id, label );-- --
CREATE INDEX idx_place_label ON place_labels ( label );-- --
CREATE INDEX idx_place_label_lang ON place_labels ( language_id ) 
	WHERE language_id IS NOT NULL;-- --

-- Location label searching
CREATE VIRTUAL TABLE place_search 
	USING fts4( content, tokenize=unicode61 );-- --


CREATE VIEW place_view AS SELECT
	places.id AS id,
	GROUP_CONCAT( pm.meters ) AS meters, 
	GROUP_CONCAT( pm.geo_lat ) AS geo_lat, 
	GROUP_CONCAT( pm.geo_lon ) AS geo_lon, 
	pl.label AS label,
	pl.language_id AS language_id
	
	FROM places
	LEFT JOIN place_map pm ON places.id = pm.place_id 
	LEFT JOIN place_labels pl ON places.id = pl.place_id;-- --
	

-- Entry locations
CREATE TABLE entry_places(
	entry_id INTEGER NOT NULL,
	place_id INTEGER NOT NULL,
	sort_order INTEGER NOT NULL DEFAULT 0,
	
	CONSTRAINT fk_place_entry
		FOREIGN KEY ( entry_id ) 
		REFERENCES entries ( id )
		ON DELETE CASCADE,
	
	CONSTRAINT fk_entry_place
		FOREIGN KEY ( place_id ) 
		REFERENCES places ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_entry_place ON 
	entry_places( entry_id, place_id );-- --
CREATE INDEX idx_entry_place_sort ON entry_places( sort_order );-- --

-- Category locations
CREATE TABLE category_places(
	category_id INTEGER NOT NULL,
	place_id INTEGER NOT NULL,
	sort_order INTEGER NOT NULL DEFAULT 0,
	
	CONSTRAINT fk_place_category
		FOREIGN KEY ( category_id ) 
		REFERENCES categories ( id )
		ON DELETE CASCADE,
	
	CONSTRAINT fk_category_place
		FOREIGN KEY ( place_id ) 
		REFERENCES places ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_cat_place ON 
	category_places( place_id, category_id );-- --
CREATE INDEX idx_cat_place_sort ON category_places( sort_order );-- --

-- Collection locations
CREATE TABLE collection_places(
	collection_id INTEGER NOT NULL,
	place_id INTEGER NOT NULL,
	sort_order INTEGER NOT NULL DEFAULT 0,
	
	CONSTRAINT fk_place_collection
		FOREIGN KEY ( collection_id ) 
		REFERENCES collections ( id )
		ON DELETE CASCADE,
	
	CONSTRAINT fk_collection_place
		FOREIGN KEY ( place_id ) 
		REFERENCES places ( id )
		ON DELETE CASCADE
);-- --
CREATE UNIQUE INDEX idx_coll_place ON 
	collection_places( place_id, collection_id );-- --
CREATE INDEX idx_coll_place_sort ON 
	collection_places( sort_order );-- --






-- Content views


-- Service document view for a site URL
-- Usage:
-- SELECT * FROM service_view WHERE basename = :basename
CREATE VIEW service_view AS SELECT
	sites.id AS id, 
	sites.title AS title,
	sites.basename AS basename,
	sites.basepath AS basepath,
	settings.info AS settings,
	sites.settings_override AS settings_override,
	GROUP_CONCAT(
		'id='			|| workspaces.id, ','
	) AS wkspaces,
	GROUP_CONCAT(
		'id='			|| collections.id	|| '&' || 
		'urn='			|| collection_meta.urn	|| '&' || 
		'workspace_id='		|| collections.workspace_id, ','
	) AS colls,
	GROUP_CONCAT(
		'id='			|| categories.id	|| '&' || 
		'urn='			|| category_meta.urn	|| '&' || 
		'collection_id='	|| categories.collection_id, ','
	) AS cats,
	GROUP_CONCAT(
		'id='			|| accept.id		|| '&' || 
		'mime_type='		|| accept.mime_type	|| '&' || 
		'collection_id='	|| accept.collection_id, ','
	) AS collaccept
	
	FROM sites
	INNER JOIN site_workspaces ON 
		sites.id = site_workspaces.site_id
	LEFT JOIN settings ON sites.settings_id = settings.id
	LEFT JOIN workspaces ON 
		site_workspaces.workspace_id = workspaces.id
	LEFT JOIN collections ON 
		workspaces.id = collections.workspace_id
	LEFT JOIN collection_meta ON collections.id = collection_meta.collection_id 
	LEFT JOIN categories ON collections.id = categories.collection_id
	LEFT JOIN category_meta ON categories.id = category_meta.category_id
	LEFT JOIN accept ON collections.id = accept.collection_id;-- --

-- Collection
-- Usage:
-- SELECT * FROM collection_view WHERE sites.basename = :basename
-- SELECT * FROM collection_view WHERE sites.id = :site_id
CREATE VIEW collection_view AS SELECT 
	collections.id AS id, 
	collections.urn AS urn,
	s.info AS settings,
	collections.settings_override AS settings_override,
	
	sites.id AS site_id,
	sites.title AS site_title,
	sites.basename AS basename,
	sites.basepath AS basepath,
	
	workspaces.id AS workspace_id,
	
	-- Collection accept types
	GROUP_CONCAT(
		'id='			|| accept.id		|| '&' || 
		'mime_type='		|| accept.mime_type	|| '&' || 
		'collection_id='	|| accept.collection_id, ','
	) AS colaccept,
	
	-- Collection categories
	GROUP_CONCAT(
		'id='			|| categories.id	|| '&' || 
		'urn='			|| category_meta.urn	|| '&' || 
		'collection_id='	|| categories.collection_id, ','
	) AS cats
		
	FROM collections
	INNER JOIN site_workspaces ON 
		collections.workspace_id = site_workspaces.workspace_id
	INNER JOIN sites ON site_workspaces.site_id = sites.id
	LEFT JOIN settings s ON sites.settings_id = s.id
	LEFT JOIN workspaces ON site_workspaces.workspace_id = workspaces.id
	LEFT JOIN categories ON collections.id = categories.collection_id
	LEFT JOIN category_meta ON categories.id = category_meta.category_id
	LEFT JOIN accept ON collections.id = accept.collection_id;-- --




