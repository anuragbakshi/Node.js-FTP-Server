net = require "net"
fs = require "fs"
sys = require "sys"
childProcess = require "child_process"

NAME = "Node.js FTP Server"
SUPPORTED_TYPES = ["A", "N", "T", "E", "C", "I", "L"]
ARGUMENTS = process.argv[-1..]
LOGINS =
	"a": "b"

initDataServer = (state) ->
	state.dataServer = net.createServer (socket) ->
		state.dataConnected = yes
		state.dataSocket = socket

	state.dataServer.listen 0

COMMAND_HANDLERS =
	EPSV: (state, arg) ->
		if state.loggedIn
			initDataServer state
			state.controlSocket.write "229 Entering Extended Passive Mode (|||#{state.dataServer.address().port}|)\r\n"
		else
			state.controlSocket.write "530 Please login with USER and PASS.\r\n"

	FEAT: (state, arg) ->
		state.controlSocket.write "211-Features supported\r\n MDTM\r\n MLST Type*;Size*;Modify*;Perm*;Unique*;\r\n REST STREAM\r\n SIZE\r\n TVFS\r\n"
		state.controlSocket.write "211 End\r\n"

	LIST: (state, arg) ->
		if state.loggedIn
			if state.dataConnected
				state.controlSocket.write "150 Opening ASCII mode data connection for '/bin/ls'.\r\n"

				childProcess.exec "ls -lA", (error, stdout, stderr) ->
					state.dataSocket.write stdout
					state.controlSocket.write "226 Transfer complete.\r\n"		# TODO: Put in callback so it really writes after data is sent.
			else
				state.controlSocket.write "425 Can't build data connection: Connection refused.\r\n"		# TODO: Add active support.
		else
			state.controlSocket.write "530 Please login with USER and PASS.\r\n"

	PASS: (state, arg) ->
		state.pass = arg

		if LOGINS[state.user] is state.pass
			state.loggedIn = yes
			state.controlSocket.write "230 User #{state.user} logged in.\r\n"
		else
			state.loggedIn = no
			state.controlSocket.write "530 Login incorrect.\r\n"

	PASV: (state, arg) ->
		if state.loggedIn
			initDataServer state

			localAddress = state.controlSocket.localAddress.split "."
			dataPort = state.dataServer.address().port
			if localAddress.length is 4
				state.controlSocket.write "227 Entering Passive Mode (#{localAddress.join ","},#{Math.floor dataPort / 256},#{dataPort % 256})\r\n"
			else
				state.controlSocket.write "425 Can't open passive connection: Address family not supported by protocol family."
		else
			state.controlSocket.write "530 Please login with USER and PASS.\r\n"

	PWD: (state, arg) ->
		state.controlSocket.write "257 \"#{state.currentDirectory}\" is the current directory.\r\n"

	SYST: (state, arg) ->
		state.controlSocket.write "215 UNIX Type: L8\r\n"

	TYPE: (state, arg) ->
		if state.loggedIn
			if arg in SUPPORTED_TYPES
				state.type = arg

				state.controlSocket.write "200 Type set to #{arg}.\r\n"
			else
				state.controlSocket.write "500 'TYPE #{arg}': command not understood.\r\n"
		else
			state.controlSocket.write "530 Please login with USER and PASS.\r\n"

	USER: (state, arg) ->
		state.user = arg

		state.controlSocket.write "331 User #{arg} accepted, provide password.\r\n"

	QUIT: (state, arg) ->
		state.controlSocket.end "221 Thank you for using the FTP service on #{state.controlSocket.address().address}.\r\n"

ftpClientHandler = (socket) ->
	socket.write "220 #{NAME} ready.\r\n"

	state =
		loggedIn: no
		dataConnected: no
		currentDirectory: process.cwd()
		controlSocket: socket

	socket.on "data", (data) ->
		args = data.toString().trim().split " "

		console.log data.toString()
		COMMAND_HANDLERS[args[0]] state, args[1]

server = net.createServer ftpClientHandler
server.listen ARGUMENTS[0]
