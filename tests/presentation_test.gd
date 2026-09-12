extends SceneTree
## Integration/performance capture with actual renderer and simultaneous AI inputs.
var samples: Array = []
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var app = load("res://scripts/main.gd").new()
	app.profile = load("res://scripts/save_manager.gd").new("user://presentation_test_profile.json")
	root.add_child(app)
	app.set_physics_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	app.chosen = [0,3]
	app.mode = "versus"
	app.start_match()
	app.intro_frames = 0
	var start: int = Time.get_ticks_msec()
	var loops = 2400
	for frame in range(loops):
		if frame%240 == 0:
			app.stage = int(frame/240)%10
			app.chosen = [int(frame/240)%7,(int(frame/240)+3)%7]
			app.combat.setup(app.chosen,false)
			app.combat.fighters[0].meter = 100
			app.combat.fighters[1].meter = 100
			app.combat.fighters[0].x = 550
			app.combat.fighters[1].x = 730
		var commands = [app.bots[0].think(app.combat,0,3),app.bots[1].think(app.combat,1,3)]
		app.combat.tick(commands)
		app.consume_combat_events()
		if frame > 60 and frame%60 == 0:
			samples.append({"fps":Engine.get_frames_per_second(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0})
		await physics_frame
	var elapsed: float = (Time.get_ticks_msec()-start)/1000.0
	var fps: Array = []
	for sample in samples: fps.append(sample.fps)
	fps.sort()
	var report = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"resolution":"1280x720","simulated_frames":loops,"wall_seconds":elapsed,"steps_per_second":loops/elapsed,"fps_min":fps[0],"fps_median":fps[int(fps.size()/2)],"fps_max":fps[-1],"samples":samples}
	var path = "res://docs/performance.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PRESENTATION: ",JSON.stringify({"frames":loops,"seconds":elapsed,"fps_median":report.fps_median,"fps_min":report.fps_min,"gpu":report.renderer}))
	await app.sound.shutdown()
	app.queue_free()
	await process_frame
	quit()
