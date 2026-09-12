extends Node2D
## Original procedural stage art and generated HD pixel-art animation presentation.
## Combat state is read-only here; visuals never change simulation or collision data.

const FIGHTER = preload("res://scripts/fighter.gd")
const NAMES = ["arthur", "vitor", "maria", "diogo", "mirkos", "felipe", "murilo", "prime"]
const COLORS = [Color("74dbff"), Color("ffce67"), Color("a99aff"), Color("50f5de"), Color("c197ff"), Color("a6efff"), Color("ff8759"), Color("f7b9ff")]
const STAGE_COLORS = [Color("50e1df"),Color("de69c7"),Color("a899f5"),Color("9b6fec"),Color("b0e3f2"),Color("e5ba65"),Color("79b2ef"),Color("ec885b"),Color("76d6c1"),Color("d294ed")]
var combat = null
var stage_id: int = 0
var time: float = 0.0
var alternate: Array = [false, false]
var debug: bool = false
var shake_strength: float = 0.6
var flash_strength: float = 0.5
var textures: Array = []
var effects: Array = []
var pulse: float = 0.0
var shake: float = 0.0
var camera_offset: float = 0.0
var paused: bool = false
var cinematic: float = 0.0
var cinematic_id: int = 0
var super_position: Vector2 = Vector2(640,400)
var _shake_offset: Vector2 = Vector2.ZERO
var _glow_texture: GradientTexture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_art()

func load_art() -> void:
	textures.clear()
	for n in NAMES:
		var path = "res://assets/fighters/" + n + ".png"
		textures.append(load(path) if ResourceLoader.exists(path) else null)

func _process(delta: float) -> void:
	if not paused:
		time += delta
		pulse = maxf(0.0, pulse - delta * 2.3)
		shake = maxf(0.0, shake - delta * 36.0)
		cinematic = maxf(0.0, cinematic - delta)
		for e in effects:
			e.age += delta
		effects = effects.filter(func(e): return e.age < 0.75)
	queue_redraw()

func ingest_events(events: Array) -> void:
	for event in events:
		var e: Dictionary = event.duplicate()
		if combat != null:
			var player = clampi(int(e.get("player",0)),0,combat.fighters.size()-1)
			e.id = combat.fighters[player].id
		e.age = 0.0
		var kind: String = str(e.get("type", e.get("kind", "hit"))).to_lower()
		if kind in ["hit", "counter", "guard_break", "super_hit", "ko", "block", "perfect_block", "parry", "clash", "projectile_clash", "throw", "super"]:
			if effects.size() >= 64:
				effects.pop_front()
			effects.append(e)
		if kind in ["hit", "counter", "guard_break", "super_hit", "ko", "super"]:
			pulse = minf(1.0, pulse + 0.45)
			shake = maxf(shake, 8.0 if kind in ["guard_break", "ko", "super"] else 3.0)
		if kind == "super":
			cinematic = 1.15
			cinematic_id = int(e.get("id", e.get("character",0)))
			super_position = Vector2(float(e.get("x",640)),float(e.get("y",450)))

func _draw() -> void:
	_shake_offset = Vector2(sin(time * 101.0), cos(time * 123.0)) * shake * shake_strength
	draw_set_transform(_shake_offset)
	draw_stage(stage_id, time, pulse)
	if combat != null:
		var sequence = combat.get("cinematic")
		if sequence is Dictionary and bool(sequence.get("active",false)):
			_draw_super_sequence(sequence,time)
			draw_set_transform(Vector2.ZERO)
			return
	if combat != null:
		for p in combat.projectiles:
			if str(p.get("kind", "projectile")) in ["trap", "barrier"]:
				draw_projectile(p,time)
		for i in range(combat.fighters.size()):
			draw_fighter(combat.fighters[i], time, alternate[i] if i < alternate.size() else false)
		for p in combat.projectiles:
			if str(p.get("kind", "projectile")) not in ["trap", "barrier"]:
				draw_projectile(p,time)
		if debug:
			for f in combat.fighters:
				draw_rect(FIGHTER.hurtbox(f),Color(0.2,1,0.7,0.25))
				draw_rect(FIGHTER.hurtbox(f),Color(0.2,1,0.7,0.9),false,2)
				draw_rect(FIGHTER.pushbox(f),Color(0.1,0.5,1,0.7),false,2)
				if combat.has_method("hitbox") and not f.get("move",{}).is_empty():
					draw_rect(combat.hitbox(f),Color(1,0.2,0.3,0.35))
	for e in effects:
		draw_effect(e, float(e.age))
	draw_set_transform(Vector2.ZERO)
	if cinematic > 0.0:
		var c = COLORS[clampi(cinematic_id,0,7)]
		var a = minf(1.0, cinematic * 3.0)
		draw_rect(Rect2(0,0,1280,38*a),Color(0.01,0.02,0.04,0.95))
		draw_rect(Rect2(0,720-38*a,1280,38*a),Color(0.01,0.02,0.04,0.95))
		for i in range(10):
			var y = 90.0 + i * 58.0
			draw_line(Vector2(fmod(time*1700+i*138.0,1500)-200,y),Vector2(fmod(time*1700+i*138.0,1500)+160,y),Color(c,0.13*a),2)

func _gradient(rect: Rect2, top: Color, bottom: Color, steps: int = 40) -> void:
	for i in range(steps):
		var y = rect.position.y + rect.size.y * float(i) / steps
		draw_rect(Rect2(rect.position.x,y,rect.size.x,rect.size.y/steps+1),top.lerp(bottom,float(i)/steps))

func _glow(center: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	if _glow_texture == null:
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.2,0.5,1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,.62),Color(1,1,1,.17),Color(1,1,1,0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.width = 256
		_glow_texture.height = 256
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(.5,.5)
		_glow_texture.fill_to = Vector2(1,.5)
	draw_texture_rect(_glow_texture,Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(color,.55*strength))

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func _ellipse(center: Vector2, radius: Vector2, color: Color, filled: bool = true, width: float = 1.0) -> void:
	var points = PackedVector2Array()
	for i in range(49):
		var a = TAU * i / 48.0
		points.append(center+Vector2(cos(a)*radius.x,sin(a)*radius.y))
	if filled:
		draw_colored_polygon(points,color)
	else:
		draw_polyline(points,color,width,true)

func _ring(center: Vector2, radius: float, color: Color, rotation: float, sections: int = 12) -> void:
	for i in range(sections):
		var a = TAU*i/sections+rotation
		draw_arc(center,radius,a,a+TAU/sections*0.74,12,color,2.0,true)

func draw_stage(id: int, t: float, impact: float = 0.0) -> void:
	var idx = posmod(id,10)
	var c: Color = STAGE_COLORS[idx]
	_gradient(Rect2(0,0,1280,540),Color("060b17"),Color(c.r*.10,c.g*.11,c.b*.15))
	var parallax = sin(t*.13)*8.0
	if combat != null and combat.fighters.size() > 1:
		parallax += ((combat.fighters[0].x+combat.fighters[1].x)*.5-640.0)*.035
	for i in range(54):
		var x = fmod(i*197.41+38,1280)
		var y = fmod(i*73.19+12,386)
		draw_circle(Vector2(x+parallax*.3,y),.6+float(i%3)*.35,Color(c, .10+.12*sin(t*.8+i)))
	match idx:
		0:
			_draw_nexus(c,t,parallax,impact)
		1:
			_draw_city(c,t,parallax,false)
		2:
			_draw_temple(c,t,parallax,false)
		3:
			_draw_station(c,t,parallax)
		4:
			_draw_city(c,t,parallax,true)
		5:
			_draw_temple(c,t,parallax,true)
		6:
			_draw_tower(c,t,parallax)
		7:
			_draw_reactor(c,t,parallax,impact)
		8:
			_draw_campus(c,t,parallax)
		9:
			_draw_dimension(c,t,parallax,impact)
	_draw_architectural_detail(c,idx,t,parallax)
	_gradient(Rect2(0,456,1280,137),Color(0.01,0.018,0.033,0),Color("101a24"),24)
	_draw_floor(c,idx,t)
	for i in range(28):
		var x = fmod(i*173.9+t*(9+idx),1340)-30
		var y = fmod(i*61.9-t*(10+idx*1.6),300)+235
		var alpha = .18+.13*sin(t+i)
		if idx == 4:
			y = fmod(i*61.9+t*33,420)+80
			draw_circle(Vector2(x,y),1.4,Color(c,alpha))
		elif idx in [1,6]:
			y = fmod(i*61.9+t*300,400)+90
			draw_line(Vector2(x,y),Vector2(x-5,y+16),Color(c,alpha*.5),1)
		else:
			draw_rect(Rect2(x,y,1.6,1.6),Color(c,alpha))
	if impact > 0:
		draw_line(Vector2(0,518),Vector2(1280,518),Color(c,impact*.4),3)

func _draw_architectural_detail(c: Color,id: int,t: float,p: float) -> void:
	# Shallow relief, perspective rails and reflected light ground every arena.
	if id in [0,3,7]:
		for i in range(20):
			var x=i*72.0-40+p*.3
			_poly([Vector2(x,500),Vector2(x+38,500),Vector2(x+26,478),Vector2(x+8,478)],Color("1a2934"))
			draw_line(Vector2(x+8,478),Vector2(x+26,478),Color(c,.28),1)
			draw_rect(Rect2(x+6,486,23,3),Color("080e17"))
		for x in [110,1138]:
			draw_rect(Rect2(x,373,38,85),Color("0c1520"))
			draw_rect(Rect2(x+5,380,28,29),Color(c,.09))
			for j in range(4):
				draw_rect(Rect2(x+8,415+j*8,17+(j%2)*7,2),Color(c,.24))
	elif id in [2,5]:
		for side in [-1,1]:
			for i in range(4):
				var x=640+side*(162+i*107)+p
				for j in range(3):
					var center=Vector2(x,306+j*48)
					draw_arc(center,9,0,TAU,4,Color(c,.10),1)
					draw_line(center-Vector2(0,12),center+Vector2(0,12),Color(c,.12),1)
		for i in range(28):
			var a=i*TAU/28.0
			var center=Vector2(640+p,248)
			draw_arc(center,177,a,a+.105,6,Color(c,.15),1,true)
	elif id in [1,4,6]:
		for i in range(5):
			var x=100+i*270+p
			draw_rect(Rect2(x,415,68,90),Color("0b121e"))
			draw_rect(Rect2(x+7,423,54,31),Color("17222e"))
			for j in range(6):
				draw_line(Vector2(x+11,428+j*4),Vector2(x+55,428+j*4),Color(c,.12),1)
			draw_circle(Vector2(x+54,472),2,Color(c,.45))
		for i in range(12):
			var x=i*118+p*.4
			draw_line(Vector2(x,504),Vector2(x,458),Color("263440"),3)
			draw_line(Vector2(x,466),Vector2(x+118,466),Color("263440"),2)
	elif id == 8:
		for x in [186,454,834,1102]:
			draw_rect(Rect2(x,460,78,8),Color("314047"))
			for side in [4,68]:
				draw_rect(Rect2(x+side,468,5,30),Color("222f37"))
		for i in range(34):
			var x=i*41.0+p
			draw_line(Vector2(x,502),Vector2(x,481),Color("2c383e"),1)
			draw_line(Vector2(x,489),Vector2(x+41,489),Color("24343c"),1)
	for i in range(3):
		var x=180+i*457+sin(t*.13+i)*20
		var pts=PackedVector2Array([Vector2(x-15,140),Vector2(x+15,140),Vector2(x+160,512),Vector2(x-140,512)])
		draw_polygon(pts,PackedColorArray([Color(c,.025),Color(c,.025),Color(c,0),Color(c,0)]))

func _draw_nexus(c: Color,t: float,p: float,impact: float) -> void:
	var center = Vector2(640+p,280)
	_glow(center,310,c,1.1+impact)
	for i in range(4):
		_ring(center,100+i*40,Color(c,.11+i*.035),t*(.035 if i%2 else -.045),16)
	for side in [-1,1]:
		for i in range(3):
			var x = 640+side*(300+i*168)+p
			_poly([Vector2(x-26,132+i*34),Vector2(x+24,142+i*34),Vector2(x+36,487),Vector2(x-46,487)],Color("0d1b28"))
			draw_line(Vector2(x-22,148+i*34),Vector2(x-38,473),Color(c,.35),3)
	_poly([center+Vector2(0,-99),center+Vector2(75,0),center+Vector2(0,99),center+Vector2(-75,0)],Color("15293b"))
	_poly([center+Vector2(0,-78),center+Vector2(41,0),center+Vector2(0,78),center+Vector2(-41,0)],Color(c,.18+.04*sin(t)))
	draw_line(center+Vector2(0,-62),center+Vector2(0,62),Color(c,.6),2)

func _draw_city(c: Color,t: float,p: float,frozen: bool) -> void:
	var moon = Vector2(950+p*.3,137)
	_glow(moon,130,Color("a0caff"),.45)
	draw_circle(moon,47,Color("364955"))
	draw_circle(moon+Vector2(-15,-9),44,Color("101c2b"))
	for layer in range(2):
		for i in range(15):
			var x = i*98-43+p*(.3+layer*.6)
			var h = 105+fmod(i*89+layer*61,190)
			var y = 449-h+layer*30
			draw_rect(Rect2(x,y,74+layer*24,460-y),Color("0b1423") if layer==0 else Color("101f2d"))
			for row in range(int(h/23)):
				for col in range(4):
					if (row*3+col+i)%4!=0:
						draw_rect(Rect2(x+11+col*16,y+15+row*22,4,8),Color(c,.04+layer*.08))
			if layer==1:
				draw_rect(Rect2(x+5,y+2,68,3),Color(c,.4))
				if frozen:
					_poly([Vector2(x,y),Vector2(x+75,y),Vector2(x+50,y+16),Vector2(x+32,y+3),Vector2(x+18,y+21)],Color("628698"))
	if not frozen:
		for i in range(3):
			var x = 168+i*433+p
			draw_rect(Rect2(x,278+i%2*58,64,131),Color(c,.1))
			draw_rect(Rect2(x+6,284+i%2*58,3,92),Color(c,.6))
			for j in range(4):
				draw_line(Vector2(x+16,299+j*19+i%2*58),Vector2(x+46,299+j*19+i%2*58),Color(c,.25),3)
		var car_x = fmod(t*55,1500)-100
		draw_line(Vector2(car_x,236),Vector2(car_x+45,236),Color(c,.4),2)
	else:
		for i in range(9):
			var x = i*164-10+p
			_poly([Vector2(x,516),Vector2(x+25,370-fmod(i*45,95)),Vector2(x+46,410),Vector2(x+74,517)],Color("1a3548"))
			draw_line(Vector2(x+25,370-fmod(i*45,95)),Vector2(x+30,495),Color(c,.32),2)

func _draw_temple(c: Color,t: float,p: float,solar: bool) -> void:
	var center = Vector2(640+p,248)
	_glow(center,280,c,.9)
	if solar:
		draw_circle(center,92,Color(c,.09))
		for i in range(20):
			var a=TAU*i/20.0+t*.015
			draw_line(center+Vector2.from_angle(a)*110,center+Vector2.from_angle(a)*156,Color(c,.18),3)
	else:
		_ring(center,112,Color(c,.27),t*.09,12)
		_ring(center,145,Color(c,.13),-t*.06,12)
		for i in range(12):
			var a=TAU*i/12.0-PI*.5
			draw_line(center+Vector2.from_angle(a)*88,center+Vector2.from_angle(a)*99,Color(c,.5),2)
		draw_line(center,center+Vector2.from_angle(t*.11)*77,Color(c,.46),2)
		draw_line(center,center+Vector2.from_angle(t*.027)*54,Color(c,.46),3)
	for side in [-1,1]:
		for i in range(3):
			var x=640+side*(260+i*190)+p
			var h=278+i*42
			draw_rect(Rect2(x-26,480-h,52,h),Color("1c222c"))
			draw_rect(Rect2(x-33,470-h,66,20),Color("2b3037"))
			draw_rect(Rect2(x-38,470,76,25),Color("27313a"))
			draw_line(Vector2(x-15,494-h),Vector2(x-15,469),Color(c,.15),3)
			if solar:
				draw_rect(Rect2(x-3,484-h,6,60),Color(c,.25))
	for i in range(4):
		draw_rect(Rect2(355-i*36,453+i*14,570+i*72,16),Color(.045+i*.009,.055+i*.008,.073+i*.007))

func _draw_station(c: Color,t: float,p: float) -> void:
	var center=Vector2(700+p*.5,225)
	_glow(center,230,c,.8)
	for i in range(7):
		_ellipse(center,Vector2(65+i*15,84+i*18),Color(c,.08),false,2)
	draw_circle(center,75,Color("070913"))
	_ring(center,81,Color(c,.52),t*.13,21)
	for i in range(5):
		var x=i*320-10+p
		_poly([Vector2(x,0),Vector2(x+65,0),Vector2(x+130,485),Vector2(x+84,490)],Color("111824"))
		draw_line(Vector2(x+50,20),Vector2(x+114,476),Color("344756"),4)
	draw_rect(Rect2(0,440,1280,60),Color("18232d"))
	for i in range(12):
		draw_rect(Rect2(i*114+22,455,62,3),Color(c,.33))
	draw_rect(Rect2(0,82,1280,16),Color("1b2734"))

func _draw_tower(c: Color,t: float,p: float) -> void:
	_draw_city(Color("699bbb"),t,p,false)
	for i in range(7):
		var x=i*230-170+sin(t*.05+i)*60
		_ellipse(Vector2(x,80+i%3*37),Vector2(210,47),Color("111b2b"))
	if fmod(t,7.0)<.15:
		var x=400+sin(floor(t/7))*370
		var points=PackedVector2Array([Vector2(x,100),Vector2(x+35,175),Vector2(x+10,170),Vector2(x+60,268)])
		draw_polyline(points,Color(c,.7*flash_strength),3,true)
		_glow(Vector2(x+20,158),280,c,flash_strength)
	for x in [70,1210]:
		draw_rect(Rect2(x-11,105,22,392),Color("182434"))
		draw_line(Vector2(x,105),Vector2(x,492),Color(c,.38),3)
		_ring(Vector2(x,128),20,Color(c,.6),t*.2,5)

func _draw_reactor(c: Color,t: float,p: float,impact: float) -> void:
	_glow(Vector2(640+p,320),320,c,.8+impact)
	for x in [280,640,1000]:
		var center=Vector2(x+p,277)
		draw_rect(Rect2(center.x-111,128,222,357),Color("111c23"))
		draw_rect(Rect2(center.x-73,145,146,324),Color("261f22"))
		for i in range(7):
			var y=159+i*44
			draw_rect(Rect2(center.x-61,y,122,18),Color(c,.05+.04*sin(t*1.4+i)))
			draw_rect(Rect2(center.x-105,y,15,21),Color(c,.45))
			draw_rect(Rect2(center.x+90,y,15,21),Color(c,.45))
		_ring(center,69,Color(c,.35),t*.3,8)
		draw_circle(center,35,Color(c,.13))
	for i in range(4):
		draw_rect(Rect2(0,77+i*16,1280,6),Color("1a252c"))

func _draw_campus(c: Color,t: float,p: float) -> void:
	_glow(Vector2(630,252),260,c,.45)
	for i in range(3):
		var x=172+i*373+p
		draw_rect(Rect2(x,209-i%2*38,264,239+i%2*38),Color("1c2733"))
		draw_rect(Rect2(x-13,199-i%2*38,289,14),Color("384552"))
		for row in range(4):
			for col in range(5):
				draw_rect(Rect2(x+17+col*47,230-i%2*38+row*43,25,26),Color(c,.07+float((row+col)%3)*.035))
	for x in [108,1140]:
		draw_line(Vector2(x,270),Vector2(x,488),Color("303d45"),6)
		draw_line(Vector2(x-25,270),Vector2(x+25,270),Color(c,.6),3)
		_glow(Vector2(x,275),65,c,.5)
	for i in range(6):
		var x=57+i*243+p
		draw_line(Vector2(x,377),Vector2(x+9,493),Color("162c31"),9)
		for k in range(3):
			draw_circle(Vector2(x+k*19-18,369+k%2*19),37,Color("173534"))
	var center=Vector2(656+p,374)
	_ring(center,68,Color(c,.18),t*.08,9)
	_poly([center+Vector2(0,-54),center+Vector2(38,0),center+Vector2(0,54),center+Vector2(-38,0)],Color(c,.16))

func _draw_dimension(c: Color,t: float,p: float,impact: float) -> void:
	var center=Vector2(640+p,240)
	_glow(center,320,c,.95+impact)
	for i in range(8):
		_ring(center,55+i*28,Color(c,.05+i*.014),t*(.05 if i%2 else -.025),7)
	draw_circle(center,45,Color("030613"))
	for i in range(15):
		var x=fmod(i*257.0+121,1350)-35+p
		var y=175+fmod(i*91,290)+sin(t*.6+i)*10
		var s=22+fmod(i*17,55)
		_poly([Vector2(x-s,y),Vector2(x+s*.7,y-12),Vector2(x+s,y+8),Vector2(x,y+s*.5)],Color("1b2037"))
		draw_line(Vector2(x-s,y),Vector2(x+s*.7,y-12),Color(c,.24),2)

func _draw_floor(c: Color,id: int,t: float) -> void:
	_gradient(Rect2(0,512,1280,208),Color("18252e"),Color("080e17"),28)
	for i in range(-6,15):
		var x = i*124.0
		draw_line(Vector2(640+(x-640)*.53,512),Vector2(x,720),Color(c,.075),1.5)
	for y in [523,546,579,626,695]:
		draw_line(Vector2(0,y),Vector2(1280,y),Color(c,.075),1)
	# Fixed deterministic fine detail avoids texture noise moving underfoot.
	for i in range(150):
		var x=fmod(i*241.91+51,1280)
		var y=518+fmod(i*91.731,200)
		var width=2+fmod(i*13.7,25)
		draw_line(Vector2(x,y),Vector2(x+width,y-.4),Color(c,.018+float(i%3)*.007),1)
	if id in [1,4,6]:
		for i in range(7):
			var x=90+i*203.0
			for j in range(5):
				draw_line(Vector2(x+j*8,538),Vector2(x+j*13-16,558),Color(c,.035),2)
	if id in [2,5,8]:
		for i in range(6):
			draw_line(Vector2(0,631+i*4),Vector2(1280,631+i*4),Color(c,.022),1)
	draw_line(Vector2(0,513),Vector2(1280,513),Color(c,.30),2)
	_ellipse(Vector2(640,591),Vector2(342,62),Color(c,.04),false,2)
	_ellipse(Vector2(640,591),Vector2(275,48),Color(c,.04),false,1)
	for side in [-1,1]:
		var x=640+side*573
		_poly([Vector2(x,616),Vector2(x+side*41,624),Vector2(x+side*89,624),Vector2(x+side*34,613)],Color(c,.36))
		if id in [0,3,7,9]:
			draw_line(Vector2(x,533),Vector2(x+side*65,571),Color(c,.24+.05*sin(t)),2)

func _frame_for(f: Dictionary) -> int:
	var state: String = str(f.get("state","idle"))
	var anim: String = str(f.get("anim",state))
	var m: Dictionary = f.get("move",{})
	if state in ["ko","knockdown","hitstun","hit","guard_break","guardbreak","throw_victim","thrown","super_victim"]:
		return 6
	if state in ["block","blockstun","crouch_block","crouch","parry","counter"]:
		return 4
	if state in ["jump","fall"] or (float(f.get("y",590))<588 and m.is_empty()):
		return 5
	if not m.is_empty() and state in ["attack","special","super","throw","charge"]:
		var k: String = str(m.get("kind","strike"))
		if k in ["projectile","trap","barrier","super","buff","counter","freeze","echo","pull","burst","wave"]:
			return 7
		if k in ["uppercut"]:
			return 5
		if k in ["slide","blink_strike"] or str(m.get("level","mid"))=="low" or "KICK" in str(m.get("name","")):
			return 3
		return 2
	if state in ["walk","dash","evade"] or anim in ["walk","walk_forward","walk_back"]:
		return 1
	if state in ["victory","intro"]:
		return 7 if (int(f.get("round_wins",0))+int(f.get("id",0)))%2 else 0
	return 0

func _source_rect(id: int, frame: int) -> Rect2:
	var tex: Texture2D = textures[id]
	var cell = tex.get_size()/Vector2(4,2)
	return Rect2(Vector2(frame%4,frame/4)*cell,cell)

func _draw_atlas_frame(id: int,target: Rect2,frame: int,color: Color) -> void:
	var source=_source_rect(id,frame)
	var pixels_to_world=target.size.x/source.size.x
	# Generated sheets have a few casting toes beyond the nominal cell edge.
	# Region adjustment keeps those toes in cast, out of hurt, with no rescaling.
	if frame==6:
		var right_edges=[396.0,428.0,417.0,400.0,411.0,421.0,400.0,417.0]
		source.size.x=right_edges[id]
		target.size.x=source.size.x*pixels_to_world
	elif frame==7:
		var left_extension=[34.0,14.0,10.0,19.0,11.0,0.0,33.0,21.0]
		var extension=float(left_extension[id])
		source.position.x-=extension
		source.size.x+=extension
		target.position.x-=extension*pixels_to_world
		target.size.x+=extension*pixels_to_world
	draw_texture_rect_region(textures[id],target,source,color)

func draw_fighter(f: Dictionary,t: float,alt: bool = false) -> void:
	var id=clampi(int(f.get("id",0)),0,7)
	var pos=Vector2(float(f.get("x",640)),float(f.get("y",590)))
	var face=float(f.get("face",1))
	var state=str(f.get("state","idle"))
	var c: Color=COLORS[id]
	var phase = float(f.get("frame",0))
	var shadow_scale=clampf(1.0-(590-pos.y)/480.0,.45,1.0)
	for i in range(3):
		_ellipse(Vector2(pos.x,594),Vector2((67+i*11)*shadow_scale,10+i*3),Color(0,0,0,.15))
	if id >= textures.size() or textures[id] == null:
		_draw_prime(pos,face,state,t,c)
		return
	var frame=int(f.get("_pose",_frame_for(f)))
	var bob=sin(t*3.4+id)*1.7 if state=="idle" else 0.0
	var stretch=Vector2(1,1)
	var rot=0.0
	if frame==1:
		bob=absf(sin(phase*.44))*3.5
		stretch.x=1.0+sin(phase*.42)*.025
	if frame==2:
		var m: Dictionary=f.get("move",{})
		var start=float(m.get("startup",8))
		if phase<start:
			frame=0
			rot=-.028*face
		else:
			stretch.x=1.025
	if frame==6:
		rot=-.045*face
		if state in ["ko","knockdown"]:
			rot=-1.34*face
			pos.y+=20
	rot += float(f.get("_visual_rotation",0.0))
	var size=Vector2(242,242)*stretch*float(f.get("_visual_scale",1.0))
	var dest=Rect2(Vector2(-size.x*.5,-size.y*.975+bob),size)
	var color=Color(0.9,0.83,1.0) if alt else Color.WHITE
	if int(f.get("invuln",0))>0:
		color.a=.65+.25*sin(t*40)
	if str(f.get("status","")) in ["freeze","frozen"]:
		color=Color("8edaff")
	if frame==6 and int(f.get("stun",0))>0:
		color=color.lerp(Color(1.3,.6,.5),.20)
	if state in ["dash","evade"] or str(f.get("move",{}).get("kind","")) in ["dash","teleport","crossup","blink_strike"]:
		for i in range(3,0,-1):
			draw_set_transform(pos+_shake_offset-Vector2(face*i*19,0),rot,Vector2(face,1))
			_draw_atlas_frame(id,dest,frame,Color(c,.055*float(4-i)))
	draw_set_transform(pos+_shake_offset,rot,Vector2(face,1))
	_draw_atlas_frame(id,dest,frame,color)
	draw_set_transform(_shake_offset)
	if float(f.get("meter",0))>=99:
		_ring(Vector2(pos.x,585),45,Color(c,.35),t*1.3,10)
		for j in range(5):
			var a=t*2+j*TAU/5.0
			draw_circle(pos+Vector2(cos(a)*49,-50-fmod(t*30+j*31,155)),1.9,Color(c,.7))
	if state in ["block","blockstun","crouch_block","parry","counter"]:
		var center=pos+Vector2(face*43,-104)
		_glow(center,44,c,.6)
		draw_arc(center,55,-PI*.42 if face>0 else PI*.58,PI*.42 if face>0 else PI*1.42,20,Color(c,.48),2,true)
	if not f.get("move",{}).is_empty() and f.move.get("family","")=="special":
		_element_marks(id,pos+Vector2(face*78,-120),c,t,0.5)
	if state == "victory":
		_ring(pos+Vector2(0,-111),126,Color(c,.22),t*.2,18)
		if frame == 7:
			_element_marks(id,pos+Vector2(face*85,-108),c,t,.8)
		else:
			for side in [-1,1]:
				for j in range(6):
					var point=pos+Vector2(side*(34+j*11),-13-fmod(t*24+j*29,160))
					draw_rect(Rect2(point,Vector2(2,5)),Color(c,.42))

func _super_clone(source: Dictionary,pos: Vector2,pose: int,scale_factor: float,rotation: float = 0.0,face: int = 1) -> Dictionary:
	var f: Dictionary=source.duplicate()
	f.x=pos.x
	f.y=pos.y
	f.face=face
	f.frame=90
	f.invuln=0
	f.state="hitstun" if pose==6 else "attack"
	f.stun=0
	f.move={"kind":"super","startup":1,"family":"cinematic"}
	f._pose=pose
	f._visual_scale=scale_factor
	f._visual_rotation=rotation
	return f

func _beam(a: Vector2,b: Vector2,c: Color,width: float,strength: float) -> void:
	var normal=(b-a).normalized().orthogonal()
	for i in range(4,0,-1):
		var w=width*(.5+i*.24)
		draw_polygon(PackedVector2Array([a+normal*w,a-normal*w,b-normal*w*.7,b+normal*w*.7]),PackedColorArray([Color(c,.05*strength),Color(c,.05*strength),Color(c,.11*strength),Color(c,.11*strength)]))
	draw_line(a,b,Color(c,.7*strength),maxf(1,width*.4),true)
	draw_line(a,b,Color(1,1,1,.68*strength),maxf(1,width*.075),true)

func _bolt(a: Vector2,b: Vector2,c: Color,t: float,power: float=1.0) -> void:
	var direction=(b-a).normalized().orthogonal()
	var pts=PackedVector2Array()
	for i in range(13):
		var q=float(i)/12.0
		pts.append(a.lerp(b,q)+direction*sin(i*19.3+floor(t*22)*6.17)*23*sin(q*PI))
	draw_polyline(pts,Color(c,.22*power),10,true)
	draw_polyline(pts,Color(c,.85*power),3,true)
	draw_polyline(pts,Color(1,1,1,.78*power),1,true)

func _ice_shard(pos: Vector2,height: float,width: float,c: Color,alpha: float=1.0) -> void:
	_poly([pos+Vector2(-width,0),pos+Vector2(-width*.4,-height*.78),pos+Vector2(0,-height),pos+Vector2(width*.72,-height*.72),pos+Vector2(width,0)],Color(c,.18*alpha))
	_poly([pos,pos+Vector2(0,-height),pos+Vector2(width*.72,-height*.72),pos+Vector2(width,0)],Color(c,.3*alpha))
	draw_line(pos+Vector2(0,-height),pos+Vector2(-width*.4,-height*.78),Color(c,.8*alpha),2,true)
	draw_line(pos+Vector2(0,-height),pos,Color(c,.55*alpha),1,true)

func _draw_super_sequence(sequence: Dictionary,t: float) -> void:
	# Presentation reads the locked timeline and draws disposable fighter copies.
	# Damage, collision, countdown and the actual positions remain in combat.gd.
	var frame=int(sequence.get("frame",0))
	var duration=maxi(1,int(sequence.get("duration",270)))
	var progress=clampf(float(frame)/duration,0,1)
	var id=clampi(int(sequence.get("character",0)),0,7)
	var ai=clampi(int(sequence.get("attacker",0)),0,1)
	var di=clampi(int(sequence.get("defender",1)),0,1)
	var c: Color=COLORS[id]
	var life=clampf(minf(frame/18.0,(duration-frame)/20.0),0,1)
	var beats=[30,65,105,145,190,240]
	var age=999.0
	var beat=0
	for i in range(beats.size()):
		if frame>=beats[i]:
			age=float(frame-beats[i])/60.0
			beat=i
	var impact=clampf(1.0-age*5.5,0,1)
	var final_hit=frame>=240
	var elapsed=float(frame)/60.0
	var a_pos=Vector2(340,592)
	var d_pos=Vector2(866,566)
	var a_pose=7
	var d_pose=6
	var a_scale=1.20
	var d_scale=1.20
	var a_rotation=0.0
	var d_rotation=-.1+sin(elapsed*7)*.018-impact*.1
	draw_rect(Rect2(0,0,1280,720),Color(.006,.011,.025,.78*life))
	_glow(Vector2(710,380),470,c,.48*life)
	# The sparse burst lines leave the combatants and the root UI readable.
	for i in range(14):
		var y=120+i*33.0
		var x=fmod(t*750+i*91,1600)-180
		draw_line(Vector2(x,y),Vector2(x+120+sin(i)*60,y),Color(c,.045*life),1)
	match id:
		0:
			# Arthur crosses the arena between strikes; the last beat is a skybolt.
			a_pose=2 if beat%2==0 else 5
			a_pos=Vector2(670-impact*150,588-beat%2*95)
			d_pos=Vector2(864+impact*14,507-sin(progress*PI)*64)
			if frame<30:
				a_pos=Vector2(340+frame*6,592)
				a_pose=7
			if final_hit:
				a_pos=Vector2(400,588)
				a_pose=7
				_bolt(Vector2(861,5),d_pos-Vector2(0,135),c,elapsed,1.4)
				_beam(Vector2(864,140),Vector2(864,597),c,54,impact)
			else:
				for k in range(3):
					_bolt(a_pos+Vector2(-90-k*70,-138+k*28),d_pos+Vector2(0,-135),c,elapsed+k,.35+impact*.3)
			_ellipse(Vector2(861,593),Vector2(105+impact*70,24),Color(c,.5*life),false,3)
		1:
			# Vitor builds a solar disk above the target and releases a broad beam.
			var sun=Vector2(790,257)
			var radius=75+progress*93
			_glow(sun,290,c,.6+impact)
			for k in range(3):
				_ring(sun,radius+k*19,Color(c,(.17+k*.05)*life),elapsed*(.18 if k%2 else -.14),18)
			for k in range(16):
				var q=k*TAU/16+elapsed*.16
				draw_line(sun+Vector2.from_angle(q)*(radius+35),sun+Vector2.from_angle(q)*(radius+55+impact*32),Color(c,.45*life),3)
			d_pos=Vector2(822,538-progress*42)
			if frame>=30:
				_beam(a_pos+Vector2(86,-144),d_pos-Vector2(0,140),c,24+beat*9,.6+impact)
			if final_hit:
				_beam(sun,d_pos+Vector2(0,30),Color("fff1b2"),96,impact+.2)
		2:
			# Maria creates three time echoes and a rotating clock cage.
			var center=Vector2(839,347)
			d_pos=Vector2(841,544)
			d_rotation=-.13
			for k in range(4):
				_ring(center,108+k*31,Color(c,.16+float(k)*.02),elapsed*(.35 if k%2 else -.29),12)
			for k in range(12):
				var q=k*TAU/12-PI*.5
				draw_line(center+Vector2.from_angle(q)*153,center+Vector2.from_angle(q)*172,Color(c,.55*life),2)
			draw_line(center,center+Vector2.from_angle(-elapsed*2.8)*138,Color("b8f9ff"),2)
			for k in range(3):
				var ghost=_super_clone(combat.fighters[ai],Vector2(345+k*117,562-k%2*93),2 if k%2 else 7,1.12)
				ghost.invuln=5
				draw_fighter(ghost,t+k*.05)
			a_pos=Vector2(458,589)
			if final_hit:
				for k in range(12):
					var q=k*TAU/12
					_beam(center+Vector2.from_angle(q)*225,center,c,11,impact)
		3:
			# Diogo teleports through a cyan data grid before the final compile.
			for x in range(0,1281,64):
				draw_line(Vector2(x,138),Vector2(x,630),Color(c,.065),1)
			for y in range(138,630,42):
				draw_line(Vector2(0,y),Vector2(1280,y),Color(c,.065),1)
			a_pos=Vector2(547+beat%2*153,584-beat%3*41)
			a_pose=2 if not final_hit else 7
			d_pos=Vector2(880+sin(beat*2.1)*16,541)
			for k in range(45):
				var point=Vector2(fmod(k*171.7+elapsed*90,1220)+30,170+fmod(k*63.9,375))
				var s=4+k%4*3
				draw_rect(Rect2(point,Vector2(s,s)),Color(c,.06+.16*impact),false,1)
			for k in range(4):
				var from=Vector2(a_pos.x-140+k*35,230+k*67)
				draw_line(from,from+Vector2(56,0),Color(c,.2+impact*.3),3)
			if final_hit:
				a_pos=Vector2(417,591)
				_beam(a_pos-Vector2(-78,145),d_pos-Vector2(0,135),c,72,impact+.3)
		4:
			# Mirkos drags the target into a dimensional well with orbiting moons.
			var well=Vector2(819,327)
			d_pos=Vector2(821,531-progress*55)
			d_scale=1.19-progress*.28
			d_rotation=-progress*.55
			_glow(well,320,c,.9)
			draw_circle(well,118+impact*18,Color("03020c"))
			for k in range(5):
				_ellipse(well,Vector2(126+k*19,131+k*27),Color(c,.18+float(k)*.025),false,2)
			for k in range(9):
				var q=elapsed*.9+k*TAU/9
				var orb=well+Vector2(cos(q)*213,sin(q)*163)
				draw_circle(orb,8+k%3*2,Color(c,.3))
				draw_arc(orb,11,0,TAU,16,Color(c,.7),1)
				if impact>.2:
					draw_line(orb,well,Color(c,impact*.3),1)
			if final_hit:
				_ring(well,130+(1-impact)*230,Color(c,impact),elapsed,36)
				d_scale=1.03
		5:
			# Felipe grows a crystalline prison; the sixth beat breaks it outward.
			d_pos=Vector2(860,566)
			d_rotation=0
			for k in range(11):
				var x=622+k*39
				var rise=clampf((frame-k*8)/55.0,0,1)
				var h=(100+sin(k*2.1)*65)*rise
				_ice_shard(Vector2(x,599),h,14,c,.8)
			if not final_hit:
				_ice_shard(Vector2(859,593),320*clampf(frame/48.0,0,1),94,c,.74)
			else:
				for k in range(21):
					var q=k*TAU/21
					var piece=Vector2(859,415)+Vector2.from_angle(q)*(36+age*450)
					_ice_shard(piece,27+k%4*9,7,c,1-age*.9)
			for k in range(36):
				var point=Vector2(fmod(k*147.8-elapsed*53+1600,1280),167+fmod(k*31.8+elapsed*31,401))
				draw_rect(Rect2(point,Vector2(2,2)),Color(c,.55))
		6:
			# Murilo lifts the opponent on a spiral of fire, then lands a fire wave.
			a_pose=5 if frame<190 else 7
			a_pos=Vector2(646,563-sin(progress*PI)*93)
			d_pos=Vector2(844,522-sin(progress*PI)*91)
			for k in range(34):
				var q=k*.31+elapsed*2
				var radius=84+k*2.8
				var point=Vector2(836,385)+Vector2(cos(q)*radius,sin(q)*radius*.84)
				var flame=Color("ffce64") if k%3==0 else c
				_glow(point,22+k%4*4,flame,.4)
				_poly([point+Vector2(-5,9),point+Vector2(3,-13-k%3*4),point+Vector2(7,6)],Color(flame,.5))
			if final_hit:
				a_pos=Vector2(402,591)
				d_pos=Vector2(865,558)
				_beam(Vector2(430,554),Vector2(1180,554),c,60,impact+.2)
				for k in range(12):
					var point=Vector2(622+k*45,589)
					_poly([point-Vector2(19,0),point+Vector2(0,-(54+k%4*36)*impact),point+Vector2(26,0)],Color(c,impact*.55))
		7:
			var center=Vector2(820,343)
			a_pos=Vector2(350,585)
			d_pos=Vector2(821,532)
			for k in range(7):
				var other: Color=COLORS[k]
				var point=center+Vector2.from_angle(k*TAU/7+elapsed*.55)*173
				_glow(point,67,other,.7)
				_beam(point,center,other,7,.5+impact)
			_ring(center,212,Color(c,.6),elapsed*.2,7)
	if final_hit:
		d_pos.x+=impact*26
		d_rotation-=impact*.23
	var attacker=_super_clone(combat.fighters[ai],a_pos,a_pose,a_scale,a_rotation,1)
	var defender=_super_clone(combat.fighters[di],d_pos,d_pose,d_scale,d_rotation,-1)
	draw_fighter(defender,t,alternate[di] if di<alternate.size() else false)
	draw_fighter(attacker,t,alternate[ai] if ai<alternate.size() else false)
	if age<.45:
		var center=d_pos-Vector2(0,137)
		var event={"type":"super_hit","id":id,"x":center.x,"y":center.y}
		draw_effect(event,age)
		_ring(center,25+age*(350 if final_hit else 220),Color(c,impact*.6),elapsed,16)
		_glow(center,105 if final_hit else 70,c,impact*.8)
	if id==5 and not final_hit and frame>45:
		# Transparent front facets make the ice prison readable over the body.
		_ice_shard(Vector2(859,593),317,94,c,.38)
	if impact>.05:
		draw_rect(Rect2(0,0,1280,720),Color(c,impact*.035*flash_strength))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,1280,42*life),Color(.003,.006,.012,.95))
	draw_rect(Rect2(0,678,1280,42*life),Color(.003,.006,.012,.95))

func _draw_prime(pos: Vector2,face: float,state: String,t: float,c: Color) -> void:
	var bob=sin(t*2)*5
	var center=pos+Vector2(0,-128+bob)
	_glow(center,90,c,.8)
	for side in [-1,1]:
		_poly([center+Vector2(side*17,13),center+Vector2(side*37,48),pos+Vector2(side*46,-8),pos+Vector2(side*10,-8)],Color("263447"))
		_poly([center+Vector2(side*22,-30),center+Vector2(side*61,-8),center+Vector2(side*70,37),center+Vector2(side*45,20)],Color("344354"))
		_poly([center+Vector2(side*29,-29),center+Vector2(side*59,-47),center+Vector2(side*79,-17),center+Vector2(side*48,-8)],Color("576173"))
		draw_line(center+Vector2(side*46,-29),center+Vector2(side*65,-19),c,2)
	_poly([center+Vector2(-26,-38),center+Vector2(26,-38),center+Vector2(38,9),center+Vector2(0,38),center+Vector2(-38,9)],Color("202b42"))
	_poly([center+Vector2(0,-31),center+Vector2(19,-5),center+Vector2(0,21),center+Vector2(-19,-5)],Color(c,.8))
	var head=center+Vector2(0,-63)
	_poly([head+Vector2(-20,-20),head+Vector2(14,-25),head+Vector2(24,2),head+Vector2(6,27),head+Vector2(-17,12)],Color("4c526d"))
	draw_line(head+Vector2(-7,-2),head+Vector2(18,-2),Color("faf0ff"),3)
	_ring(center,101,Color(c,.16),t*.22,7)
	if state in ["attack","special","super"]:
		_element_marks(7,center+Vector2(face*75,0),c,t,1)

func _element_marks(id: int,pos: Vector2,c: Color,t: float,strength: float) -> void:
	if id==0:
		var pts=PackedVector2Array()
		for i in range(7):
			pts.append(pos+Vector2(i*10-30,sin(i*2.9+t*25)*14))
		draw_polyline(pts,Color(c,.8*strength),2,true)
	elif id in [2,4,7]:
		_ring(pos,24,Color(c,.7*strength),t*1.2,8 if id==2 else 6)
		if id==4:
			draw_circle(pos,12,Color("121328"))
	elif id in [3,5]:
		for i in range(5):
			var a=t+i*TAU/5
			var p=pos+Vector2.from_angle(a)*25
			if id==3:
				draw_rect(Rect2(p,Vector2(5,5)),Color(c,.6*strength),false,1)
			else:
				_poly([p+Vector2(0,-10),p+Vector2(4,0),p+Vector2(0,7),p+Vector2(-4,0)],Color(c,.6*strength))
	else:
		for i in range(5):
			var a=t*2+i*1.26
			var p=pos+Vector2.from_angle(a)*14
			draw_circle(p,5+i%3,Color(c,.2*strength))

func draw_projectile(p: Dictionary,t: float) -> void:
	var owner=int(p.get("owner",0))
	var id=int(p.get("id",p.get("character",0)))
	if combat!=null and owner>=0 and owner<combat.fighters.size():
		id=int(combat.fighters[owner].id)
	id=clampi(id,0,7)
	var c: Color=COLORS[id]
	var pos=Vector2(float(p.get("x",640)),float(p.get("y",480)))
	var kind=str(p.get("kind","projectile"))
	var radius=float(p.get("radius",22))
	if kind=="barrier":
		var h=160.0
		draw_rect(Rect2(pos.x-12,pos.y-h,24,h),Color(c,.1))
		draw_line(pos+Vector2(-12,-h),pos+Vector2(-12,0),Color(c,.7),2)
		draw_line(pos+Vector2(12,-h),pos+Vector2(12,0),Color(c,.7),2)
		for i in range(8):
			draw_line(pos+Vector2(-9,-i*20),pos+Vector2(9,-i*20-12),Color(c,.22),1)
	elif kind=="trap":
		_ellipse(Vector2(pos.x,585),Vector2(55,13),Color(c,.20))
		_ellipse(Vector2(pos.x,585),Vector2(50,11),Color(c,.65),false,2)
		_element_marks(id,pos+Vector2(0,-15),c,t,.8)
	else:
		var vx=float(p.get("vx",p.get("speed",7)))
		if p.get("vel",null) is Vector2:
			vx=p.vel.x
		for i in range(5,0,-1):
			draw_circle(pos-Vector2(signf(vx)*i*9,0),radius*(1-i*.12),Color(c,.025*(6-i)))
		_glow(pos,radius*2.8,c,.8)
		draw_circle(pos,radius*.64,Color(c,.65))
		draw_circle(pos,radius*.28,Color("f3ffff"))
		_element_marks(id,pos,c,t,1)

func draw_effect(event: Dictionary,age: float) -> void:
	var kind=str(event.get("type",event.get("kind","hit"))).to_lower()
	var id=clampi(int(event.get("id",event.get("character",0))),0,7)
	var pos=Vector2(float(event.get("x",640)),float(event.get("y",460)))
	if event.get("pos",null) is Vector2:
		pos=event.pos
	var c: Color=COLORS[id]
	if kind in ["block","perfect_block","parry"]:
		c=Color("94f6fa")
	elif kind in ["hit","counter","throw","guard_break"]:
		c=Color("ffe2a2")
	var alpha=clampf(1-age*2.3,0,1)
	var size=26+age*170
	if kind=="guard_break":
		size*=1.5
	if age < .17:
		_glow(pos,75,c,alpha)
		draw_circle(pos,maxf(1,17-age*90),Color(1,1,1,alpha*flash_strength))
	if kind in ["block","perfect_block","parry","clash","projectile_clash"]:
		draw_arc(pos,size,0,TAU,40,Color(c,alpha),2,true)
	else:
		for i in range(11):
			var a=i*TAU/11+.17
			var direction=Vector2.from_angle(a)
			draw_line(pos+direction*size*.55,pos+direction*size*(.85+float(i%3)*.2),Color(c,alpha),3.0 if i%2 else 2.0,true)
		for i in range(5):
			var a=i*1.29+.42
			var point=pos+Vector2.from_angle(a)*(size+15)+Vector2(0,age*age*110)
			draw_rect(Rect2(point,Vector2(3,3)),Color(c,alpha))

func draw_portrait(canvas: CanvasItem,id: int,rect: Rect2,variant: int=0,flip: bool=false) -> void:
	id=clampi(id,0,7)
	if textures.size()==0:
		load_art()
	if id>=textures.size() or textures[id]==null:
		var c=COLORS[id]
		canvas.draw_circle(rect.get_center(),minf(rect.size.x,rect.size.y)*.28,Color(c,.15))
		canvas.draw_arc(rect.get_center(),minf(rect.size.x,rect.size.y)*.35,0,TAU,32,c,2)
		return
	var frames=[0,0,2,7]
	var frame=int(frames[posmod(variant,4)])
	var source=_source_rect(id,frame)
	if rect.size.y <= rect.size.x*1.1:
		source.position += source.size*Vector2(.22,.015)
		source.size *= Vector2(.53,.59)
		var ratio=rect.size.x/rect.size.y
		if source.size.x/source.size.y>ratio:
			var w=source.size.y*ratio
			source.position.x+=(source.size.x-w)*.5
			source.size.x=w
		else:
			source.size.y=source.size.x/ratio
	else:
		# Match source aspect to the card without stretching the body.
		var desired=source.size.y*rect.size.x/rect.size.y
		source.position.x+=(source.size.x-desired)*.5
		source.size.x=desired
	if flip:
		canvas.draw_set_transform(Vector2(rect.end.x,rect.position.y),0,Vector2(-1,1))
		canvas.draw_texture_rect_region(textures[id],Rect2(Vector2.ZERO,rect.size),source,Color.WHITE)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(textures[id],rect,source,Color.WHITE)

