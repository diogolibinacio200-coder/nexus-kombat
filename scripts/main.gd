extends Node2D
## Flow coordinator. Combat, input, presentation and persistence are independent.
const Combat = preload("res://scripts/combat.gd")
const Inputs = preload("res://scripts/input_manager.gd")
const Profile = preload("res://scripts/save_manager.gd")
const Sound = preload("res://scripts/audio_manager.gd")
const Arena = preload("res://scripts/arena_view.gd")
const UI = preload("res://scripts/interface.gd")
const AI = preload("res://scripts/ai.gd")
const STAGES = ["NEXUS ARENA", "CYBER CITY", "TEMPLE OF TIME", "VOID STATION", "FROZEN DISTRICT", "SOLAR TEMPLE", "THUNDER TOWER", "REACTOR CORE", "UNIVERSITY NEXUS", "FINAL DIMENSION"]
const STAGE_SUB = ["O ponto de encontro de todas as energias", "Entre neon, chuva e concreto", "O passado ainda está em movimento", "Na fronteira do espaço conhecido", "Silêncio sob os cristais", "Onde a luz ganha forma", "Acima das nuvens, dentro da tempestade", "O coração térmico do Nexus", "Conhecimento além da realidade", "Toda dimensão tem um limite"]
const MENU = ["ARCADE", "VERSUS", "TRAINING", "TOURNAMENT", "HOW TO PLAY", "SETTINGS", "STATISTICS", "CREDITS", "EXIT"]
const TRAIN_OPTIONS = ["DUMMY", "VIDA INFINITA", "ENERGIA INFINITA", "GUARDA INFINITA", "HITBOXES", "RESET DE POSIÇÃO", "VOLTAR"]
const DIFFICULTIES = ["EASY", "NORMAL", "HARD", "MASTER"]
var input = Inputs.new()
var profile = Profile.new()
var sound = Sound.new()
var combat = Combat.new()
var arena = Arena.new()
var ui = UI.new()
var bots = [AI.new(1047), AI.new(2048)]
var screen = "boot"
var screen_time = 0.0
var clock_time = 0.0
var idle_frames = 0
var menu_index = 1
var mode = "versus"
var cursors = [0, 3]
var chosen = [0, 3]
var ready_players = [false, false]
var stage = 0
var stage_cursor = 0
var wins = [0, 0]
var round_number = 1
var result_index = 0
var pause_index = 0
var settings_index = 0
var help_page = 0
var previous_screen = "menu"
var controls_player = 0
var controls_index = 0
var capturing_binding = false
var binding_capture_wait_release = false
var shutting_down = false
var controls_actions = ["up", "down", "left", "right", "attack", "power", "block"]
var toast = ""
var toast_timer = 0.0
var escape_pressed = false
var enter_pressed = false
var tab_pressed = false
var reset_pressed = false
var debug_pressed = false
var any_pressed = false
var debug_view = false
var match_winner = -1
var round_end_timer = 0
var intro_frames = 0
var notices: Array = []
var input_history = [[], []]
var tutorial = false
var tutorial_step = 0
var tutorial_hits = 0
var tutorial_move_start = 0.0
var tutorial_done = false
var train_options = {"dummy": 0, "health": true, "meter": true, "guard": false, "boxes": false}
var train_index = 0
var arcade_order: Array = []
var arcade_index = 0
var tournament_roster: Array = []
var tournament_winners: Array = []
var tournament_round = 0
var tournament_cursor = 0
var tutorial_last_step = -1
var ai_frame = 0
var command_capture = ""
var command_screen = ""
var command_quit = 0
var elapsed_frames = 0
var music_context = ""
var event_counts = {"perfect_blocks":0, "guard_breaks":0, "supers":0, "biggest_combo":0}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	profile.load_profile()
	input.load_bindings(profile.data.get("bindings", {}))
	add_child(sound)
	add_child(arena)
	add_child(ui)
	ui.app = self
	arena.z_index = 0
	ui.z_index = 10
	apply_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			command_capture = arg.trim_prefix("--capture=")
		if arg.begins_with("--screen="):
			command_screen = arg.trim_prefix("--screen=")
		if arg.begins_with("--quit-after="):
			command_quit = int(arg.trim_prefix("--quit-after="))
		if arg == "--windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280,720))
	if not command_screen.is_empty():
		set_screen(command_screen)
		if command_screen in ["fight", "pause", "training_menu", "result"]:
			start_match()
			intro_frames = 0
			set_screen(command_screen)
			combat.fighters[0].meter = 76
			combat.fighters[1].meter = 43
			combat.fighters[0].x = 445
			combat.fighters[1].x = 835
		if command_screen == "result":
			match_winner = 0
		if command_screen == "select":
			ready_players = [false,false]
	play_music("menu")

func apply_settings() -> void:
	var s: Dictionary = profile.data.settings
	sound.set_levels(float(s.music), float(s.sfx))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not s.fullscreen:
		DisplayServer.window_set_size(Vector2i(1280,720) if int(s.resolution) == 0 else Vector2i(1920,1080))
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	arena.set("shake_strength", float(s.shake))
	arena.set("flash_strength", float(s.flashes))

func persist() -> void:
	profile.data.bindings = input.export_bindings()
	profile.save_profile()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "fight" and mode != "attract" and command_capture.is_empty():
		pause_index = 0
		set_screen("pause")

func _input(event: InputEvent) -> void:
	if shutting_down: return
	if event is InputEventKey and event.pressed and not event.echo:
		any_pressed = true
		if capturing_binding:
			if event.physical_keycode != KEY_ESCAPE:
				if input.set_binding(controls_player, controls_actions[controls_index], event.physical_keycode):
					persist()
					show_toast("COMANDO SALVO")
				else: show_toast("TECLA RESERVADA AO SISTEMA")
			finish_binding_capture()
			return
		escape_pressed = event.physical_keycode == KEY_ESCAPE or escape_pressed
		if event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and screen in ["fight","pause"]:
			escape_pressed = true
			return
		enter_pressed = event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] or enter_pressed
		tab_pressed = event.physical_keycode == KEY_TAB or tab_pressed
		reset_pressed = event.physical_keycode == KEY_R or reset_pressed
		debug_pressed = event.physical_keycode == KEY_F3 or debug_pressed
		if event.physical_keycode == KEY_F11:
			profile.data.settings.fullscreen = not profile.data.settings.fullscreen
			apply_settings()
			persist()
	if event is InputEventJoypadButton and event.pressed:
		any_pressed = true
		if capturing_binding:
			if event.button_index != JOY_BUTTON_BACK:
				if input.set_gamepad_binding(controls_player,controls_actions[controls_index],event.button_index,event.device):
					persist()
					show_toast("CONTROLE ARCADE SALVO")
				else: show_toast("BOTÃO RESERVADO AO SISTEMA")
			finish_binding_capture()
			return
		if event.button_index == JOY_BUTTON_START:
			if screen in ["fight","pause"]:
				escape_pressed = true
			else:
				enter_pressed = true
		if event.button_index == JOY_BUTTON_BACK:
			escape_pressed = true

func finish_binding_capture() -> void:
	capturing_binding = false
	binding_capture_wait_release = true
	escape_pressed = false
	enter_pressed = false
	any_pressed = false
	get_viewport().set_input_as_handled()

func quit_game() -> void:
	if shutting_down: return
	shutting_down = true
	persist()
	await sound.shutdown()
	get_tree().quit()

func _process(delta: float) -> void:
	clock_time += delta
	screen_time += delta
	toast_timer = maxf(0.0, toast_timer-delta)
	for n in notices:
		n.age += delta
	notices = notices.filter(func(n): return n.age < 1.3)
	arena.visible = screen in ["boot", "menu", "select", "stage", "vs", "fight", "pause", "result", "ending", "training_menu", "tournament", "tournament_result"]
	arena.stage_id = stage
	arena.paused = screen in ["pause", "training_menu"]
	arena.combat = combat if screen in ["fight", "pause", "result", "training_menu"] else null
	arena.alternate = [false, chosen[0] == chosen[1]]
	arena.debug = debug_view or (mode == "training" and train_options.boxes)
	ui.queue_redraw()

func _physics_process(_delta: float) -> void:
	if shutting_down: return
	elapsed_frames += 1
	input.update()
	var p: Array = [input.sample(0), input.sample(1)]
	var active_input = any_pressed
	for commands in p:
		for key in commands:
			if key.ends_with("_pressed") and commands[key]:
				active_input = true
	if active_input:
		idle_frames = 0
	else:
		idle_frames += 1
	if screen == "boot" and (screen_time > 1.6 or active_input):
		set_screen("menu")
	elif screen == "menu":
		tick_menu(p)
	elif screen == "select":
		tick_select(p)
	elif screen == "stage":
		tick_stage(p)
	elif screen == "vs":
		if screen_time > 3.4 or confirm(p,0) or confirm(p,1):
			start_match()
	elif screen == "fight":
		tick_fight(p, active_input)
	elif screen == "pause":
		tick_pause(p)
	elif screen == "result":
		tick_result(p)
	elif screen == "settings":
		tick_settings(p)
	elif screen == "controls":
		tick_controls(p)
	elif screen == "help":
		tick_help(p)
	elif screen == "training_menu":
		tick_training_menu(p)
	elif screen == "tournament":
		tick_tournament(p)
	elif screen == "tournament_result":
		if confirm(p,0) or confirm(p,1):
			if tournament_round >= 3:
				set_screen("menu")
			else:
				prepare_tournament_match()
	elif screen == "ending":
		if screen_time > 1 and (confirm(p,0) or escape_pressed):
			set_screen("menu")
	elif screen in ["stats", "credits"]:
		if confirm(p,0) or confirm(p,1) or escape_pressed:
			set_screen("menu")
	if debug_pressed and screen == "fight":
		debug_view = not debug_view
	escape_pressed = false
	enter_pressed = false
	tab_pressed = false
	reset_pressed = false
	debug_pressed = false
	any_pressed = false
	if not command_capture.is_empty() and elapsed_frames == 150:
		capture_frame.call_deferred()
	if command_quit > 0 and elapsed_frames > command_quit:
		quit_game()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var shot = get_viewport().get_texture().get_image()
	shot.save_png(command_capture)
	print("SCREENSHOT: " + command_capture)

func set_screen(next: String) -> void:
	screen = next
	screen_time = 0.0
	idle_frames = 0
	match next:
		"menu": play_music("menu")
		"select", "stage", "tournament": play_music("selection")
		"vs": play_music("vs")
		"fight": play_music("arena")
		"result", "ending", "tournament_result": play_music("victory")

func play_music(context: String) -> void:
	if music_context != context or context == "arena":
		sound.music(context, stage)
		music_context = context

func show_toast(text: String) -> void:
	toast = text
	toast_timer = 2.0

func confirm(p: Array, player: int) -> bool:
	return bool(p[player].get("attack_pressed", false)) or (enter_pressed and player == 0)

func axis(p: Array, horizontal: bool = false, player: int = -1) -> int:
	var value = 0
	for i in range(2):
		if player >= 0 and i != player:
			continue
		value += int(p[i].get("right_pressed" if horizontal else "down_pressed", false))
		value -= int(p[i].get("left_pressed" if horizontal else "up_pressed", false))
	return clampi(value, -1, 1)

func navigate(index: int, direction: int, count: int) -> int:
	if direction != 0:
		sound.play("select")
	return posmod(index+direction, count)

func tick_menu(p: Array) -> void:
	menu_index = navigate(menu_index, axis(p), MENU.size())
	if confirm(p,0) or confirm(p,1):
		sound.play("confirm")
		match menu_index:
			0: begin_mode("arcade")
			1: begin_mode("versus")
			2: begin_mode("training")
			3:
				mode = "tournament"
				tournament_roster = []
				tournament_winners = []
				tournament_round = 0
				tournament_cursor = 0
				set_screen("tournament")
			4:
				help_page = 0
				previous_screen = "menu"
				set_screen("help")
			5:
				settings_index = 0
				set_screen("settings")
			6: set_screen("stats")
			7: set_screen("credits")
			8:
				quit_game()
	if idle_frames > 1500 and profile.data.settings.arcade_mode:
		mode = "attract"
		chosen = [randi_range(0,6), randi_range(0,6)]
		stage = randi_range(0,9)
		start_match()
		combat.fighters[0].meter = 100
		combat.fighters[1].meter = 100

func begin_mode(next_mode: String) -> void:
	mode = next_mode
	tutorial = false
	cursors = [chosen[0], chosen[1]]
	ready_players = [false, next_mode in ["arcade", "training"]]
	set_screen("select")

func tick_select(p: Array) -> void:
	if escape_pressed:
		set_screen("menu")
		return
	for i in range(2):
		if i == 1 and mode in ["arcade", "training"]:
			continue
		if p[i].get("block_pressed",false):
			if not ready_players[i]:
				set_screen("menu")
				return
			ready_players[i] = false
		if ready_players[i]:
			continue
		var direction = axis(p,true,i)
		if axis(p,false,i) != 0:
			direction = axis(p,false,i)*4
		cursors[i] = navigate(cursors[i],direction,8)
		if confirm(p,i):
			chosen[i] = cursors[i] if cursors[i] < 7 else randi_range(0,6)
			cursors[i] = chosen[i]
			ready_players[i] = true
			sound.play("confirm")
	if ready_players[0] and ready_players[1]:
		if mode == "arcade":
			arcade_order.clear()
			for n in range(7):
				if n != chosen[0]: arcade_order.append(n)
			arcade_order.shuffle()
			arcade_order.resize(5)
			arcade_order.append(7)
			arcade_index = 0
			chosen[1] = arcade_order[0]
		if mode == "training": chosen[1] = (chosen[0]+1)%7
		stage_cursor = stage
		set_screen("stage")

func tick_stage(p: Array) -> void:
	if escape_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		ready_players[0] = false
		ready_players[1] = mode in ["arcade", "training"]
		set_screen("select")
		return
	var direction = axis(p,true)
	if axis(p) != 0: direction = axis(p)*5
	stage_cursor = navigate(stage_cursor,direction,11)
	stage = stage_cursor if stage_cursor < 10 else int(clock_time)%10
	if confirm(p,0) or confirm(p,1):
		if stage_cursor == 10: stage = randi_range(0,9)
		sound.play("confirm")
		set_screen("vs")

func start_match() -> void:
	wins = [0,0]
	round_number = 1
	match_winner = -1
	combat.setup(chosen,mode == "training")
	for key in event_counts: event_counts[key] = 0
	input_history = [[],[]]
	notices.clear()
	intro_frames = 200
	round_end_timer = 0
	set_screen("fight")
	if mode == "training":
		intro_frames = 0
		reset_training()
	if mode == "attract": intro_frames = 65
	sound.play("round_one")

func start_round() -> void:
	combat.reset_round()
	intro_frames = 120
	round_end_timer = 0
	notices.clear()
	input_history = [[],[]]
	sound.play("final_round" if is_final_round() else "round_two")

func is_final_round() -> bool:
	var required_wins: int = (int(profile.data.settings.rounds)+1)/2
	return wins[0] == required_wins-1 and wins[1] == required_wins-1

func tick_fight(p: Array, active: bool) -> void:
	if mode == "attract" and active:
		mode = "versus"
		set_screen("menu")
		return
	if escape_pressed and mode != "attract":
		pause_index = 0
		set_screen("pause")
		return
	if mode == "training" and tab_pressed:
		train_index = 0
		set_screen("training_menu")
		return
	if mode == "training" and reset_pressed:
		reset_training()
	if intro_frames > 0:
		intro_frames -= 1
		if (confirm(p,0) or confirm(p,1)) and intro_frames > 65:
			intro_frames = 65
		if intro_frames == 60: sound.play("fight")
		return
	if round_end_timer > 0:
		round_end_timer -= 1
		if round_end_timer == 0:
			resolve_round()
		return
	if mode == "arcade": p[1] = bots[1].think(combat,1,int(profile.data.settings.difficulty))
	if mode == "attract":
		p[0] = bots[0].think(combat,0,3)
		p[1] = bots[1].think(combat,1,2)
	if mode == "training":
		sync_training_options()
		p[1] = dummy_input()
		if train_options.guard:
			combat.fighters[0].guard = 100.0
			combat.fighters[1].guard = 100.0
		combat.time_frames = 99*60
	for i in range(2): record_input(i,p[i])
	combat.tick(p)
	consume_combat_events()
	if mode == "training":
		if tutorial: tick_tutorial()
		if combat.winner >= 0 or (not combat.cinematic.active and not train_options.health and (combat.fighters[0].hp <= 0 or combat.fighters[1].hp <= 0)):
			show_toast("K.O. • TREINO REINICIADO")
			reset_training()
	elif combat.winner >= 0:
		round_end_timer = 155
		sound.play("ko")
		if combat.winner < 2:
			var winner: Dictionary = combat.fighters[combat.winner]
			if winner.hp >= 1000:
				add_notice("PERFECT",combat.winner)
				sound.play("perfect")
			elif winner.hp < 180:
				add_notice("COMEBACK",combat.winner)

func record_input(player: int, commands: Dictionary) -> void:
	var keys: Array = []
	for k in ["up","down","left","right","attack","power","block"]:
		if commands.get(k+"_pressed",false): keys.append(k)
	if keys.is_empty(): return
	input_history[player].push_front(" + ".join(keys))
	if input_history[player].size() > 7: input_history[player].pop_back()

func consume_combat_events() -> void:
	arena.ingest_events(combat.events)
	var step_at_start: int = tutorial_step
	for e in combat.events:
		var kind = str(e.get("type","hit"))
		sound.play(kind,int(combat.fighters[int(e.get("player",0))].id))
		if kind in ["perfect_block","parry","counter","guard_break","throw_break","super","no_meter"]:
			add_notice(e.get("text",kind.to_upper().replace("_"," ")),int(e.get("player",0)))
		if kind == "perfect_block": event_counts.perfect_blocks += 1
		if kind == "guard_break": event_counts.guard_breaks += 1
		if kind == "super": event_counts.supers += 1
		if tutorial:
			if step_at_start == 1 and kind == "hit" and int(e.get("player",-1)) == 0: tutorial_hits += 1
			if step_at_start == tutorial_step:
				if step_at_start == 2 and kind in ["block","perfect_block","parry"] and int(e.get("player",-1)) == 0: advance_tutorial()
				elif step_at_start == 3 and kind in ["perfect_block","parry"] and int(e.get("player",-1)) == 0: advance_tutorial()
				elif step_at_start == 4 and kind == "guard_break" and int(e.get("player",-1)) == 1: advance_tutorial()
				elif step_at_start == 5 and kind in ["projectile","special"] and int(e.get("player",-1)) == 0: advance_tutorial()
				elif step_at_start == 7 and kind == "super" and int(e.get("player",-1)) == 0: advance_tutorial()
	for f in combat.fighters:
		event_counts.biggest_combo = maxi(event_counts.biggest_combo,int(f.combo))

func add_notice(text: String, player: int) -> void:
	notices.append({"text":text,"player":player,"age":0.0})
	if notices.size() > 6: notices.pop_front()

func resolve_round() -> void:
	if combat.winner < 0: return
	if combat.winner < 2:
		wins[combat.winner] += 1
	var goal_rounds: int = (int(profile.data.settings.rounds)+1)/2
	if wins[0] >= goal_rounds or wins[1] >= goal_rounds:
		match_winner = 0 if wins[0] > wins[1] else 1
		if mode == "attract":
			chosen = [randi_range(0,6), randi_range(0,6)]
			stage = (stage+1)%10
			start_match()
			return
		save_match()
		result_index = 0
		sound.play("player_one_wins" if match_winner == 0 else "player_two_wins")
		set_screen("result")
	else:
		round_number += 1
		start_round()

func save_match() -> void:
	var stats: Dictionary = profile.data.stats
	stats.matches = int(stats.get("matches",0))+1
	var win_key = "p1_wins" if match_winner == 0 else "p2_wins"
	stats[win_key] = int(stats.get(win_key,0))+1
	var played: Dictionary = stats.get("most_played",{})
	for fighter_id in chosen:
		var key = str(fighter_id)
		played[key] = int(played.get(key,0))+1
	stats.most_played = played
	for key in ["perfect_blocks","guard_breaks","supers"]:
		stats[key] = int(stats.get(key,0))+event_counts[key]
	stats.biggest_combo = maxi(int(stats.get("biggest_combo",0)),event_counts.biggest_combo)
	persist()

func result_options() -> Array:
	if mode == "arcade" and match_winner == 0: return ["CONTINUAR", "MENU PRINCIPAL"]
	if mode == "tournament": return ["VER CHAVEAMENTO", "MENU PRINCIPAL"]
	return ["REMATCH", "CHARACTER SELECT", "MENU PRINCIPAL"]

func tick_result(p: Array) -> void:
	if screen_time < 0.5: return
	var options = result_options()
	result_index = navigate(result_index,axis(p),options.size())
	if escape_pressed:
		set_screen("menu")
		return
	if confirm(p,0) or confirm(p,1):
		match options[result_index]:
			"REMATCH": start_match()
			"CHARACTER SELECT": begin_mode(mode)
			"MENU PRINCIPAL": set_screen("menu")
			"CONTINUAR":
				arcade_index += 1
				if arcade_index >= arcade_order.size():
					set_screen("ending")
				else:
					chosen[1] = arcade_order[arcade_index]
					stage = 9 if chosen[1] == 7 else (stage+1)%9
					set_screen("vs")
			"VER CHAVEAMENTO":
				tournament_winners.append(chosen[match_winner])
				tournament_round += 1
				set_screen("tournament_result")

func tick_pause(p: Array) -> void:
	var options = ["CONTINUAR", "CONTROLES", "LISTA DE GOLPES", "REINICIAR PARTIDA", "SELEÇÃO", "MENU PRINCIPAL"]
	if mode == "training": options.insert(3,"OPÇÕES DE TREINO")
	pause_index = navigate(pause_index,axis(p),options.size())
	if escape_pressed: set_screen("fight")
	if confirm(p,0) or confirm(p,1):
		match options[pause_index]:
			"CONTINUAR": set_screen("fight")
			"CONTROLES":
				previous_screen = "pause"
				controls_index = 0
				set_screen("controls")
			"LISTA DE GOLPES":
				previous_screen = "pause"
				help_page = 2+chosen[0]
				set_screen("help")
			"REINICIAR PARTIDA": start_match()
			"SELEÇÃO": begin_mode(mode)
			"MENU PRINCIPAL": set_screen("menu")
			"OPÇÕES DE TREINO": set_screen("training_menu")

func tick_settings(p: Array) -> void:
	if escape_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		set_screen("menu")
		return
	settings_index = navigate(settings_index,axis(p),11)
	var direction = axis(p,true)
	if confirm(p,0) or confirm(p,1): direction = 1
	var s: Dictionary = profile.data.settings
	if direction != 0:
		match settings_index:
			0: s.music = clampf(float(s.music)+direction*0.1,0,1)
			1: s.sfx = clampf(float(s.sfx)+direction*0.1,0,1)
			2: s.shake = clampf(float(s.shake)+direction*0.1,0,1)
			3: s.flashes = clampf(float(s.flashes)+direction*0.1,0,1)
			4: s.rounds = [1,3,5][posmod([1,3,5].find(int(s.rounds))+direction,3)]
			5: s.difficulty = posmod(int(s.difficulty)+direction,4)
			6: s.fullscreen = not s.fullscreen
			7: s.resolution = posmod(int(s.resolution)+direction,2)
			8: s.arcade_mode = not s.arcade_mode
			9:
				previous_screen = "settings"
				controls_index = 0
				set_screen("controls")
			10: set_screen("menu")
		apply_settings()
		persist()
	if escape_pressed: set_screen("menu")

func tick_controls(p: Array) -> void:
	if capturing_binding: return
	if binding_capture_wait_release:
		for commands in p:
			for action in controls_actions:
				if commands.get(action,false): return
		binding_capture_wait_release = false
		return
	if escape_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		set_screen(previous_screen)
		return
	controls_player = posmod(controls_player+axis(p,true),2)
	controls_index = navigate(controls_index,axis(p),9)
	if confirm(p,0) or confirm(p,1):
		if controls_index < 7:
			capturing_binding = true
		elif controls_index == 7:
			input.defaults()
			persist()
			show_toast("CONTROLES RESTAURADOS")
		else: set_screen(previous_screen)
	if escape_pressed: set_screen(previous_screen)

func tick_help(p: Array) -> void:
	help_page = navigate(help_page,axis(p,true),9)
	if escape_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		set_screen(previous_screen)
	if confirm(p,0) and previous_screen == "menu":
		mode = "training"
		tutorial = true
		tutorial_step = 0
		tutorial_hits = 0
		tutorial_done = false
		train_options.health = true
		train_options.meter = true
		train_options.guard = false
		chosen = [0,1]
		stage = 0
		start_match()
		tutorial_move_start = combat.fighters[0].x

func tick_training_menu(p: Array) -> void:
	if escape_pressed or tab_pressed or p[0].get("block_pressed",false) or p[1].get("block_pressed",false):
		set_screen("fight")
		return
	train_index = navigate(train_index,axis(p),TRAIN_OPTIONS.size())
	var direction = axis(p,true)
	if confirm(p,0): direction = 1
	if direction != 0:
		match train_index:
			0: train_options.dummy = posmod(int(train_options.dummy)+direction,5)
			1: train_options.health = not train_options.health
			2: train_options.meter = not train_options.meter
			3: train_options.guard = not train_options.guard
			4: train_options.boxes = not train_options.boxes
			5: reset_training()
			6: set_screen("fight")
	if escape_pressed or tab_pressed: set_screen("fight")

func reset_training() -> void:
	combat.reset_round()
	sync_training_options()
	if train_options.meter:
		for f in combat.fighters: f.meter = 100.0
	tutorial_move_start = combat.fighters[0].x
	input_history = [[],[]]

func sync_training_options() -> void:
	combat.training_options.infinite_health = bool(train_options.health)
	combat.training_options.infinite_meter = bool(train_options.meter)

func dummy_input() -> Dictionary:
	ai_frame += 1
	var behavior: int = train_options.dummy
	if tutorial:
		if tutorial_step in [2,3]: behavior = 3
		elif tutorial_step == 4: behavior = 1
		else: behavior = 0
	var commands: Dictionary = {}
	match behavior:
		1: commands = {"block":true,"down":true}
		2: commands = {"up":true,"up_pressed":ai_frame%45 == 0}
		3:
			var dist = combat.fighters[0].x-combat.fighters[1].x
			commands = {"left":dist < -100,"right":dist > 100,"attack":ai_frame%70 == 0,"attack_pressed":ai_frame%70 == 0}
		4: commands = bots[1].think(combat,1,int(profile.data.settings.difficulty))
	return commands

func tick_tutorial() -> void:
	if tutorial_done: return
	if tutorial_step == 0 and absf(combat.fighters[0].x-tutorial_move_start) > 130: advance_tutorial()
	if tutorial_step == 1 and tutorial_hits >= 3: advance_tutorial()
	if tutorial_step == 5 and not combat.fighters[0].move.is_empty():
		if combat.fighters[0].move.get("cost",0) > 0: advance_tutorial()
	if tutorial_step == 6 and combat.fighters[0].combo >= 2: advance_tutorial()

func advance_tutorial() -> void:
	if tutorial_step >= 8: return
	tutorial_step += 1
	sound.play("confirm")
	show_toast("ETAPA CONCLUÍDA")
	if tutorial_step >= 8: tutorial_done = true

func tick_tournament(p: Array) -> void:
	if escape_pressed:
		set_screen("menu")
		return
	tournament_cursor = navigate(tournament_cursor,axis(p,true),7)
	if confirm(p,0) or confirm(p,1):
		tournament_roster.append(tournament_cursor)
		tournament_cursor = (tournament_cursor+1)%7
		sound.play("confirm")
		if tournament_roster.size() == 4: prepare_tournament_match()

func prepare_tournament_match() -> void:
	if tournament_round < 2:
		chosen = [tournament_roster[tournament_round*2],tournament_roster[tournament_round*2+1]]
	else:
		chosen = [tournament_winners[0],tournament_winners[1]]
	stage_cursor = stage
	set_screen("stage")

func fighter_info(id: int) -> Dictionary:
	return combat.move_db.character(id)

func binding_label(player: int, action: String) -> String:
	return OS.get_keycode_string(input.get_binding(player,action))
