sqlite = require 'sqlite3'
bcrypt = require 'bcryptjs'
# API URL: https://github.com/mapbox/node-sqlite3/wiki/API
class Database
    
  constructor: ->
    @connection = new sqlite.Database(g.options.db_connection_string,sqlite3.OPEN_READWRITE) #"connection string just needs to be filename"
  
  initialize: (cb) ->
    cb(null, null)
    return

  # cb(err)
  addUser: (name, password, email, cb) ->
      cryptpass = bcrypt.hashSync(password, 8)
        @connection.run( 
            "INSERT INTO users(name, passwd, is_valid, email) VALUES (?, ?, true, ?)"
            [name, cryptpass, email]
            cb)

  login: (playerId, ip, cb) ->
        @connection.run(
            "INSERT Logins(playerId, ip) VALUES (?, ?)" 
            #select player_id, ((ip >> 24) || '.' || ((ip >> 16) & 255) || '.' || ((ip >> 8) & 255) || '.' || (ip & 255) ) as ipstr from logins
            ##will format ip ...
            [playerId, ip]
            cb)
            
    getUserId: (name, password, cb) ->
        cryptpass = bcrypt.hashSync(password, 8)
        @connection.each(
            "SELECT id FROM Users WHERE name=? AND passwd=? AND isValid=1"
            [name, cryptpass]
            (err, result) ->
                console.log err if err
                return cb(err) if err
                return cb('not found') if result.length isnt 1
                cb(null, result[0].id))
                
    createGame: (startData, gameType, players, spies, cb) ->
        @connection.run(
            "BEGIN TRANSACTION CreateGame\n" +
            "SET XACT_ABORT ON\n" +
            "DECLARE @gameId INT\n" +
            "INSERT Games(startData, gameType) VALUES (?, ?);\n" +
            "SET @gameId=@@IDENTITY\n" +
            (players.map (player, idx) -> 
                "INSERT GamePlayers(gameId, seat, playerId, isSpy) VALUES (@gameId, #{idx}, #{player.id}, #{if player in spies then 1 else 0})\n").join('') +
            "COMMIT TRANSACTION CreateGame\n" +
            "SELECT @gameId AS id"    
            [startData, gameType]
            (err, result) ->
                console.log err if err?
                return cb(err) if err
                cb(null, result[0].id) if result.length > 0)
                
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
            "SELECT GamePlayers.* FROM Games, GamePlayers WHERE Games.id=GamePlayers.gameId AND Games.endTime IS NULL"
            (err, players) ->
                return cb(err) if err
                @connection.each(
                    "SELECT GameLog.* FROM Games, GameLogs WHERE Games.id=GameLog.gameId AND Games.endTime IS NULL ORDER BY id",
                    (err, gamelogs) ->
                        return cb(err) if err
                        cb(null, parseResults(players, gamelogs))))
                        
    updateGame: (gameId, id, playerId, action, cb) ->
        @connection.query(
            "INSERT GameLog(gameId, id, playerId, action) VALUES (?, ?, ?, ?)"
            [gameId, id, playerId, action]
            cb)
            
    finishGame: (gameId, spiesWin, cb) ->
        @connection.query(
            "UPDATE Games SET endTime=datetime('now'), spiesWin=? WHERE id=?"
            [spiesWin, gameId]
            cb)
            
    getTables: (cb) ->
        async.map [
            "SELECT id, startTime, endTime, spiesWin, gameType FROM Games WHERE endTime IS NOT NULL ORDER BY startTime"
            "SELECT id, name FROM Users"
            "SELECT gameId, playerId, isSpy FROM GamePlayers as gp, Games as g WHERE gp.gameId = g.id AND g.endTime IS NOT NULL"],
            (item, cb) => @connection.each, item, [], cb
            (err, res) =>
                return cb(err) if err?
                cb null,
                    games: res[0]
                    players: res[1]
                    gamePlayers: res[2]

