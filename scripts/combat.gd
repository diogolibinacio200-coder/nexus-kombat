extends RefCounted
## Fixed 60 Hz simulation: no wall clocks, rendering or hardware input here.
const Fighter = preload("res://scripts/fighter.gd")
const MoveDB = preload("res://scripts/move_db.gd")
const GROUND := 590.0
const EMPTY := {"left":false,"right":false,"up":false,"down":false,"attack":false,"power":false,"block":false,"attack_pressed":false,"power_pressed":false,"block_pressed":false,"up_pressed":false}
var move_db = MoveDB.new()
var fighters: Array = []
var projectiles: Array = []
var events: Array = []
var hitstop := 0
var winner := -1
var time_frames := 99 * 60
var tick_count := 0
var training := false
var training_options := {"infinite_health":true,"infinite_meter":true,"guard":"none","dummy":"idle"}
var round_duration := 99
var _serial := 0
var cinematic: Dictionary = {"active":false,"frame":0,"duration":270,"attacker":0,"defender":1,"character":0,"name":"","origin_a":0.0,"origin_d":0.0,"damage_total":0.0,"pulse":0}
var _trade_contacts := false

func setup(ids: Array = [0,1], is_training: bool = false) -> void:
	training = is_training
	fighters = [Fighter.create(int(ids[0]),0),Fighter.create(int(ids[1]),1)]
	reset_round()

func reset_round() -> void:
	if fighters.size() < 2:
		fighters = [Fighter.create(0,0),Fighter.create(1,1)]
	for i in 2:
		var old: Dictionary = fighters[i]
		var fresh: Dictionary = Fighter.create(old.id,i)
		fresh.round_wins = old.get("round_wins",0)
		fighters[i] = fresh
	projectiles.clear()
	events.clear()
	hitstop = 0
	winner = -1
	time_frames = round_duration * 60
	tick_count = 0
	_serial = 0
	cinematic.active = false
	cinematic.frame = 0
	_trade_contacts = false

func _event(type: String, p: int, text: String = "", extras: Dictionary = {}) -> void:
	var f: Dictionary = fighters[clampi(p,0,1)]
	var ev := {"type":type,"player":p,"x":f.x,"y":f.y - 110.0,"text":text}
	ev.merge(extras,true)
	events.append(ev)

func _meter(f: Dictionary, amount: float) -> void:
	var before: float = f.meter
	f.meter = clampf(f.meter + amount,0.0,100.0)
	if before < 100.0 and f.meter >= 100.0:
		_event("super_ready",f.player,"SUPER READY")

func tick(raw_inputs: Array) -> void:
	events.clear()
	if fighters.size() < 2 or winner >= 0:
		return
	if cinematic.active:
		_tick_cinematic()
		return
	var inputs: Array = []
	for i in 2:
		var value: Dictionary = EMPTY.duplicate()
		if i < raw_inputs.size():
			value.merge(raw_inputs[i],true)
		inputs.append(value)
		_capture(fighters[i],value)
	if hitstop > 0:
		hitstop -= 1
		return
	tick_count += 1
	if not training:
		time_frames = maxi(0,time_frames - 1)
	for i in 2:
		_update_fighter(fighters[i],fighters[1-i],inputs[i])
	_pushboxes()
	for i in 2:
		var f: Dictionary = fighters[i]
		if f.state != "attack" and f.state != "throw" and f.state != "thrown":
			f.face = 1 if fighters[1-i].x >= f.x else -1
	var contacts: Array = []
	for i in 2:
		var f: Dictionary = fighters[i]
		if f.state == "attack" and not f.move.is_empty():
			_process_move(f,fighters[1-i],contacts)
	_resolve_contacts(contacts,inputs)
	if cinematic.active: return
	_update_projectiles(inputs)
	for i in 2:
		var f: Dictionary = fighters[i]
		if f.id == 7 and f.hp <= 500 and f.phase == 1:
			f.phase = 2
			_event("phase",i,"NEXUS PRIME · PHASE 2")
		if training:
			if training_options.get("infinite_meter",true):
				f.meter = 100.0
			if training_options.get("infinite_health",true) and (f.hp <= 0 or (f.stun == 0 and f.state in ["idle","walk","crouch","block","crouch_block"] and f.combo_timer == 0)):
				f.hp = 1000.0
	_check_round_end()

func _check_round_end() -> void:
	if not training and (fighters[0].hp <= 0 or fighters[1].hp <= 0 or time_frames == 0):
		winner = 2 if is_equal_approx(fighters[0].hp,fighters[1].hp) else (0 if fighters[0].hp > fighters[1].hp else 1)
		_event("ko",winner if winner < 2 else 0,"TIME UP" if time_frames == 0 else "K.O.")
		for i in 2:
			fighters[i].state = "victory" if winner == i else "ko"
			fighters[i].anim = fighters[i].state
			fighters[i].frame = 0

func _resolve_contacts(contacts: Array, inputs: Array) -> void:
	# Same-frame throws tech; a same-frame strike defeats a throw. Resolving
	# captures only after collecting contacts removes player-index priority.
	if contacts.size() == 2 and contacts[0].move.kind == "throw" and contacts[1].move.kind == "throw":
		for f in fighters:
			f.state = "idle"
			f.move = {}
			f.invuln = 12
			f.vel.x = -f.face * 7.0
		_event("throw_break",0,"DOUBLE THROW BREAK!")
		hitstop = 8
		return
	var strikes: Array = contacts.filter(func(c: Dictionary) -> bool: return c.move.kind != "throw")
	_trade_contacts = strikes.size() == 2 and fighters[0].invuln == 0 and fighters[1].invuln == 0
	for contact in contacts:
		var a: Dictionary = fighters[contact.owner]
		var d: Dictionary = fighters[1-contact.owner]
		if contact.move.kind == "throw":
			if strikes.is_empty(): _begin_throw(a,d)
		else:
			_apply_hit(a,d,contact.move,inputs[1-contact.owner],false)
	_trade_contacts = false

func _begin_throw(a: Dictionary, d: Dictionary) -> void:
	a.state = "throw"
	a.throw_target = d.player
	d.state = "thrown"
	d.thrown_by = a.player
	d.throw_timer = 11
	d.move = {}
	_event("throw_start",a.player,"THROW")

func _start_cinematic(a: Dictionary, d: Dictionary, m: Dictionary) -> void:
	if a.combo_timer <= 0 or d.state not in ["hitstun","guardbreak"]:
		a.combo = 0
		a.combo_damage = 0.0
	var damage: float = roundf(m.damage * maxf(0.32,1.0-a.combo*0.12))
	cinematic = {"active":true,"frame":0,"duration":270,"attacker":a.player,"defender":d.player,"character":a.id,"name":m.name,"origin_a":a.x,"origin_d":d.x,"damage_total":damage,"damage_applied":0.0,"pulse":0,"base_combo":a.combo}
	a.state = "super"
	d.state = "super_victim"
	a.anim = "super"
	d.anim = "super_victim"
	a.vel = Vector2.ZERO
	d.vel = Vector2.ZERO
	a.y = GROUND
	d.y = GROUND
	a.stun = 0
	d.stun = 0
	a.buffer_time = 0
	d.buffer_time = 0
	a.frame = 0
	d.frame = 0
	a.hit_confirm = true
	d.move = {}
	hitstop = 0
	_meter(a,6.0)
	_meter(d,4.0)
	_event("cinematic_start",a.player,m.name,{"target":d.player,"duration":270})

func _tick_cinematic() -> void:
	tick_count += 1
	cinematic.frame += 1
	var a: Dictionary = fighters[cinematic.attacker]
	var d: Dictionary = fighters[cinematic.defender]
	a.frame = cinematic.frame
	d.frame = cinematic.frame
	var strike_frames := [30,65,105,145,190,240]
	if strike_frames.has(int(cinematic.frame)):
		var index: int = strike_frames.find(int(cinematic.frame))
		# Five quick strikes and a stronger finisher preserve the exact budget.
		var damage: float = floorf(cinematic.damage_total * 0.12) if index < 5 else cinematic.damage_total-cinematic.damage_applied
		cinematic.damage_applied += damage
		cinematic.pulse = index+1
		d.hp = maxf(0.0,d.hp-damage)
		d.damage_received += damage
		d.last_damage = damage
		a.damage_dealt += damage
		a.combo += 1
		a.combo_damage += damage
		a.max_combo = maxi(a.max_combo,a.combo)
		_event("super_hit",a.player,cinematic.name,{"target":d.player,"damage":damage,"pulse":index+1,"final":index==5,"x":d.x,"y":d.y-115.0})
		_event("hit",a.player,cinematic.name,{"target":d.player,"damage":damage,"combo":a.combo,"x":d.x,"y":d.y-115.0})
		_event("combo",a.player,"%d HIT" % a.combo,{"damage":a.combo_damage})
	if cinematic.frame >= cinematic.duration:
		cinematic.active = false
		a.state = "idle"
		a.anim = "idle"
		a.move = {}
		a.frame = 0
		a.combo_timer = 55
		a.cancel_count = 3
		d.state = "knockdown"
		d.anim = "knockdown"
		d.frame = 0
		d.stun = 32
		d.invuln = 35
		d.wakeup_used = false
		d.vel = Vector2(a.face*8.0,-4.0)
		_event("cinematic_end",a.player,cinematic.name,{"target":d.player})
		if training and training_options.get("infinite_health",true):
			d.hp = 1000.0
		_check_round_end()

func _capture(f: Dictionary, inp: Dictionary) -> void:
	f.last_input = inp.duplicate()
	if inp.block_pressed:
		f.guard_age = 0
		var forward: bool = inp.right if f.face == 1 else inp.left
		if forward:
			f.parry_age = 0
	if inp.attack_pressed or inp.power_pressed or inp.up_pressed or inp.block_pressed:
		f.buffer = inp.duplicate()
		f.buffer_time = 7
		var tokens: Array = []
		for token in ["up","down","left","right","attack","power","block"]:
			if inp[token]: tokens.append(token)
		f.history.push_front({"frame":tick_count,"input":" + ".join(tokens)})
		if f.history.size() > 10: f.history.pop_back()

func _update_fighter(f: Dictionary, other: Dictionary, inp: Dictionary) -> void:
	f.frame += 1
	f.guard_age += 1
	f.parry_age += 1
	f.invuln = maxi(0,f.invuln - 1)
	f.guard_delay = maxi(0,f.guard_delay - 1)
	f.overclock = maxi(0,f.overclock - 1)
	f.status_time = maxi(0,f.status_time - 1)
	if f.status_time == 0: f.status = ""
	f.combo_timer = maxi(0,f.combo_timer - 1)
	if f.combo_timer == 0:
		f.combo = 0
		f.combo_damage = 0.0
		f.cancel_count = 0
	if f.guard_delay == 0 and not inp.block and f.state not in ["blockstun","guardbreak"]:
		f.guard = minf(100.0,f.guard + 0.27)
	if f.state == "thrown":
		_update_throw(f,other,inp)
		return
	if f.state == "throw":
		f.anim = "throw"
		return
	if f.stun > 0:
		_wakeup_input(f,inp)
		f.stun -= 1
		f.buffer_time = maxi(0,f.buffer_time - 1)
		_physics(f)
		if f.stun == 0:
			if f.state in ["knockdown","guardbreak"]:
				f.state = "wakeup"
				f.stun = 10
				f.invuln = 12
				f.frame = 0
			elif f.y >= GROUND:
				f.state = "idle"
				f.juggle = 0
			else:
				f.state = "jump"
		f.anim = f.state
		return
	if f.state == "attack" and not f.move.is_empty():
		if f.frame > f.move.startup + f.move.active + f.move.recovery:
			f.state = "idle" if f.y >= GROUND else "jump"
			f.move = {}
			f.frame = 0
	if inp.attack:
		f.charge = mini(60,f.charge + 1)
	else:
		if f.charge >= 28 and _free(f):
			_start_move(f,move_db.normals()[6])
		f.charge = 0
	if f.buffer_time > 0:
		if _command(f,other,f.buffer):
			f.buffer_time = 0
		f.buffer_time = maxi(0,f.buffer_time - 1)
	if _free(f):
		var grounded: bool = Fighter.grounded(f)
		if grounded and inp.block:
			f.state = "crouch_block" if inp.down else "block"
			f.vel.x = 0
		elif grounded and inp.down:
			f.state = "crouch"
			f.vel.x = 0
		else:
			var dir := int(inp.right) - int(inp.left)
			f.vel.x = dir * Fighter.BASE.walk_speed * (0.63 if f.status == "slow" else 1.0)
			f.state = ("walk" if dir != 0 else "idle") if grounded else "jump"
			if grounded and dir != 0: _event("move",f.player)
	elif f.state == "attack" and not f.move.is_empty():
		var m: Dictionary = f.move
		f.vel.x = m.speed * f.face if f.frame >= m.startup and f.frame < m.startup + m.active and m.kind in ["dash","slide","strike"] else f.vel.x * 0.8
	_physics(f)
	f.anim = f.state

func _free(f: Dictionary) -> bool:
	return f.state in ["idle","walk","crouch","block","crouch_block","jump","wakeup"] and f.stun == 0

func _wakeup_input(f: Dictionary, inp: Dictionary) -> void:
	if f.state != "knockdown" or f.frame < 6 or f.wakeup_used or not Fighter.grounded(f): return
	var direction := int(inp.right)-int(inp.left)
	var roll_edge: bool = inp.block_pressed or inp.get("left_pressed",false) or inp.get("right_pressed",false)
	if inp.block and direction != 0 and roll_edge and f.meter >= 20.0:
		f.meter -= 20.0
		f.roll_frames = 12
		f.roll_dir = direction
		f.invuln = maxi(f.invuln,12)
		f.stun = mini(f.stun,12)
		f.wakeup_used = true
		_event("wakeup_roll",f.player,"WAKE-UP ROLL")
	elif inp.up_pressed or inp.attack_pressed:
		f.stun = mini(f.stun,8)
		f.wakeup_used = true
		_event("quick_rise",f.player,"QUICK RISE")

func _command(f: Dictionary, other: Dictionary, inp: Dictionary) -> bool:
	var forward: bool = inp.right if f.face == 1 else inp.left
	var back: bool = inp.left if f.face == 1 else inp.right
	var attack_edge: bool = inp.attack_pressed
	var power_edge: bool = inp.power_pressed
	var command: Dictionary = {}
	if inp.attack and inp.block and (attack_edge or inp.block_pressed):
		command = move_db.move("NEXUS THROW","throw",105,6,3,28,86,0,{"family":"throw","guard_damage":0.0,"height":180.0})
	elif inp.attack and inp.power and (attack_edge or power_edge):
		command = move_db.super_move(f.id) if f.meter >= 100.0 else move_db.specials(f.id)[5]
	elif power_edge:
		var slot := 0
		if inp.down: slot = 3
		elif inp.up: slot = 4
		elif forward: slot = 1
		elif back: slot = 2
		command = move_db.specials(f.id)[slot]
		if f.id == 7 and f.phase == 2 and slot == 2:
			command = move_db.move("QUANTUM SHIFT","teleport",0,8,1,19,245,20)
	elif inp.block_pressed and back:
		command = move_db.defense(f.id)
	elif attack_edge:
		var slot := 0
		if f.y < GROUND - 2: slot = 5 if forward or back else 4
		elif inp.down: slot = 3
		elif inp.up: slot = 7
		elif forward: slot = 1
		elif back: slot = 2
		elif f.combo >= 2: slot = 6
		command = move_db.normals()[slot]
	elif inp.up_pressed and _free(f) and Fighter.grounded(f) and not inp.block:
		f.vel.y = Fighter.BASE.jump_velocity
		f.state = "jump"
		f.frame = 0
		_event("jump",f.player)
		return true
	if command.is_empty():
		return false
	if f.meter < command.cost:
		_event("no_meter",f.player,"NEXUS INSUFICIENTE")
		return true
	if not _free(f):
		if not (f.state == "attack" and f.hit_confirm and f.cancel_count < 3):
			return false
		if f.move.family == "normal":
			if not f.move.get("cancel",false): return false
			if command.family == "normal" and (command.name == f.move.name or f.cancel_count >= 2): return false
			if command.family not in ["normal","special","super"]: return false
		elif command.family != "super":
			return false
		f.cancel_count += 1
	_start_move(f,command)
	return true

func _start_move(f: Dictionary, source: Dictionary) -> void:
	var m: Dictionary = source.duplicate(true)
	if f.overclock > 0 and m.family == "normal":
		# A temporary cancel/range property change, with no permanent stat increase.
		m.range += 24.0
		m.recovery = maxi(8,m.recovery - 3)
		f.overclock = 0
	if m.chargeable and f.charge >= 28:
		m.damage *= 1.2
		m.startup += 4
		m.recovery += 5
	f.meter = maxf(0,f.meter - m.cost)
	f.state = "attack"
	f.anim = "attack"
	f.frame = 0
	f.move = m
	f.hit_targets = []
	f.hit_confirm = false
	f.invuln = maxi(f.invuln,m.invuln)
	f.vel.x *= 0.5
	f.attacks += 1
	_meter(f,2.0 if m.family == "normal" else 0.0)
	_event("attack",f.player,m.name,{"kind":m.kind})
	if m.family == "super":
		f.supers += 1
		hitstop = maxi(hitstop,12)
		_event("super",f.player,m.name)

func _physics(f: Dictionary) -> void:
	if f.roll_frames > 0:
		f.vel.x = f.roll_dir*5.0
		f.roll_frames -= 1
	f.x = clampf(f.x + f.vel.x,90.0,1190.0)
	if f.y < GROUND or f.vel.y < 0:
		f.vel.y += Fighter.BASE.gravity * (1.0 + f.juggle * 0.17)
		f.y += f.vel.y
	if f.y >= GROUND:
		var landed: bool = f.vel.y > 0
		f.y = GROUND
		f.vel.y = 0
		if landed:
			_event("land",f.player)
			if f.state == "hitstun" and f.juggle > 0:
				f.state = "knockdown"
				f.stun = 24
				f.frame = 0
				f.wakeup_used = false
			elif f.state == "jump":
				f.state = "idle"
				f.frame = 0
	if f.state in ["hitstun","blockstun","knockdown","guardbreak","wakeup"]:
		f.vel.x *= 0.83

func _pushboxes() -> void:
	var a: Dictionary = fighters[0]
	var b: Dictionary = fighters[1]
	if a.state in ["throw","thrown"] or b.state in ["throw","thrown"]: return
	if not Fighter.pushbox(a).intersects(Fighter.pushbox(b)): return
	var distance: float = absf(a.x - b.x)
	if distance >= 66.0: return
	var direction := 1.0 if b.x >= a.x else -1.0
	var shift := (66.0 - distance) * 0.5
	a.x = clampf(a.x - shift * direction,90.0,1190.0)
	b.x = clampf(b.x + shift * direction,90.0,1190.0)
	# Correct the remainder when one fighter is pinned against the arena edge.
	if absf(a.x - b.x) < 66.0:
		if a.x <= 90.0 or a.x >= 1190.0: b.x = a.x + direction * 66.0
		else: a.x = b.x - direction * 66.0

func hitbox(f: Dictionary) -> Rect2:
	if f.move.is_empty(): return Rect2()
	var m: Dictionary = f.move
	var x: float = f.x + 15.0 if f.face == 1 else f.x - m.range
	if m.kind == "burst": x = f.x - m.range
	return Rect2(x,f.y + m.offset_y - m.height * 0.5,m.range - 15.0 if m.kind != "burst" else m.range * 2.0,m.height)

func _process_move(f: Dictionary, other: Dictionary, contacts: Array) -> void:
	var m: Dictionary = f.move
	if f.frame < m.startup or f.frame >= m.startup + m.active: return
	if f.frame == m.startup:
		match m.kind:
			"projectile": _spawn(f,m,"projectile",f.x + f.face * 67.0,f.y - 112.0)
			"trap":
				for old in projectiles:
					if old.owner == f.player and old.kind == "trap": old.dead = true
				_spawn(f,m,"trap",clampf(f.x + m.range * f.face,110.0,1170.0),GROUND - 22.0)
			"barrier":
				for old in projectiles:
					if old.owner == f.player and old.kind == "barrier": old.dead = true
				_spawn(f,m,"barrier",f.x + 100.0 * f.face,GROUND - 92.0)
			"teleport","evade":
				var old_x: float = f.x
				f.x = clampf(f.x + f.face * m.range,90.0,1190.0)
				f.invuln = 5
				_event("teleport",f.player,m.name,{"from_x":old_x})
			"crossup":
				f.x = clampf(other.x + other.face * 90.0,90.0,1190.0)
				f.face = 1 if other.x >= f.x else -1
				_event("teleport",f.player,m.name)
			"blink_strike":
				f.x = clampf(f.x + f.face * minf(90.0,maxf(0.0,absf(f.x-other.x)-110.0)),90.0,1190.0)
				_event("teleport",f.player,m.name)
			"buff":
				f.overclock = m.duration
				_event("buff",f.player,m.name)
			"uppercut": f.vel.y = -6.8
			"throw":
				if absf(f.x-other.x) <= m.range and Fighter.grounded(other) and other.invuln == 0 and other.stun == 0 and other.state not in ["throw","thrown"]:
					contacts.append({"owner":f.player,"move":m.duplicate(true)})
	if m.kind in ["projectile","trap","barrier","teleport","counter","buff","evade","throw"]: return
	if f.hit_targets.has(other.player): return
	if hitbox(f).intersects(Fighter.hurtbox(other)):
		f.hit_targets.append(other.player)
		contacts.append({"owner":f.player,"move":m.duplicate(true)})

func _apply_hit(a: Dictionary, d: Dictionary, m: Dictionary, inp: Dictionary, projectile: bool) -> bool:
	if cinematic.active or d.invuln > 0 or d.state in ["thrown","throw","knockdown","wakeup"]: return false
	if d.state == "attack" and not d.move.is_empty() and d.move.kind == "counter" and d.frame >= d.move.startup and d.frame < d.move.startup+d.move.active:
		var counter_move: Dictionary = d.move.duplicate(true)
		d.move = {}
		d.state = "idle"
		d.invuln = 8
		if projectile:
			_meter(d,8)
			_event("counter",d.player,counter_move.name+" · ABSORB",{"target":a.player,"damage":0.0})
			return true
		a.state = "hitstun"
		a.stun = 29
		a.frame = 0
		a.hp = maxf(0.0,a.hp-counter_move.damage)
		a.vel.x = d.face * counter_move.push
		if counter_move.freeze > 0:
			a.status = "freeze"
			a.status_time = int(counter_move.freeze)
			a.stun += int(counter_move.freeze)
		d.damage_dealt += counter_move.damage
		a.damage_received += counter_move.damage
		_meter(d,13)
		d.last_counter = true
		hitstop = maxi(hitstop,10)
		_event("counter",d.player,counter_move.name,{"target":a.player,"damage":counter_move.damage})
		return true
	var can_guard: bool = d.state in ["idle","walk","crouch","block","crouch_block","blockstun"] and Fighter.grounded(d)
	var correct_level: bool = (inp.down and m.level != "high") or (not inp.down and m.level != "low")
	if can_guard and inp.block and correct_level:
		if d.parry_age <= 3 and not projectile:
			d.parry_age = 999
			d.guard_age = 999
			d.state = "idle"
			d.stun = 0
			d.parries += 1
			d.invuln = 7
			a.state = "hitstun"
			a.stun = 21
			a.frame = 0
			_meter(d,15)
			hitstop = maxi(hitstop,9)
			_event("parry",d.player,"PARRY!",{"target":a.player})
			return true
		var perfect: bool = d.guard_age <= 5
		d.guard_age = 999
		d.last_perfect = perfect
		d.guard = maxf(0.0,d.guard - m.guard_damage * (0.18 if perfect else 1.0))
		d.guard_delay = 100
		d.hp = maxf(1.0,d.hp - (0.0 if perfect else m.damage * m.chip))
		d.state = "blockstun"
		d.stun = 5 if perfect else m.blockstun
		d.frame = 0
		d.vel.x = a.face * (1.3 if perfect else 3.0)
		a.vel.x = -a.face * 1.4
		_meter(d,10.0 if perfect else 3.0)
		_meter(a,2.0)
		hitstop = maxi(hitstop,7 if perfect else 4)
		if perfect:
			d.perfect_blocks += 1
			_event("perfect_block",d.player,"PERFECT BLOCK",{"target":a.player})
		else:
			_event("block",d.player,"BLOCK",{"target":a.player})
		if d.guard <= 0:
			d.state = "guardbreak"
			d.stun = 52
			d.guard = 22.0
			a.guard_breaks += 1
			hitstop = maxi(hitstop,15)
			_event("guard_break",d.player,"GUARD BREAK!",{"target":a.player})
		return true
	if m.kind == "super" and not _trade_contacts:
		_start_cinematic(a,d,m)
		return true
	var counter: bool = d.state == "attack" and not d.move.is_empty() and d.frame < d.move.startup
	# A display timer may outlive hitstun; a recovered opponent starts a new combo.
	if a.combo_timer <= 0 or d.state not in ["hitstun","guardbreak"]:
		a.combo = 0
		a.combo_damage = 0.0
		a.cancel_count = 0
	var scaling := maxf(0.32,1.0 - a.combo * 0.12)
	var damage: float = roundf(m.damage * scaling * (1.08 if counter else 1.0))
	d.hp = maxf(0.0,d.hp - damage)
	d.damage_received += damage
	a.damage_dealt += damage
	a.combo += 1
	a.combo_damage += damage
	a.max_combo = maxi(a.max_combo,a.combo)
	a.combo_timer = 100
	a.hit_confirm = true
	d.last_damage = damage
	d.last_counter = counter
	d.frame = 0
	d.state = "hitstun"
	d.stun = maxi(8,int(m.hitstun) - (a.combo-1)*2 + (7 if counter else 0))
	d.move = {}
	d.vel.x = a.face * (m.push + a.combo * 0.35)
	if m.pull > 0:
		d.vel.x = -a.face * m.pull
	if m.launch < 0 and d.juggle < 4:
		d.vel.y = m.launch * maxf(0.5,1.0-d.juggle*0.16)
		d.juggle += 1
	elif d.y < GROUND:
		d.juggle += 1
	if m.freeze > 0 and a.combo <= 3:
		d.stun += int(m.freeze)
		d.status = "freeze"
		d.status_time = int(m.freeze)
	if m.get("slow",0) > 0:
		d.status = "slow"
		d.status_time = int(m.slow)
	if a.combo >= 8 or d.juggle >= 5:
		d.state = "knockdown"
		d.stun = 32
		d.invuln = 35
		d.wakeup_used = false
		d.vel.y = 3.0
		d.vel.x = a.face * 11.0
	a.combo_timer = maxi(45,d.stun + 16)
	_meter(a,8.0 if counter else 6.0)
	_meter(d,4.0)
	hitstop = maxi(hitstop,7 if m.damage < 90 else 11)
	_event("hit",a.player,m.name,{"target":d.player,"x":d.x,"y":d.y-105,"damage":damage,"combo":a.combo})
	if counter: _event("counter",a.player,"COUNTER!",{"target":d.player})
	if a.combo >= 2: _event("combo",a.player,"%d HIT" % a.combo,{"damage":a.combo_damage})
	if m.kind == "super":
		hitstop = maxi(hitstop,27)
		_event("super_hit",a.player,m.name,{"target":d.player,"damage":damage})
	if m.kind == "echo":
		var echo: Dictionary = m.duplicate(true)
		echo.damage = 26.0
		echo.kind = "echo_hit"
		echo.freeze = 0
		_spawn(a,echo,"echo",d.x,d.y-105.0)
	return true

func _update_throw(d: Dictionary, a: Dictionary, inp: Dictionary) -> void:
	d.throw_timer -= 1
	d.x = a.x + a.face * 70.0
	d.y = GROUND
	if inp.attack and inp.block and (inp.attack_pressed or inp.block_pressed):
		d.state = "idle"
		a.state = "idle"
		d.invuln = 12
		a.invuln = 12
		d.vel.x = a.face * 7.0
		a.vel.x = -a.face * 7.0
		d.thrown_by = -1
		a.throw_target = -1
		hitstop = maxi(hitstop,8)
		_event("throw_break",d.player,"THROW BREAK!")
		return
	if d.throw_timer <= 0:
		d.hp = maxf(0.0,d.hp - 105.0)
		d.state = "knockdown"
		d.stun = 34
		d.wakeup_used = false
		d.vel = Vector2(a.face * 11.0,-5.0)
		d.thrown_by = -1
		a.state = "idle"
		a.throw_target = -1
		a.throws += 1
		a.damage_dealt += 105.0
		d.damage_received += 105.0
		a.move = {}
		_meter(a,9)
		_meter(d,5)
		hitstop = maxi(hitstop,12)
		_event("throw",a.player,"NEXUS THROW",{"target":d.player,"damage":105.0})

func _spawn(f: Dictionary, m: Dictionary, kind: String, x: float, y: float) -> void:
	_serial += 1
	projectiles.append({"uid":_serial,"x":x,"y":y,"owner":f.player,"kind":kind,"face":f.face,"vel":Vector2(m.speed*f.face if kind == "projectile" else 0,0),"life":m.duration,"age":0,"radius":m.range*0.5 if kind == "projectile" else (58.0 if kind == "trap" else 42.0),"move":m.duplicate(true),"dead":false,"color":move_db.character(f.id).color,"hp":2 if kind == "barrier" else 1})
	_event("projectile",f.player,m.name,{"kind":kind,"x":x,"y":y})

func _update_projectiles(inputs: Array) -> void:
	for p in projectiles:
		p.life -= 1
		p.age += 1
		p.x += p.vel.x
		p.y += p.vel.y
		if p.life <= 0 or p.x < 25 or p.x > 1255: p.dead = true
	for i in projectiles.size():
		var a: Dictionary = projectiles[i]
		if a.dead or a.kind not in ["projectile","barrier"]: continue
		for j in range(i+1,projectiles.size()):
			if a.dead: break
			var b: Dictionary = projectiles[j]
			if b.dead or b.owner == a.owner or b.kind not in ["projectile","barrier"]: continue
			if a.kind == "barrier" and b.kind == "barrier": continue
			if absf(a.x-b.x) < a.radius+b.radius and absf(a.y-b.y) < 100:
				if a.kind == "barrier": a.hp -= 1
				else: a.dead = true
				if b.kind == "barrier": b.hp -= 1
				else: b.dead = true
				if a.hp <= 0: a.dead = true
				if b.hp <= 0: b.dead = true
				_event("clash",a.owner,"CLASH",{"x":(a.x+b.x)*0.5,"y":a.y})
	for p in projectiles:
		if p.dead or p.kind == "barrier": continue
		if p.kind == "trap" and p.age < 18: continue
		if p.kind == "echo" and p.age < 12: continue
		var d: Dictionary = fighters[1-p.owner]
		var box := Rect2(p.x-p.radius,p.y-p.radius,p.radius*2,p.radius*2)
		if box.intersects(Fighter.hurtbox(d)):
			# Digital defense can return a projectile once; other counters absorb it.
			if d.state == "attack" and not d.move.is_empty() and d.move.get("reflect",false) and d.frame >= d.move.startup and d.frame < d.move.startup+d.move.active and p.kind == "projectile":
				p.owner = d.player
				p.vel.x *= -1
				p.face *= -1
				p.x += p.face * 85
				p.color = move_db.character(d.id).color
				_event("parry",d.player,"PACKET REFLECT")
			elif _apply_hit(fighters[p.owner],d,p.move,inputs[1-p.owner],true):
				p.dead = true
	projectiles = projectiles.filter(func(p: Dictionary) -> bool: return not p.dead)

func snapshot() -> Dictionary:
	return {"tick":tick_count,"time":time_frames,"winner":winner,"hitstop":hitstop,"fighters":fighters.duplicate(true),"projectiles":projectiles.duplicate(true),"cinematic":cinematic.duplicate(true)}
