extends RefCounted
## Canonical fighter state. Combat uses frame units and pixel-per-frame velocity.

const BASE = {"max_hp":1000.0,"max_guard":100.0,"max_meter":100.0,"walk_speed":4.2,"jump_velocity":-14.4,"gravity":0.68,"body_width":66.0,"body_height":212.0}

static func create(id: int, player: int) -> Dictionary:
	return {"id":id,"player":player,"x":370.0 if player == 0 else 910.0,"y":590.0,"face":1 if player == 0 else -1,"hp":BASE.max_hp,"guard":BASE.max_guard,"meter":0.0,"state":"idle","frame":0,"move":{},"combo":0,"combo_damage":0.0,"vel":Vector2.ZERO,"stun":0,"invuln":0,"anim":"idle","charge":0,"phase":1,"guard_age":999,"parry_age":999,"guard_delay":0,"combo_timer":0,"juggle":0,"hit_confirm":false,"cancel_count":0,"hit_targets":[],"buffer":{},"buffer_time":0,"defense_time":0,"overclock":0,"status_time":0,"status":"","throw_target":-1,"throw_timer":0,"thrown_by":-1,"ready_announced":false,"last_input":{},"history":[],"last_damage":0.0,"last_counter":false,"last_perfect":false,"damage_dealt":0.0,"damage_received":0.0,"attacks":0,"perfect_blocks":0,"parries":0,"guard_breaks":0,"supers":0,"throws":0,"max_combo":0,"round_wins":0,"wakeup_used":false,"roll_frames":0,"roll_dir":0}

static func hurtbox(f: Dictionary) -> Rect2:
	var h: float = 128.0 if f.state == "crouch" or f.state == "crouch_block" else BASE.body_height
	return Rect2(f.x - 29.0, f.y - h, 58.0, h - 7.0)

static func pushbox(f: Dictionary) -> Rect2:
	return Rect2(f.x - 33.0, f.y - 135.0, 66.0, 135.0)

static func grounded(f: Dictionary) -> bool:
	return f.y >= 589.9
