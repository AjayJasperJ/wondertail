extends Node
## Short synthesized cues and a quiet, looping original pentatonic score.
var volume := 0.4
var music := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0


func _ready() -> void:
	add_child(music)
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voices.append(voice)
		add_child(voice)
	var rate := 22050
	var bytes := PackedByteArray()
	bytes.resize(rate * 8 * 2)
	var notes := [261.63, 329.63, 392.0, 493.88, 440.0, 392.0, 329.63, 293.66]
	for i in range(rate * 8):
		var t := float(i) / rate
		var phase := fmod(t, 1.0)
		var f: float = notes[int(t) % notes.size()]
		var envelope := sin(PI * phase) * exp(-phase * 2)
		var sample := (sin(TAU * f * t) * 0.12 + sin(TAU * f * 0.5 * t) * 0.05) * envelope
		bytes.encode_s16(i * 2, int(sample * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = rate * 8
	music.stream = stream
	music.play()
	set_volume(volume)


func set_volume(value: float) -> void:
	volume = clampf(value, 0, 1)
	music.volume_db = linear_to_db(maxf(0.0001, volume * 0.65))
	for voice in voices:
		voice.volume_db = linear_to_db(maxf(0.0001, volume))


func cue(frequency: float, duration: float = 0.12, gain: float = 0.12) -> void:
	if voices.is_empty() or volume <= 0:
		return
	var rate := 22050
	var frames := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / rate
		var envelope := sin(PI * float(i) / frames)
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * t) * envelope * gain * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	var voice: AudioStreamPlayer = voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = stream
	voice.play()
