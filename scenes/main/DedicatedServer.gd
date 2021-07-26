extends Node

var version = "1.0"

var network = NetworkedMultiplayerENet.new()
var port: int = 56901
var max_players = 10
var player_state_collection: Dictionary = {}
var lobby_server = "http://161.35.124.177:56900"
var rng = RandomNumberGenerator.new()
var winner

onready var player_container_scene = preload("res://scenes/instances/PlayerContainer.tscn")
onready var http_request = HTTPRequest.new()

var readied_up_players = 0

func _ready():
	rng.randomize()
	get_tree().set_auto_accept_quit(false)
	add_child(http_request)
	var _error = http_request.connect("request_completed", self, "_handle_lobby_return")
	_error = $LobbyResetTimer.connect("timeout", self, "_reset_server")
	_error = $ShutdownTimer.connect("timeout", self, "_quit")
	print("Version " + version)
	var arguments = {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
	if arguments.has("port"):
		port = int(arguments["port"])
		print("port set to " + str(port))
	elif OS.get_environment("PORT") != "":
		port = int(OS.get_environment("PORT"))
		print("port set to " + str(port))
	http_request.request(lobby_server + "/server/add/" + str(port))

func _handle_lobby_return(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse(body.get_string_from_utf8()).result
		if json.has("response"):
			if json.response == "added":
				start_server()
			if json.response == "removed":
				_quit()

func start_server():
	var _server_status = network.create_server(port, max_players)
	get_tree().set_network_peer(network)
	print("Server started on port " + str(port))
	
	var _peer_connect_signal_status = network.connect("peer_connected", self, "_peer_connected")
	var _peer_disconnect_signal_status = network.connect("peer_disconnected", self, "_peer_disconnected")
	
func add_player_instance(pid: int):
	var new_player = player_container_scene.instance()
	new_player.name = str(pid)
	add_child(new_player, true)
	var player_container = get_node(str(pid))
	fill_player_container(player_container)
	
func fill_player_container(_player_conatiner):
	pass

func _peer_connected(pid: int):
	print("User " + str(pid) + " connected")
	add_player_instance(pid)
	rpc_id(0, "spawn_player", pid, Vector2(rng.randf_range(9, 67) * 10, 350))
	$LobbyResetTimer.stop()
	
func _peer_disconnected(pid: int):
	print("User " + str(pid) + " disconnected")
	if has_node(str(pid)):
		get_node(str(pid)).queue_free()
		var _erase_err = player_state_collection.erase(pid)
		rpc_id(0, "despawn_player", pid)
		if player_state_collection.size() == 0:
			$LobbyResetTimer.start()
	
remote func receive_player_state(player_state):
	var pid: int = get_tree().get_rpc_sender_id()
	if player_state_collection.has(pid):
		if player_state_collection[pid]["T"] < player_state["T"]:
			player_state_collection[pid] = player_state
		if player_state_collection[pid]["P"].y < -1069 and not winner:
			rpc("winner", pid)
			winner = true
	else:
		player_state_collection[pid] = player_state

func send_world_state(world_state):
	rpc_unreliable_id(0, "receive_world_state", world_state)

remote func fetch_server_time(client_time):
	var pid = get_tree().get_rpc_sender_id()
	rpc_id(pid, "return_server_time", OS.get_system_time_msecs(), client_time)
	
remote func determine_latency(client_time):
	var pid = get_tree().get_rpc_sender_id()
	rpc_id(pid, "return_latency", client_time)
	
remote func start_game():
	print("asking players to ready up")
	rpc("ready_up")
	
remote func ready_to_race():
	readied_up_players += 1
	print(str(readied_up_players) + " are ready to go, need " + str(player_state_collection.size()) + " total")
	if readied_up_players >= player_state_collection.size():
		rpc("start_race")
		winner = false
	
func _reset_server():
	readied_up_players = 0
	http_request.request(lobby_server + "/server/available/" + str(port))
	
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		http_request.request(lobby_server + "/server/remove/" + str(port))
		$ShutdownTimer.start()
		
func _quit():
	get_tree().quit()
