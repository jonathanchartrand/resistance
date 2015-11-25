DROP TABLE logins;
DROP TABLE gamelog;
DROP TABLE gameplayers;
DROP TABLE games;
DROP TABLE users;

/* Original schema: */

CREATE TABLE users
(
    id integer PRIMARY KEY autoincrement, 
    name nvarchar(32) NOT NULL UNIQUE check( length(name <= 32) ),
    passwd nvarchar NOT NULL, 
    is_valid BOOLEAN NOT NULL check( is_valid in (0,1) ),
    email nvarchar NOT NULL,
    create_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    validation_code nvarchar check( length(validation_code) <= 16)
);

CREATE TABLE games
( 
    id integer PRIMARY KEY autoincrement,
	game_type SMALLINT NOT NULL DEFAULT 1,
    start_data nvarchar NOT NULL, 
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    spies_win BOOLEAN NOT NULL check( spies_win in (0,1) )
);

CREATE TABLE gameplayers
(
    game_id integer NOT NULL REFERENCES games(id) ON DELETE CASCADE, 
    seat SMALLINT NOT NULL,
    player_id integer NOT NULL REFERENCES users(id),
    is_spy BOOLEAN NOT NULL check( is_spy in (0,1) ), 
    CONSTRAINT pk_gameplayers PRIMARY KEY (game_id, seat),
    CONSTRAINT unique_player UNIQUE (player_id, game_id)
);

CREATE TABLE gamelog
(
    game_id integer NOT NULL REFERENCES games(id) ON DELETE CASCADE, 
    id integer NOT NULL,
    player_id integer NOT NULL REFERENCES users(id), 
    action nvarchar NOT NULL,
    time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_gamelog PRIMARY KEY (game_id, id)
);

CREATE TABLE logins
(
	player_id integer NOT NULL REFERENCES users(id),
	time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	ip int NOT NULL
);

CREATE INDEX idx_logins on logins(player_id, time);

with pwd as (select '1234' as pw),
ue as (
select 'test' name,'test' eml
union all select '<Alpha>','alpha'
union all select '<Bravo>','bravo'
union all select '<Charlie>','charlie'
union all select '<Delta>','delta'
union all select '<Echo>','echo'
union all select '<Foxtrot>','foxtrot'
union all select '<Golf>','golf'
union all select '<Hotel>','hotel'
union all select '<India>','india'
union all select '<Juliet>','juliet'
)
insert into users (name,passwd,email,is_valid)
select u.name,p.pw,(u.eml||'@example.com'),1 from ue u,pwd p;
