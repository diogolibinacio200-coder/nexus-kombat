extends RefCounted
## Frame data is centralized here. Adding a roster entry needs no combat changes.

const BASE = preload("res://scripts/fighter.gd").BASE
var balance_overrides: Dictionary = {}

func _init(path: String = "res://data/balance.json") -> void:
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("moves",{}) is Dictionary:
			balance_overrides = parsed.get("moves", {})

const ROSTER = [
	["ARTHUR","DOMÍNIO DA TEMPESTADE","74dbff","EYE OF THE STORM","A tempestade encontrou seu centro.","Arthur devolve a energia da tempestade ao céu. O Nexus agora ilumina caminhos, em vez de aprisionar mundos."],
	["VITOR DO BEM","GUARDIÃO SOLAR","ffce67","SUPERNOVA","Toda sombra tem um fim.","Vitor transforma o núcleo em um novo sol. A luz abre passagens seguras entre as dimensões antes isoladas."],
	["MARIA","ARQUITETA DO TEMPO","a99aff","ZERO HOUR","Seu próximo segundo é meu.","Maria solta os instantes presos no Nexus. Cada mundo recupera seu futuro, e nenhum deles é escrito de antemão."],
	["DIOGO","NEXUS CORE","50f5de","SYSTEM OVERRIDE","O sistema acaba de mudar.","Diogo reescreve o protocolo do Nexus. A dimensão deixa de escolher seus donos: passa a responder a todos."],
	["MIRKOS","VOID MASTER","c197ff","EVENT HORIZON","Há um universo entre cada golpe.","Mirkos sela a singularidade e mapeia rotas entre os mundos. No silêncio do vazio, surge uma nova fronteira."],
	["FELIPE","GUARDIÃO CRIOGÊNICO","a6efff","ABSOLUTE ZERO","Até o caos pode parar.","Felipe cristaliza a última anomalia. O núcleo adormece em um monumento de gelo, lembrando o preço do equilíbrio."],
	["MURILO","FLAME REACTOR","ff8759","INFERNO DRIVE","Ainda resta uma centelha.","Murilo converte a sobrecarga em uma aurora de plasma. Sete portais se abrem, e os lutadores finalmente retornam."],
	["NEXUS PRIME","O NÚCLEO DESPERTO","f7b9ff","DIMENSION COLLAPSE","Todas as rotas chegam a mim.","A anomalia se reorganiza. O próximo ciclo do Nexus ainda pode ser transformado."]
]

func move(n: String, kind: String = "strike", damage: float = 60.0, start: int = 10, active: int = 4, recovery: int = 22, reach: float = 135.0, cost: float = 20.0, extras: Dictionary = {}) -> Dictionary:
	var m := {"name":n,"kind":kind,"damage":damage,"startup":start,"active":active,"recovery":recovery,"range":reach,"height":80.0,"offset_y":-116.0,"guard_damage":18.0,"cost":cost,"level":"mid","hitstun":23,"blockstun":13,"push":5.0,"launch":0.0,"speed":0.0,"duration":90,"cancel":false,"family":"special","chip":0.06,"invuln":0,"freeze":0,"pull":0.0,"chargeable":false}
	m.merge(extras,true)
	# JSON supplies tuning values only; move identities and mechanics remain typed.
	var config_name = n+" [DEFENSE]" if m.family == "defense" else n
	var entry = balance_overrides.get(config_name,{})
	var overrides: Dictionary = entry if entry is Dictionary else {}
	for key in overrides:
		if m.has(key) and key not in ["name","kind","family"]:
			var value = overrides[key]
			if typeof(m[key]) in [TYPE_INT,TYPE_FLOAT] and typeof(value) in [TYPE_INT,TYPE_FLOAT]:
				m[key] = int(value) if typeof(m[key]) == TYPE_INT else float(value)
			elif typeof(m[key]) == typeof(value):
				m[key] = value
	return m

func normals() -> Array:
	return [
		move("NEXUS JAB","strike",45,6,3,11,106,0,{"family":"normal","cancel":true,"guard_damage":8.0,"hitstun":21}),
		move("ADVANCING EDGE","strike",62,9,4,15,143,0,{"family":"normal","cancel":true,"guard_damage":12.0,"speed":1.8}),
		move("RETREATING FANG","strike",50,8,4,16,127,0,{"family":"normal","cancel":true,"guard_damage":10.0,"speed":-1.8}),
		move("LOW SWEEP","strike",48,8,4,16,121,0,{"family":"normal","cancel":true,"guard_damage":10.0,"level":"low","offset_y":-39.0,"height":47.0}),
		move("AIR FANG","strike",52,6,9,12,113,0,{"family":"normal","cancel":true,"guard_damage":10.0,"level":"high","offset_y":-79.0,"height":112.0}),
		move("DIVING EDGE","strike",60,8,8,15,144,0,{"family":"normal","cancel":true,"guard_damage":12.0,"level":"high","offset_y":-52.0,"height":102.0,"speed":3.0}),
		move("CHARGED IMPACT","strike",93,17,5,25,156,0,{"family":"normal","cancel":true,"guard_damage":28.0,"push":9.0,"chargeable":true,"launch":-5.0}),
		move("RISING EDGE","strike",70,10,7,27,104,0,{"family":"normal","cancel":true,"guard_damage":15.0,"offset_y":-180.0,"height":200.0,"launch":-10.0})
	]

func character(id: int) -> Dictionary:
	var index := clampi(id,0,7)
	var r: Array = ROSTER[index]
	return {"id":index,"name":r[0],"title":r[1],"color":r[2],"super":r[3],"quote":r[4],"ending":r[5],"specials":specials(index),"defense":defense(index),"base":BASE.duplicate(),"signature":["NEXUS JAB","ADVANCING EDGE",specials(index)[1].name]}

func specials(id: int) -> Array:
	match id:
		0:
			return [move("ARC LIGHTNING","projectile",74,14,1,25,60,20,{"speed":9.5}),move("TEMPEST STRIKE","dash",79,9,6,24,135,20,{"speed":8.0}),move("THUNDER STEP","teleport",0,8,1,19,245,20),move("STATIC TRAP","trap",56,18,1,24,200,20,{"duration":150,"freeze":7}),move("RISING THUNDER","uppercut",84,9,10,30,111,20,{"height":225.0,"offset_y":-177.0,"launch":-11.0}),move("STORM BREAKER","strike",122,22,6,31,190,30,{"guard_damage":34.0,"chargeable":true,"push":12.0})]
		1:
			return [move("SOLAR SHOT","projectile",76,16,1,23,66,20,{"speed":8.0}),move("SUN DASH","dash",80,11,7,22,143,20,{"speed":7.4}),move("LIGHT WALL","barrier",0,12,1,22,91,20,{"duration":100}),move("SOLAR UPPERCUT","uppercut",82,9,10,29,114,20,{"height":224.0,"offset_y":-180.0,"launch":-11.0}),move("RADIANT STRIKE","strike",97,18,5,26,168,20,{"guard_damage":25.0,"chargeable":true}),move("FLASH BURST","burst",115,19,8,31,186,30,{"guard_damage":31.0,"push":14.0})]
		2:
			return [move("TIME SHARD","projectile",70,14,1,25,61,20,{"speed":7.2,"freeze":6}),move("PHASE STEP","teleport",0,7,1,20,245,20),move("TEMPORAL COUNTER","counter",88,4,15,28,148,20),move("TIME FREEZE","freeze",49,20,4,30,166,20,{"freeze":13,"hitstun":21,"guard_damage":15.0}),move("CHRONO STRIKE","echo",86,14,5,27,154,20,{"duration":16,"chargeable":true}),move("TIME RIFT","trap",98,24,1,30,235,30,{"duration":135,"freeze":9,"guard_damage":27.0})]
		3:
			return [move("DATA BLAST","projectile",74,13,1,26,58,20,{"speed":9.0}),move("NEXUS DASH","dash",79,11,6,22,140,20,{"speed":7.8}),move("FIREWALL","barrier",0,13,1,21,91,20,{"duration":105}),move("OVERCLOCK","buff",0,15,1,19,0,20,{"duration":210}),move("GLITCH STRIKE","blink_strike",88,17,5,27,160,20,{"chargeable":true}),move("NEXUS PORTAL","crossup",92,23,5,30,135,30,{"guard_damage":25.0})]
		4:
			return [move("VOID ORB","projectile",76,17,1,23,78,20,{"speed":6.3}),move("VOID PORTAL","teleport",0,8,1,19,245,20),move("GRAVITY PULL","pull",69,16,6,25,242,20,{"pull":11.0,"push":0.0}),move("RIFT KICK","blink_strike",85,17,5,26,175,20),move("DIMENSIONAL SLASH","strike",94,18,5,27,210,20,{"guard_damage":25.0,"chargeable":true}),move("SINGULARITY","trap",99,25,1,29,220,30,{"duration":160,"pull":6.0,"guard_damage":26.0})]
		5:
			return [move("ICE SHARD","projectile",72,15,1,24,65,20,{"speed":8.3,"freeze":6}),move("FROST SLIDE","slide",77,12,7,25,150,20,{"speed":7.1,"level":"low","offset_y":-44.0,"height":55.0}),move("ICE WALL","barrier",0,13,1,22,92,20,{"duration":110}),move("CRYO UPPERCUT","uppercut",84,10,9,29,114,20,{"offset_y":-180.0,"height":225.0,"launch":-11.0}),move("FROST TRAP","trap",58,19,1,24,210,20,{"duration":160,"freeze":8,"slow":36}),move("GLACIAL STRIKE","strike",123,23,6,31,184,30,{"freeze":8,"guard_damage":33.0,"chargeable":true})]
		6:
			return [move("FIREBALL","projectile",78,16,1,25,67,20,{"speed":8.5}),move("BLAZE DASH","dash",82,12,7,24,143,20,{"speed":7.6}),move("THERMAL BURST","burst",81,13,6,26,153,20,{"push":12.0}),move("FLAME UPPERCUT","uppercut",85,10,9,30,112,20,{"offset_y":-181.0,"height":224.0,"launch":-11.0}),move("BURNING STRIKE","strike",96,18,5,27,172,20,{"chargeable":true,"guard_damage":26.0}),move("HEAT WAVE","wave",118,23,8,32,282,30,{"guard_damage":31.0,"push":10.0})]
		_:
			return [move("CORE PULSE","projectile",74,15,1,24,66,20,{"speed":8.5}),move("VECTOR DRIVE","dash",80,11,6,24,143,20,{"speed":7.5}),move("PRIME AEGIS","barrier",0,13,1,23,92,20,{"duration":100}),move("FRACTURE RISE","uppercut",84,10,9,30,112,20,{"offset_y":-180.0,"height":224.0,"launch":-11.0}),move("QUANTUM REND","strike",94,18,5,27,174,20,{"chargeable":true,"guard_damage":26.0}),move("DIMENSION BREACH","crossup",118,23,6,31,184,30,{"guard_damage":31.0})]

func defense(id: int) -> Dictionary:
	var names := ["STATIC REBOUND","SOLAR VEIL","TEMPORAL COUNTER","PACKET REFLECT","RIFT EVASION","CRYO SHELL","HEAT GUARD","PRIME REVERSAL"]
	var kind := "evade" if id == 4 else "counter"
	return move(names[clampi(id,0,7)],kind,85,3,14,28,151,40,{"family":"defense","invuln":8 if id == 4 else 0,"reflect":id == 3,"freeze":7 if id == 5 else 0,"push":13.0 if id == 6 else 6.0})

func super_move(id: int) -> Dictionary:
	return move(ROSTER[clampi(id,0,7)][3],"super",280,18,8,42,290,100,{"family":"super","guard_damage":48.0,"chip":0.04,"hitstun":42,"launch":-10.0,"invuln":10,"push":14.0,"height":185.0,"offset_y":-125.0})
