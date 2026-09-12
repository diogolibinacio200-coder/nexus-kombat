extends SceneTree
## Boundary cases complement combat_test.gd: exact defense timing and two-sided play.
const Combat = preload("res://scripts/combat.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func fresh():
	var combat = Combat.new()
	combat.setup([0, 1])
	combat.fighters[0].x = 550.0
	combat.fighters[1].x = 645.0
	return combat

func has_event(events: Array, kind: String) -> bool:
	return events.any(func(event: Dictionary) -> bool: return event.type == kind)

func timed_guard(lead: int, forward: bool) -> Array:
	var combat = fresh()
	combat._start_move(combat.fighters[0], combat.move_db.normals()[0])
	var log: Array = []
	for frame: int in range(6):
		var guard: Dictionary = {"block": frame >= 6-lead, "block_pressed": frame == 6-lead, "left": forward and frame >= 6-lead}
		combat.tick([{}, guard])
		log.append_array(combat.events)
	return log

func run_checks() -> void:
	check(has_event(timed_guard(5, false), "perfect_block"), "Perfect block includes age five")
	check(not has_event(timed_guard(6, false), "perfect_block"), "Perfect block excludes age six")
	check(has_event(timed_guard(3, true), "parry"), "Parry includes age three")
	check(not has_event(timed_guard(4, true), "parry"), "Parry excludes age four")
	var combat = fresh()
	combat.tick([{"attack":true, "attack_pressed":true}, {"attack":true, "attack_pressed":true}])
	for frame: int in range(8):
		combat.tick([{}, {}])
	check(combat.fighters[0].hp < 1000.0 and combat.fighters[1].hp < 1000.0, "Simultaneous normals damage both fighters")
	check(combat.fighters[0].hp == combat.fighters[1].hp, "Simultaneous equal normals do not favor player one")
	for low: bool in [false, true]:
		for crouch: bool in [false, true]:
			combat = fresh()
			var move: Dictionary = combat.move_db.normals()[3 if low else 4]
			combat._start_move(combat.fighters[0], move)
			var log: Array = []
			for frame: int in range(14):
				combat.tick([{}, {"block":true, "down":crouch}])
				log.append_array(combat.events)
			check(has_event(log, "block") == (low == crouch), "Guard level: low=%s crouch=%s" % [low, crouch])
	combat = fresh()
	combat.fighters[1].meter = 0.0
	combat.tick([{}, {"right":true, "block":true, "block_pressed":true}])
	check(combat.fighters[1].meter == 0.0 and combat.fighters[1].state == "block", "Unaffordable defensive special keeps ordinary block")
	print("Defense boundaries: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
