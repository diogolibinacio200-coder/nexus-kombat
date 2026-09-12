extends RefCounted
## Reacts only to visible fighter/projectile state, never to opponent inputs.
## Seeded decisions and a real reaction delay make replay tests reproducible.
var rng := RandomNumberGenerator.new()
var memory: Array = [{"wait":0,"held":{},"previous":{},"decision":0},{"wait":0,"held":{},"previous":{},"decision":0}]

func _init(seed_value: int = 64139) -> void:
	rng.seed = seed_value

func think(combat, player: int, difficulty = 1) -> Dictionary:
	var level: int = clampi(int(difficulty),0,3)
	if difficulty is String:
		level = ["easy","normal","hard","expert"].find(difficulty.to_lower())
		if level < 0: level = 1
	var mem: Dictionary = memory[player]
	mem.wait -= 1
	if mem.wait <= 0:
		mem.held = _decide(combat,player,level)
		mem.wait = [29,20,13,9][level] + rng.randi_range(0,5)
		mem.decision += 1
	var result := {"left":false,"right":false,"up":false,"down":false,"attack":false,"power":false,"block":false}
	result.merge(mem.held,true)
	for key in ["attack","power","block","up"]:
		result[key + "_pressed"] = result[key] and not mem.previous.get(key,false)
	mem.previous = result.duplicate()
	# Offensive buttons are tapped, while movement and defense remain held.
	mem.held["attack"] = false
	mem.held["power"] = false
	mem.held["up"] = false
	return result

func _decide(combat, player: int, level: int) -> Dictionary:
	var f: Dictionary = combat.fighters[player]
	var o: Dictionary = combat.fighters[1-player]
	var action := {"left":false,"right":false,"up":false,"down":false,"attack":false,"power":false,"block":false}
	var distance: float = absf(f.x-o.x)
	var forward := "right" if o.x >= f.x else "left"
	var back := "left" if forward == "right" else "right"
	var roll := rng.randf()
	var awareness: float = [0.27,0.46,0.66,0.80][level]
	if f.state == "thrown":
		if rng.randf() < [0.05,0.2,0.42,0.65][level]:
			action.attack = true
			action.block = true
		return action
	if f.stun > 0 and f.state != "blockstun": return action
	if combat.winner >= 0: return action
	var threat: bool = o.state == "attack" and distance < 275
	for p in combat.projectiles:
		if p.owner != player and p.kind == "projectile" and absf(p.x-f.x) < 210: threat = true
	if threat and roll < awareness:
		action.block = true
		if not o.move.is_empty(): action.down = o.move.level == "low"
		if level >= 2 and rng.randf() < 0.15: action[forward] = true
		elif level >= 2 and f.meter >= 40 and rng.randf() < 0.12: action[back] = true
		return action
	if f.state == "attack" and f.hit_confirm and level >= 1:
		if f.meter >= 100 and distance < 275:
			action.attack = true
			action.power = true
		elif f.meter >= 20:
			action.power = true
			action[forward] = true
		else:
			action.attack = true
			action[forward] = true
		return action
	if f.meter >= 100 and distance < 265 and (o.stun > 0 or roll > 0.47):
		action.attack = true
		action.power = true
		return action
	if distance > 350:
		if f.meter >= 20 and roll < 0.52:
			action.power = true
		else:
			action[forward] = true
			if roll > 0.89: action.up = true
		return action
	if distance > 170:
		if f.meter >= 20 and roll < 0.31:
			action.power = true
			action[forward] = rng.randf() < 0.65
		else:
			action[forward] = true
			if roll > 0.82: action.up = true
		return action
	if distance < 86 and o.state in ["block","crouch_block","blockstun"] and roll < 0.68:
		action.attack = true
		action.block = true
		return action
	if o.y < 530 and roll < 0.75:
		action.attack = true
		action.up = true
		return action
	if f.meter >= 30 and roll < 0.15:
		action.attack = true
		action.power = true
	elif f.meter >= 20 and roll < 0.30:
		action.power = true
		var direction_roll := rng.randi_range(0,4)
		if direction_roll == 0: action[forward] = true
		elif direction_roll == 1: action.down = true
		elif direction_roll == 2: action.up = true
	elif roll < 0.80:
		action.attack = true
		if distance > 105: action[forward] = true
		elif roll < 0.49: action.down = true
		elif roll > 0.72: action[back] = true
	elif roll < 0.88:
		action.block = true
	elif roll < 0.94:
		action[back] = true
	else:
		action.up = true
		action[forward] = true
	return action
