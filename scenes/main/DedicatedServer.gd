extends Node

var version = "1.0"

var network = NetworkedMultiplayerENet.new()
var port = 25565
var max_players = 10
var player_state_collection: Dictionary = {}

onready var player_container_scene = preload("res://scenes/instances/PlayerContainer.tscn")

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
	rpc_id(0, "spawn_player", pid, Vector2(350, 350))
	
func _peer_disconnected(pid: int):
	print("User " + str(pid) + " disconnected")
	if has_node(str(pid)):
		get_node(str(pid)).queue_free()
		var _erase_err = player_state_collection.erase(pid)
		rpc_id(0, "despawn_player", pid)

func _ready():
	print("Version " + version)
	var arguments = {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
	print(arguments)
	if arguments.has("port"):
		port = arguments["port"]
	start_server()
	
remote func receive_player_state(player_state):
	var pid: int = get_tree().get_rpc_sender_id()
	if player_state_collection.has(pid):
		if player_state_collection[pid]["T"] < player_state["T"]:
			player_state_collection[pid] = player_state
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
