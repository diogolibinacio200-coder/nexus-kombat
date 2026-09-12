extends SceneTree
## Rebuild the readable tuning file from the currently active move definitions.
func _initialize() -> void:
	var db = load("res://scripts/move_db.gd").new()
	var moves: Dictionary = {}
	var roster: Array = []
	for m in db.normals(): moves[m.name] = m
	for id in range(8):
		var character: Dictionary = db.character(id)
		roster.append({"id":id,"name":character.name,"title":character.title,"super":character.super})
		for m in character.specials: moves[m.name] = m
		var defense: Dictionary = db.defense(id)
		moves[defense.name+" [DEFENSE]"] = defense
		var super_move: Dictionary = db.super_move(id)
		moves[super_move.name] = super_move
	var file = FileAccess.open("res://data/balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"units":"frames at 60 Hz; pixels; damage out of 1000 HP","note":"Edit numeric values then restart. Shared base stats live in scripts/fighter.gd. The [DEFENSE] suffix differentiates defensive techniques.","moves":moves},"\t"))
	file.close()
	var chars = FileAccess.open("res://data/roster.json",FileAccess.WRITE)
	chars.store_string(JSON.stringify(roster,"\t"))
	chars.close()
	print("Exported ",moves.size()," moves and ",roster.size()," roster records.")
	quit()
