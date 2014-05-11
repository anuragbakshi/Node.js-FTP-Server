net = require "net"
fs = require "fs"
sys = require "sys"
childProcess = require "child_process"

NAME = "Node.js FTP Server"
ARGUMENTS = process.argv[-1..]
LOGINS =
	"anuragbakshi": "12221997"

COMMAND_HANDLERS =
	EPSV: (state, arg) ->
		if state.loggedIn
			state.epsvServer = net.createServer (socket) ->
				state.epsvConnected = yes
				state.epsvSocket = socket

			state.epsvServer.listen 0
			state.controlSocket.write "229 Entering Extended Passive Mode (|||#{state.epsvServer.address().port}|)\n"
		else
			state.controlSocket.write "530 Please login with USER and PASS.\n"

	LIST: (state, arg) ->
		if state.loggedIn
			if state.epsvConnected
				state.controlSocket.write "150 Opening ASCII mode data connection for '/bin/ls'.\n"

				childProcess.exec "ls -lA", (error, stdout, stderr) ->
					state.epsvSocket.write stdout
					state.controlSocket.write "226 Transfer complete.\n"		# TODO: Put in callback so it really writes after data is sent.
			else
				state.controlSocket.write "425 Can't build data connection: Connection refused.\n"		# TODO: Add active support.
		else
			state.controlSocket.write "530 Please login with USER and PASS.\n"

	PASS: (state, arg) ->
		state.pass = arg

		if LOGINS[state.user] is state.pass
			state.loggedIn = yes
			state.controlSocket.write "230 User #{state.user} logged in.\n"
		else
			state.loggedIn = no
			state.controlSocket.write "530 Login incorrect.\n"

	USER: (state, arg) ->
		state.user = arg

		state.controlSocket.write "331 User #{arg} accepted, provide password.\n"

ftpClientHandler = (socket) ->
	socket.write "220 #{NAME} ready.\n"

	state =
		loggedIn: no
		epsvConnected: no
		currentDirectory: process.cwd()
		controlSocket: socket

	socket.on "data", (data) ->
		args = data.toString().trim().split " "

		COMMAND_HANDLERS[args[0]] state, args[1]

server = net.createServer ftpClientHandler
server.listen ARGUMENTS[0]
