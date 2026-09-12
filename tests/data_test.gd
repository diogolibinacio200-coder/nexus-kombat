extends SceneTree
const DB = preload("res://scripts/move_db.gd")
var failures = 0
var checks = 0
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var db = DB.new()
	check(db.balance_overrides.size() == 72,"all 72 move entries loaded")
	db.balance_overrides = {"TEMPORAL COUNTER":{"damage":61.0},"TEMPORAL COUNTER [DEFENSE]":{"damage":93.0},"NEXUS JAB":{"name":"CHANGED","kind":"super","family":"super","damage":71.0,"startup":13.0}}
	check(db.specials(2)[2].damage == 61,"special numerical override")
	check(db.defense(2).damage == 93,"defense numerical override is independent")
	var jab: Dictionary = db.normals()[0]
	check(jab.damage == 71,"normal damage override")
	check(jab.startup == 13 and typeof(jab.startup) == TYPE_INT,"frame data preserves integer type")
	check(jab.name == "NEXUS JAB" and jab.kind == "strike" and jab.family == "normal","protected move identity")
	db.balance_overrides = {"NEXUS JAB":14}
	check(db.normals()[0].damage == 45,"invalid entry gracefully ignored")
	var path = "user://test_balance_invalid.json"
	var f = FileAccess.open(path,FileAccess.WRITE)
	f.store_string('{"moves":false}')
	f.close()
	var invalid = DB.new(path)
	check(invalid.normals()[0].damage == 45,"invalid moves collection falls back to defaults")
	DirAccess.remove_absolute(path)
	var combat = load("res://scripts/combat.gd").new()
	combat.setup([0,1])
	var fighter: Dictionary = combat.fighters[0]
	fighter.state = "attack"
	fighter.move = combat.move_db.normals()[0]
	fighter.move.cancel = false
	fighter.hit_confirm = true
	fighter.meter = 80.0
	var command: Dictionary = combat.EMPTY.duplicate()
	command.merge({"power":true,"power_pressed":true},true)
	check(not combat._command(fighter,combat.fighters[1],command),"disabled cancel prevents special before recovery")
	check(fighter.move.family == "normal" and fighter.meter == 80,"rejected cancel preserves current move and energy")
	fighter.move.cancel = true
	fighter.meter = 0.0
	combat._command(fighter,combat.fighters[1],command)
	check(fighter.cancel_count == 0,"unaffordable special does not consume a cancel")
	fighter.meter = 80.0
	combat._command(fighter,combat.fighters[1],command)
	check(fighter.move.family == "special" and fighter.cancel_count == 1,"enabled affordable normal to special cancel")
	print("DATA TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
