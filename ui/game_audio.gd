extends Node
var enabled = true
var player: AudioStreamPlayer
var sounds: Dictionary = {}

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -18
	add_child(player)
	for entry in [["move",150.0,0.08],["hit",85.0,0.12],["victory",660.0,0.3],["click",440.0,0.05]]:
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var length = int(22050*entry[2])
		var samples = PackedByteArray()
		samples.resize(length*2)
		for i in range(length):
			var t = float(i)/22050.0
			var envelope = 1.0-float(i)/length
			var value = int(sin(t*TAU*entry[1])*envelope*16000)
			samples.encode_s16(i*2,value)
		wav.data = samples
		sounds[entry[0]] = wav

func play(sound: String) -> void:
	if enabled and sounds.has(sound):
		player.stream = sounds[sound]
		player.play()
