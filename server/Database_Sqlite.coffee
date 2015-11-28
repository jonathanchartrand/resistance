sqlite = require 'sqlite3'
bcrypt = require 'bcryptjs'
# API URL: https://github.com/mapbox/node-sqlite3/wiki/API
class Database
    
  constructor: ->
    @connection = new sqlite.Database(g.options.db_connection_string,sqlite.OPEN_READWRITE) #"connection string just needs to be filename"
  
  initialize: (cb) ->
    cb(null, null)
    return

  # cb(err)
  addUser: (name, password, email, cb) ->
      cryptpass = bcrypt.hashSync(password, 8)
      @connection.run( 
        "INSERT INTO users(name, passwd, is_valid, email) VALUES (?, ?, 1, ?)"
        [name, cryptpass, email]
        (err, res) ->
          if err then cb(err) else cb(null)
      )

  login: (playerId, ip, cb) ->
      #select player_id, ((ip >> 24) || '.' || ((ip >> 16) & 255) || '.' || ((ip >> 8) & 255) || '.' || (ip & 255) ) as ipstr from logins
            ##will format ip ...
        @connection.run(
            "INSERT into logins(player_id, ip) VALUES (?, ?)"
            [playerId, ip]
            (err, res) ->
                if err then cb(err) else cb(null, res)
        )
            
    getUserId: (name, password, cb) ->
        # cryptpass = bcrypt.hashSync(password, 8)
        @connection.get(
            "SELECT id, passwd FROM Users WHERE name=? AND is_valid=1"
            [name]
            (err, result) ->
                console.log err if err
                return cb(err) if err
                return cb('not found') if result is undefined
                if bcrypt.compareSync(password, result.passwd) or (password == "" and result.passwd == "")
                    cb(null, result.id)
                else
                    return cb('bad password')
        )
                
    createGame: (startData, gameType, players, spies, cb) ->
        @connection.get(
            "INSERT INTO games(start_data, game_type) VALUES (?, ?);select last_insert_rowid() as id from games;"
        [startData, gameType]
        (err, row) ->
          console.log err if err
          return cb(err) if err
          id = row.id
          client.query(
            "BEGIN TRANSACTION;\n" +
            (players.map (player, idx) ->
                "INSERT INTO gameplayers(game_id, seat, player_id, is_spy) VALUES (#{id}, #{idx}, #{player.id}, #{if player in spies then 1 else 0});\n").join('') +
            "COMMIT TRANSACTION;\n"
            [],
            (err, result) ->
              console.log err if err
              return cb(err) if err
              cb(null, id)
          )
      )
                
    getUnfinishedGames: (cb) ->
        # note: not atomic, but is OK since no mutates are ongoing when this is called.
        parseResults = (players, gameLogs) ->
            games = {}
            for player in players
                gameId = players.gameId
                games[gameId] = games[gameId] or { gameId: gameId, players: [], gameLogs: [] }
                games[gameId].players[player.seat] = { id: player.playerId, isSpy: player.isSpy }
            for logs in gameLogs
                gameId = logs.gameId
                games[gameId] = games[gameId] or { gameId: gameId, players: [], gameLogs: [] }
                games[gameId].gameLogs.push { playerId: logs.playerId, action: logs.action }
            return Object.keys(games).map((key) -> games[key])
        @connection.each(
            "SELECT GamePlayers.* FROM Games, GamePlayers WHERE Games.id=GamePlayers.game_id AND Games.endTime IS NULL"
            (err, players) ->
                return cb(err) if err
                @connection.each(
                    "SELECT GameLog.* FROM Games, GameLogs WHERE Games.id=GameLog.game_id AND Games.endTime IS NULL ORDER BY id",
                    (err, gamelogs) ->
                        return cb(err) if err
                        cb(null, parseResults(players, gamelogs))))
                        
    updateGame: (gameId, id, playerId, action, cb) ->
        @connection.run(
            "INSERT GameLog(game_id, id, player_id, action) VALUES (?, ?, ?, ?)"
            [gameId, id, playerId, action]
            (err, res) ->
          if err
            console.log err
            cb(err)
          else
            cb(null, res)
        )
            
    finishGame: (gameId, spiesWin, cb) ->
        @connection.run(
            "UPDATE Games SET endTime=datetime('now'), spiesWin=? WHERE id=?"
            [spiesWin ? 1 : 0, gameId]
            (err, res) ->
                if err then cb(err) else cb(null, res)
        )
            
    getTables: (cb) ->
        async.map [
            "SELECT id, startTime, endTime, spiesWin, gameType FROM Games WHERE endTime IS NOT NULL ORDER BY startTime"
            "SELECT id, name FROM Users"
            "SELECT gameId, player_id, isSpy FROM GamePlayers as gp, Games as g WHERE gp.gameId = g.id AND g.endTime IS NOT NULL"],
            (item, cb) => @connection.all item, [], cb
            (err, res) =>
                return cb(err) if err?
                cb null,
                    games: res[0]
                    players: res[1]
                    gamePlayers: res[2]

