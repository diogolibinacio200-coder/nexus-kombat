extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const AI = preload("res://scripts/ai.gd")
const Fighter = preload("res://scripts/fighter.gd")
var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func fresh(a: int = 0,b: int = 1):
	var c = Combat.new()
	c.setup([a,b])
	c.fighters[0].x = 550.0
	c.fighters[1].x = 645.0
	return c

func steps(c, frames: int, a: Dictionary = {}, b: Dictionary = {}) -> Array:
	var result: Array = []
	for frame in frames:
		c.tick([a,b])
		result.append_array(c.events.duplicate(true))
	return result

func has_event(events: Array, kind: String) -> bool:
	return events.any(func(e: Dictionary) -> bool: return e.type == kind)

func run() -> void:
	var c = fresh()
	var db = c.move_db
	for i in 8:
		check(db.character(i).base == Fighter.BASE,"Base stat equality %d" % i)
		check(db.specials(i).size() >= 6,"Six distinct specials %d" % i)
		var names: Array = []
		for m in db.specials(i):
			check(m.startup > 0 and m.active > 0 and m.recovery > 0 and m.cost >= 0,"Valid frame data " + m.name)
			names.append(m.name)
		check(names.size() == 6,"Unique roster moves %d" % i)
	check(db.normals().size() == 8,"Eight normals")
	c.tick([{"attack":true,"attack_pressed":true},{}])
	steps(c,12)
	check(c.fighters[1].hp < 1000,"Normal connects using hitbox")
	check(c.fighters[0].meter > 0,"Attack and hit gain meter")
	check(c.fighters[0].combo == 1,"Initial combo count")
	c = fresh()
	steps(c,8,{}, {"block":true})
	c.tick([{"attack":true,"attack_pressed":true},{"block":true}])
	var log := steps(c,15,{}, {"block":true})
	check(has_event(log,"block"),"Dedicated block input")
	check(c.fighters[1].hp > 990 and c.fighters[1].guard < 100,"Block chip and guard loss")
	c = fresh()
	c.tick([{"attack":true,"attack_pressed":true},{}])
	steps(c,3)
	c.tick([{}, {"block":true,"block_pressed":true}])
	log = steps(c,8,{}, {"block":true})
	check(has_event(log,"perfect_block"),"Perfect block timing window")
	check(c.fighters[1].hp == 1000,"Perfect block prevents chip")
	c = fresh()
	c.tick([{"attack":true,"attack_pressed":true},{}])
	steps(c,4)
	c.tick([{}, {"left":true,"block":true,"block_pressed":true}])
	log = steps(c,6,{}, {"left":true,"block":true})
	check(has_event(log,"parry"),"Forward relative parry")
	check(c.fighters[0].stun > 0,"Parry leaves attacker vulnerable")
	c = fresh()
	c.fighters[1].guard = 3.0
	steps(c,8,{}, {"block":true})
	c.tick([{"attack":true,"attack_pressed":true},{"block":true}])
	log = steps(c,12,{}, {"block":true})
	check(has_event(log,"guard_break"),"Guard break triggered")
	check(c.fighters[1].state == "guardbreak","Guard break recovery")
	c = fresh()
	c.tick([{"attack":true,"attack_pressed":true,"down":true},{"block":true}])
	steps(c,15,{}, {"block":true})
	check(c.fighters[1].hp < 980,"Low defeats standing block")
	c = fresh()
	c.fighters[1].x = 625
	c.tick([{"attack":true,"attack_pressed":true,"block":true},{}])
	steps(c,7)
	check(c.fighters[1].state == "thrown","Throw capture range")
	c.tick([{}, {"attack":true,"attack_pressed":true,"block":true,"block_pressed":true}])
	check(has_event(c.events,"throw_break"),"Throw break input window")
	check(c.fighters[1].hp == 1000,"Throw break prevents damage")
	c = fresh()
	c.fighters[1].x = 625
	c.tick([{"attack":true,"attack_pressed":true,"block":true},{}])
	steps(c,32)
	check(c.fighters[1].hp == 895,"Unbroken throw has deterministic damage")
	c = fresh()
	c.fighters[0].meter = 100
	c.tick([{"attack":true,"power":true,"attack_pressed":true,"power_pressed":true},{}])
	check(c.fighters[0].meter == 0,"Super costs full meter")
	check(has_event(c.events,"super"),"Super cinematic event")
	var wait_frames := 0
	while not c.cinematic.active and wait_frames < 80:
		steps(c,1)
		wait_frames += 1
	check(c.cinematic.active,"Confirmed super enters cinematic")
	check(c.fighters[0].state == "super" and c.fighters[1].state == "super_victim","Super exposes both locked states")
	var paused_time: int = c.time_frames
	var locked_x: float = c.fighters[0].x
	log = steps(c,269,{"left":true,"attack":true,"attack_pressed":true},{"right":true,"power":true,"power_pressed":true})
	check(c.cinematic.active and c.cinematic.frame == 269,"Cinematic remains locked for 269 frames")
	check(c.time_frames == paused_time and c.fighters[0].x == locked_x,"Cinematic pauses timer and ignores movement/cancel inputs")
	var pulses: Array = log.filter(func(e: Dictionary) -> bool: return e.type == "super_hit")
	var pulse_damage := 0.0
	for pulse in pulses: pulse_damage += pulse.damage
	check(pulses.size() == 6 and pulse_damage == 280,"Six cinematic pulses preserve 280 total damage")
	check(pulses[-1].get("final",false),"Last pulse is marked as finisher")
	check(c.fighters[1].hp == 720 and c.fighters[0].combo == 6,"Cinematic damage and combo accounting")
	steps(c,1)
	check(not c.cinematic.active and c.fighters[1].state == "knockdown","Cinematic ends exactly at 270 frames")
	check(c.fighters[1].invuln > 0 and c.winner == -1,"Cinematic knockdown prevents a new juggle")
	c = fresh()
	c.fighters[0].meter = 100
	c.fighters[1].hp = 90
	c._start_move(c.fighters[0],db.super_move(0))
	while not c.cinematic.active: steps(c,1)
	steps(c,269)
	check(c.fighters[1].hp == 0 and c.winner == -1,"Lethal super waits for cinematic finish before KO")
	steps(c,1)
	check(c.winner == 0 and c.fighters[0].state == "victory" and has_event(c.events,"ko"),"Cinematic finisher resolves round correctly")
	c = fresh()
	c.fighters[0].meter = 100
	c.tick([{"attack":true,"power":true,"attack_pressed":true},{"block":true}])
	log = steps(c,110,{}, {"block":true})
	check(not has_event(log,"cinematic_start") and not c.cinematic.active,"Blocked super never captures defender")
	check(has_event(log,"block") and c.fighters[1].hp > 950,"Blocked super inflicts only chip")
	c = fresh()
	c.fighters[0].x = 200
	c.fighters[1].x = 1080
	c.fighters[0].meter = 100
	c._start_move(c.fighters[0],db.super_move(0))
	log = steps(c,110)
	check(not has_event(log,"cinematic_start") and c.fighters[1].hp == 1000,"Whiffed super never captures defender")
	check(c.fighters[0].state == "idle" and c.fighters[0].meter == 0,"Whiffed super pays cost and completes recovery")
	c = fresh()
	c.fighters[0].meter = 100
	c.fighters[1].meter = 100
	c._start_move(c.fighters[0],db.super_move(0))
	c._start_move(c.fighters[1],db.super_move(1))
	log = steps(c,65)
	check(not has_event(log,"cinematic_start") and not c.cinematic.active,"Simultaneous super trade does not create conflicting captures")
	check(c.fighters[0].hp == 720 and c.fighters[1].hp == 720,"Simultaneous super trade applies symmetric damage")
	c = fresh()
	c.fighters[1].x = 625
	c.tick([{"attack":true,"attack_pressed":true,"block":true},{"attack":true,"attack_pressed":true,"block":true}])
	log = steps(c,15)
	check(has_event(log,"throw_break") and c.fighters[0].hp == 1000 and c.fighters[1].hp == 1000,"Same-frame throws break without player index priority")
	c = fresh(0,5)
	c._start_move(c.fighters[1],db.defense(5))
	c.fighters[1].frame = 5
	c._apply_hit(c.fighters[0],c.fighters[1],db.normals()[0],Combat.EMPTY,false)
	check(c.fighters[0].status == "freeze" and c.fighters[0].stun > 29,"Cryo defensive counter applies its freeze property")
	c = fresh(0,6)
	c._start_move(c.fighters[1],db.defense(6))
	c.fighters[1].frame = 5
	c._apply_hit(c.fighters[0],c.fighters[1],db.normals()[0],Combat.EMPTY,false)
	check(absf(c.fighters[0].vel.x) == 13.0,"Heat defensive counter applies its push property")
	c = fresh(0,1)
	c.fighters[0].x = 200
	c._start_move(c.fighters[1],db.defense(1))
	c.fighters[1].frame = 5
	c._apply_hit(c.fighters[0],c.fighters[1],db.specials(0)[0],Combat.EMPTY,true)
	check(c.fighters[0].hp == 1000 and c.fighters[1].hp == 1000,"Projectile absorption never remotely damages its owner")
	c = fresh()
	var orb: Dictionary = db.specials(0)[0]
	c._spawn(c.fighters[0],orb,"projectile",500,300)
	c._spawn(c.fighters[1],orb,"projectile",510,300)
	c._spawn(c.fighters[1],orb,"projectile",515,300)
	c._update_projectiles([Combat.EMPTY,Combat.EMPTY])
	check(c.projectiles.size() == 1,"Destroyed projectile cannot clash twice in the same tick")
	c = fresh()
	c.fighters[0].x = 250
	c.fighters[1].x = 950
	c.fighters[0].state = "knockdown"
	c.fighters[0].stun = 34
	var auto_recovery := 0
	while c.fighters[0].state != "idle" and auto_recovery < 70:
		steps(c,1)
		auto_recovery += 1
	check(auto_recovery == 44,"Automatic knockdown recovery has a fixed duration")
	c = fresh()
	c.fighters[0].state = "knockdown"
	c.fighters[0].stun = 34
	steps(c,6)
	c.tick([{"up":true,"up_pressed":true},{}])
	check(has_event(c.events,"quick_rise"),"Quick rise accepts grounded up input after minimum knockdown")
	var manual_recovery := 7
	while c.fighters[0].state != "idle" and manual_recovery < 70:
		steps(c,1)
		manual_recovery += 1
	check(manual_recovery < auto_recovery,"Quick rise shortens recovery compared with automatic wakeup")
	steps(c,20)
	check(c.fighters[0].invuln == 0,"Quick rise invulnerability expires")
	c = fresh()
	c.fighters[0].x = 300
	c.fighters[1].x = 950
	c.fighters[0].state = "knockdown"
	c.fighters[0].stun = 34
	c.fighters[0].meter = 50
	steps(c,6)
	c.tick([{"block":true,"block_pressed":true,"right":true,"right_pressed":true},{}])
	check(has_event(c.events,"wakeup_roll"),"Direction plus guard initiates grounded wakeup roll")
	steps(c,11)
	check(c.fighters[0].x == 360 and c.fighters[0].meter == 30,"Wakeup roll travels 60 pixels and spends 20 meter")
	c.tick([{"block":true,"block_pressed":true,"right":true,"right_pressed":true},{}])
	check(c.fighters[0].meter == 30,"Wakeup roll cannot spend repeatedly in one knockdown")
	steps(c,35)
	check(c.fighters[0].invuln == 0 and c.fighters[0].roll_frames == 0,"Waking roll leaves no permanent invulnerability or movement")
	c = fresh()
	c.fighters[0].state = "knockdown"
	c.fighters[0].stun = 34
	c.fighters[0].meter = 19
	steps(c,6)
	c.tick([{"block":true,"block_pressed":true,"right":true,"right_pressed":true},{}])
	check(c.fighters[0].roll_frames == 0 and c.fighters[0].meter == 19,"Insufficient meter prevents wakeup roll")
	c = fresh()
	c.fighters[0].meter = 19
	c.tick([{"power":true,"power_pressed":true},{}])
	check(c.fighters[0].state != "attack" and c.fighters[0].meter == 19,"Meter cost enforced")
	c = fresh()
	c.fighters[0].x = 400
	c.fighters[1].x = 880
	c.fighters[0].meter = 100
	c.fighters[1].meter = 100
	c.tick([{"power":true,"power_pressed":true},{"power":true,"power_pressed":true}])
	log = steps(c,60)
	check(has_event(log,"clash"),"Compatible projectiles clash")
	check(c.fighters[0].hp == 1000 and c.fighters[1].hp == 1000,"Clash prevents damage")
	c = fresh()
	c.fighters[0].x = 760
	c.fighters[1].x = 510
	c.tick([{},{}])
	check(c.fighters[0].face == -1 and c.fighters[1].face == 1,"Automatic facing after side swap")
	c.fighters[0].meter = 40
	c.tick([{"left":true,"power":true,"power_pressed":true},{}])
	check(c.fighters[0].move.name == "TEMPEST STRIKE","Special directions remain relative after swap")
	c = fresh()
	c._start_move(c.fighters[1],db.normals()[6])
	c._start_move(c.fighters[0],db.normals()[0])
	log = steps(c,10)
	check(has_event(log,"counter"),"Counter catches vulnerable startup")
	c = fresh(0,2)
	c.fighters[1].meter = 100
	c._start_move(c.fighters[1],db.specials(2)[2])
	c._start_move(c.fighters[0],db.normals()[0])
	log = steps(c,9)
	check(has_event(log,"counter") and c.fighters[0].hp < 1000 and c.fighters[1].hp == 1000,"Temporal counter responds to attack")
	c = fresh()
	var m: Dictionary = db.normals()[0]
	var previous_damage := 1000.0
	for hit in 8:
		c.fighters[1].invuln = 0
		c.fighters[1].state = "idle" if hit == 0 else "hitstun"
		c._apply_hit(c.fighters[0],c.fighters[1],m,Combat.EMPTY,false)
		check(c.fighters[1].last_damage <= previous_damage,"Combo damage scaling %d" % hit)
		previous_damage = c.fighters[1].last_damage
	check(c.fighters[1].state == "knockdown" and c.fighters[1].invuln > 0,"Combo hard escape prevents infinites")
	c.fighters[1].state = "idle"
	c.fighters[1].invuln = 0
	c._apply_hit(c.fighters[0],c.fighters[1],m,Combat.EMPTY,false)
	check(c.fighters[0].combo == 1,"Neutral recovery begins a new combo")
	# Execute every special with real frame progression, including non-damaging
	# teleport, barrier, buff and counter moves, without invoking test substitutes.
	for id in 8:
		for slot in 6:
			c = fresh(id,(id+1)%8)
			c.fighters[0].meter = 90.0
			var input: Dictionary = {"power":true,"power_pressed":true}
			if slot == 1: input.right = true
			elif slot == 2: input.left = true
			elif slot == 3: input.down = true
			elif slot == 4: input.up = true
			elif slot == 5:
				input.attack = true
				input.attack_pressed = true
			c.tick([input,{}])
			check(c.fighters[0].move.get("name","") == db.specials(id)[slot].name,"Special command mapping %d:%d" % [id,slot])
			steps(c,130)
			check(c.fighters[0].state != "attack","Special recovery completes %d:%d" % [id,slot])
	c = fresh()
	c.fighters[0].meter = 50
	c.tick([{"attack":true,"attack_pressed":true},{}])
	steps(c,7)
	c.tick([{"right":true,"power":true,"power_pressed":true},{}])
	log = steps(c,40)
	check(c.fighters[0].max_combo >= 2,"Hit-confirm normal to special cancel is a real combo")
	c = fresh(3,0)
	c.fighters[0].meter = 100
	c._start_move(c.fighters[0],db.specials(3)[3])
	steps(c,40)
	check(c.fighters[0].overclock > 0,"Overclock primes next normal")
	c._start_move(c.fighters[0],db.normals()[0])
	check(c.fighters[0].move.range > db.normals()[0].range and c.fighters[0].overclock == 0,"Overclock changes one normal then expires")
	c = fresh(7,0)
	c.fighters[0].hp = 499
	c.tick([{},{}])
	check(c.fighters[0].phase == 2 and c.fighters[0].hp == 499,"Boss phase changes without health cheating")
	c = fresh()
	c.time_frames = 1
	c.fighters[0].hp = 600
	c.fighters[1].hp = 400
	c.tick([{},{}])
	check(c.winner == 0 and has_event(c.events,"ko"),"Timer determines round winner")
	var before: Dictionary = c.snapshot()
	c.tick([{"attack":true,"attack_pressed":true},{}])
	check(c.snapshot() == before,"Finished rounds do not simulate")
	c.reset_round()
	check(c.winner == -1 and c.fighters[0].hp == 1000 and c.projectiles.is_empty(),"Round reset clears transient combat")
	var d = fresh(6,4)
	c = fresh(6,4)
	var ai_a = AI.new(456)
	var ai_b = AI.new(456)
	for frame in 2500:
		c.tick([ai_a.think(c,0,2),ai_a.think(c,1,2)])
		d.tick([ai_b.think(d,0,2),ai_b.think(d,1,2)])
	check(c.snapshot() == d.snapshot(),"Seeded AI and combat determinism over 2500 frames")
	check(c.fighters[0].damage_dealt + c.fighters[1].damage_dealt > 0,"AI engages and inflicts damage")
	check(c.fighters[0].x >= 90 and c.fighters[1].x <= 1190,"Arena position bounds")
	print("COMBAT TESTS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
