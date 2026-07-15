class_name CombatFeedback
extends RefCounted


static func create_synth_sound(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	noise_mix: float
) -> AudioStreamWAV:
	const MIX_RATE := 22050
	var sample_count := maxi(1, int(duration * MIX_RATE))
	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)
	var phase := 0.0

	for sample_index in range(sample_count):
		var progress := float(sample_index) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / MIX_RATE
		var noise := sin(float(sample_index) * 12.9898) * 43758.5453
		noise = (noise - floor(noise)) * 2.0 - 1.0
		var envelope := pow(1.0 - progress, 2.0)
		var waveform := lerpf(sin(phase), noise, noise_mix)
		var sample_value := int(
			clampf(waveform * envelope * 0.42, -1.0, 1.0) * 32767.0
		)
		audio_data.encode_s16(sample_index * 2, sample_value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = audio_data
	return stream


static func spawn_impact_particles(
	tree: SceneTree,
	impact_position: Vector2,
	impact_direction: Vector2,
	color: Color,
	amount: int,
	effect_name: String
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = effect_name
	particles.top_level = true
	particles.global_position = impact_position
	particles.z_index = 20
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.24
	particles.direction = impact_direction.normalized()
	particles.spread = 72.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 85.0
	particles.initial_velocity_max = 210.0
	particles.scale_amount_min = 1.6
	particles.scale_amount_max = 3.4
	particles.color = color
	particles.finished.connect(particles.queue_free)

	var effect_parent := tree.current_scene
	if effect_parent == null:
		effect_parent = tree.root
	effect_parent.add_child(particles)
	particles.restart()
	return particles


static func play_one_shot_sound(
	tree: SceneTree,
	position_value: Vector2,
	stream: AudioStream,
	volume_db: float,
	effect_name: String
) -> AudioStreamPlayer2D:
	var audio := AudioStreamPlayer2D.new()
	audio.name = effect_name
	audio.top_level = true
	audio.global_position = position_value
	audio.stream = stream
	audio.volume_db = volume_db
	audio.finished.connect(audio.queue_free)

	var effect_parent := tree.current_scene
	if effect_parent == null:
		effect_parent = tree.root
	effect_parent.add_child(audio)
	audio.play()
	return audio
