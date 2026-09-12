extends Node2D
## Deliberately drawn interface: the game has no editor-default controls.
const BOLD = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const MEDIUM = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const INK = Color("070c17")
const WHITE = Color("edf4f8")
const MUTED = Color("8699ad")
const GOLD = Color("e7b67b")
const CYAN = Color("6de2f4")
const RED = Color("ff7d78")
var app: Node
var _roster_cache: Dictionary = {}

func tx(s: String, x: float, y: float, size: int = 24, color: Color = WHITE, width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = true) -> void:
	draw_string(BOLD if bold else MEDIUM,Vector2(x,y),s,align,width,size,color)

func center(s: String, y: float, size: int = 24, color: Color = WHITE, x: float = 0, width: float = 1280) -> void:
	tx(s,x,y,size,color,width,HORIZONTAL_ALIGNMENT_CENTER)

func line(a: Vector2,b: Vector2,color: Color = Color("2a394b"),width: float = 1.0) -> void:
	draw_line(a,b,color,width,true)

func panel(rect: Rect2, fill: Color = Color(0.025,0.045,0.075,0.94), border: Color = Color("28394b")) -> void:
	draw_rect(rect,fill)
	draw_rect(rect,border,false,1)
	draw_line(rect.position,rect.position+Vector2(24,0),GOLD,2)

func tag(label: String, x: float, y: float, color: Color = GOLD, width: float = 80) -> void:
	draw_rect(Rect2(x,y,width,25),Color(color,0.12))
	tx(label,x+8,y+19,16,color)

func keycap(label: String,x: float,y: float,color: Color = WHITE,width: float = 30) -> void:
	draw_rect(Rect2(x,y,width,28),Color(color,0.08))
	draw_rect(Rect2(x,y,width,28),Color(color,0.4),false,1)
	center(label,y+21,17,color,x,width)

func wrap_text(s: String, x: float, y: float, width: float, size: int = 22, color: Color = MUTED, leading: float = 27) -> void:
	var words = s.split(" ")
	var buffer = ""
	var row = y
	for word in words:
		var candidate = buffer+" "+word if not buffer.is_empty() else word
		if MEDIUM.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width and not buffer.is_empty():
			tx(buffer,x,row,size,color,-1,HORIZONTAL_ALIGNMENT_LEFT,false)
			buffer = word
			row += leading
		else: buffer = candidate
	if not buffer.is_empty(): tx(buffer,x,row,size,color,-1,HORIZONTAL_ALIGNMENT_LEFT,false)

func info(id: int) -> Dictionary:
	if not _roster_cache.has(id):
		_roster_cache[id] = app.fighter_info(id)
	return _roster_cache[id]

func fighter_color(id: int) -> Color:
	return Color(str(info(id).get("color","6de2f4")))

func topbar(section: String, number: String = "01") -> void:
	tx("N / K",42,43,24,GOLD)
	line(Vector2(111,23),Vector2(111,47))
	tx("NEXUS KOMBAT",132,42,19,WHITE)
	tx(section,400,42,17,MUTED)
	tx("ARCADE EDITION   /   "+number,955,42,17,MUTED,285,HORIZONTAL_ALIGNMENT_RIGHT)
	line(Vector2(40,62),Vector2(1240,62))

func footer(back: String = "VOLTAR", confirm_label: String = "CONFIRMAR") -> void:
	line(Vector2(40,664),Vector2(1240,664))
	keycap("↑↓",44,679,MUTED,44)
	tx("NAVEGAR",100,700,17,MUTED)
	keycap(app.binding_label(0,"attack"),235,679,CYAN,38)
	keycap(app.binding_label(1,"attack"),281,679,RED,38)
	tx(confirm_label,331,700,17,MUTED)
	keycap("ESC",1053,679,MUTED,46)
	tx(back,1112,700,17,MUTED)

func shade(alpha: float = 0.76) -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.012,0.021,0.04,alpha))

func draw_background() -> void:
	draw_rect(Rect2(0,0,1280,720),INK)
	for n in range(16):
		var xx = 100+n*95
		line(Vector2(xx,0),Vector2(xx-300,720),Color(0.14,0.24,0.33,0.1))
	for n in range(45):
		var xx = fmod(float(n)*173.5+app.clock_time*(3+n%4),1280)
		var yy = fmod(float(n)*79.4,720)
		draw_circle(Vector2(xx,yy),1.0,Color(GOLD,0.10+0.1*sin(app.clock_time+n)))

func _draw() -> void:
	if app == null: return
	if not app.arena.visible: draw_background()
	match app.screen:
		"boot": draw_boot()
		"menu": draw_menu()
		"select": draw_select()
		"stage": draw_stages()
		"vs": draw_vs()
		"fight": draw_hud()
		"pause":
			draw_hud()
			draw_pause()
		"training_menu":
			draw_hud()
			draw_training_menu()
		"result": draw_result()
		"settings": draw_settings()
		"controls": draw_controls()
		"help": draw_help()
		"stats": draw_stats()
		"credits": draw_credits()
		"ending": draw_ending()
		"tournament": draw_tournament()
		"tournament_result": draw_bracket()
	if app.toast_timer > 0:
		panel(Rect2(420,621,440,37),Color(0.025,0.07,0.1,0.98),CYAN)
		center(app.toast,647,20,CYAN,420,440)
	# A quick fade unifies every screen transition without delaying inputs.
	if app.screen_time < 0.18:
		draw_rect(Rect2(0,0,1280,720),Color(0.005,0.008,0.016,1.0-app.screen_time/0.18))

func emblem(pos: Vector2, radius: float, alpha: float = 1.0) -> void:
	var points: PackedVector2Array = []
	for i in range(7):
		var angle = PI/3*i-PI/2
		points.append(pos+Vector2(cos(angle),sin(angle))*radius)
	draw_polyline(points,Color(GOLD,alpha),2,true)
	tx("N",pos.x-radius,pos.y+radius*0.4,int(radius*1.7),Color(WHITE,alpha),radius*2,HORIZONTAL_ALIGNMENT_CENTER)

func draw_boot() -> void:
	shade(0.89)
	emblem(Vector2(640,260),90)
	center("NEXUS KOMBAT",442,65)
	center("SETE ENERGIAS. UMA DIMENSÃO.",486,22,GOLD)
	center("ARCADE SYSTEM  /  ORIGINAL FIGHTING GAME",626,17,MUTED)

func draw_menu() -> void:
	shade(0.54)
	app.arena.draw_portrait(self,3,Rect2(388,110,415,554),1,false)
	# Two directional dark gradients keep typography separate from the hero art.
	for i in range(12):
		draw_rect(Rect2(i*47,68,47,590),Color(0.012,0.024,0.044,0.88-i*0.058))
	draw_rect(Rect2(810,64,470,601),Color(0.012,0.024,0.044,0.9))
	topbar("LOCAL MULTIPLAYER  /  1—2 JOGADORES")
	tag("FIGHTING SYSTEM",64,145,GOLD,150)
	tx("NEXUS",60,273,108)
	tx("KOMBAT",60,365,108)
	line(Vector2(67,395),Vector2(149,395),GOLD,3)
	tx("SETE ENERGIAS.",66,438,26,GOLD)
	tx("UMA DIMENSÃO.",66,470,26,GOLD)
	wrap_text("O Nexus está aberto. Escolha seu lutador e entre na arena.",66,533,340,23,WHITE,28)
	tx("ESCOLHA SEU MODO",866,113,18,MUTED)
	for i in range(app.MENU.size()):
		var yy = 161+i*50
		var selected = i == app.menu_index
		if selected:
			var poly = PackedVector2Array([Vector2(852,yy-32),Vector2(1204,yy-32),Vector2(1190,yy+12),Vector2(838,yy+12)])
			draw_colored_polygon(poly,Color("e7b67b"))
			tx("›",859,yy+1,32,INK)
		tx("0"+str(i+1),867 if not selected else 887,yy,17,INK if selected else MUTED)
		tx(app.MENU[i],917,yy+1,29,INK if selected else WHITE)
	var desc = ["Seis confrontos. Um núcleo para libertar.","Dois jogadores. A mesma arena.","Conheça cada janela. Domine cada golpe.","Quatro competidores. Um campeão.","Aprenda os comandos e a estratégia.","Prepare o gabinete para a partida.","Sua história no Nexus.","Um universo original.","Encerrar Nexus Kombat."]
	wrap_text(desc[app.menu_index],855,637,375,19,MUTED,24)
	footer("SAIR", "ENTRAR")

func draw_select() -> void:
	shade(0.72)
	topbar("CHARACTER SELECT", "02")
	center("ESCOLHA SUA ENERGIA",111,39)
	for i in range(2):
		var id: int = app.cursors[i]
		var xx = 50 if i == 0 else 850
		var col = CYAN if i == 0 else RED
		if id < 7:
			app.arena.draw_portrait(self,id,Rect2(xx,127,380,321),1,i == 1)
			draw_rect(Rect2(xx,395,380,64),Color(0.012,0.025,0.044,0.88))
			tx(info(id).name,xx,425,37,col,380,HORIZONTAL_ALIGNMENT_CENTER)
			center(info(id).title,451,17,MUTED,xx,380)
		else:
			center("?",345,172,col,xx,380)
			center("RANDOM",425,37,col,xx,380)
		tag("P"+str(i+1),xx+150,133,col,50)
		if app.ready_players[i]:
			tag("READY" if i == 0 or app.mode not in ["arcade","training"] else "CPU",xx+128,167,col,93)
	center("VS",292,92,GOLD)
	center("ATRIBUTOS IGUAIS",345,18,WHITE)
	center("A diferença está em como você luta.",374,18,MUTED)
	if app.mode == "arcade": center("ARCADE  /  "+app.DIFFICULTIES[int(app.profile.data.settings.difficulty)],411,18,GOLD)
	for i in range(8):
		var rect = Rect2(68+i*145,478,136,157)
		panel(rect,Color(0.025,0.041,0.065,0.98))
		if i < 7:
			app.arena.draw_portrait(self,i,Rect2(rect.position+Vector2(1,1),Vector2(134,122)),0,false)
		else:
			center("?",573,71,MUTED,rect.position.x,136)
		draw_rect(Rect2(rect.position.x,600,136,35),Color(0.01,0.02,0.04,0.94))
		center(info(i).name if i < 7 else "RANDOM",623,17,WHITE,rect.position.x,136)
		for player in range(2):
			if app.cursors[player] == i:
				var col = CYAN if player == 0 else RED
				draw_rect(rect.grow(-player*4),col,false,3)
				tag("P"+str(player+1),rect.position.x+player*81,481,col,47)
	footer()

func draw_stages() -> void:
	shade(0.35)
	topbar("STAGE SELECT", "03")
	center("ESCOLHA A ARENA",120,38)
	tag("ARENA  /  "+str(app.stage+1).pad_zeros(2),63,162,GOLD,128)
	tx(app.STAGES[app.stage],62,229,54)
	wrap_text(app.STAGE_SUB[app.stage],65,266,530,24,WHITE)
	tx("MESMAS REGRAS. NOVOS HORIZONTES.",64,370,19,MUTED)
	for i in range(10):
		var xx = 64+(i%5)*234
		var yy = 408+int(i/5)*86
		var selected = app.stage_cursor == i
		panel(Rect2(xx,yy,218,71),Color(0.02,0.035,0.065,0.95),GOLD if selected else Color("304256"))
		if selected: draw_rect(Rect2(xx,yy,4,71),GOLD)
		tx(str(i+1).pad_zeros(2),xx+13,yy+27,19,GOLD if selected else MUTED)
		tx(app.STAGES[i],xx+13,yy+53,19,WHITE)
	panel(Rect2(64,587,1154,42),Color(0.02,0.035,0.065,0.95),GOLD if app.stage_cursor == 10 else Color("304256"))
	center("?    RANDOM ARENA",616,22,GOLD if app.stage_cursor == 10 else MUTED)
	footer()

func draw_vs() -> void:
	shade(0.82)
	var shift = maxf(0,1.0-app.screen_time*2.7)*170
	for i in range(2):
		var xx = 62-shift if i == 0 else 819+shift
		var id: int = app.chosen[i]
		var col = fighter_color(id)
		draw_colored_polygon(PackedVector2Array([Vector2(xx+10,115),Vector2(xx+400,115),Vector2(xx+330,581),Vector2(xx-60,581)]),Color(col,0.08))
		app.arena.draw_portrait(self,id,Rect2(xx,90,400,491),2,i == 1)
		center(info(id).name,581,49,WHITE,xx-20,440)
		center(info(id).title,611,19,col,xx-20,440)
	center("VS",380,139,GOLD)
	center("//",415,35,MUTED)
	center(app.STAGES[app.stage],468,23,WHITE)
	topbar("VERSUS  /  PREPARE-SE", "04")
	if app.mode == "arcade": center("ARCADE  •  CONFRONTO "+str(app.arcade_index+1)+" / 6",103,20,GOLD)
	if app.mode == "tournament": center("TOURNAMENT  •  "+("FINAL" if app.tournament_round == 2 else "SEMIFINAL "+str(app.tournament_round+1)),103,20,GOLD)
	line(Vector2(70,653),Vector2(1210,653))
	center("PRESSIONE ATAQUE PARA AVANÇAR",692,17,MUTED)

func meter_bar(value: float,rect: Rect2,color: Color,reverse: bool = false) -> void:
	draw_rect(rect,Color(0.015,0.022,0.038,0.95))
	var amount = clampf(value,0,1)*rect.size.x
	var fill_rect = Rect2(rect.position,Vector2(amount,rect.size.y))
	if reverse: fill_rect.position.x += rect.size.x-amount
	draw_rect(fill_rect,color)
	draw_rect(Rect2(fill_rect.position,Vector2(fill_rect.size.x,2)),Color(WHITE,0.55))
	draw_rect(rect,Color(WHITE,0.2),false,1)

func draw_hud() -> void:
	if app.combat.fighters.size() < 2: return
	for j in range(8):
		draw_rect(Rect2(0,j*21,1280,21),Color(0.008,0.015,0.028,0.94-j*0.10))
	for i in range(2):
		var f: Dictionary = app.combat.fighters[i]
		var xx = 44 if i == 0 else 780
		var col = CYAN if i == 0 else RED
		var alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		tx("P"+str(i+1)+"   /   "+info(f.id).name,xx,43,27,WHITE,456,alignment)
		meter_bar(f.hp/1000.0,Rect2(xx,57,456,24),Color("d9dec9") if f.hp > 250 else RED,i == 1)
		meter_bar(f.guard/100.0,Rect2(xx,91,456,5),GOLD,i == 1)
		tx("GUARD",xx,113,13,MUTED,456,alignment)
		meter_bar(f.meter/100.0,Rect2(xx,128,456,10),col,i == 1)
		for n in range(1,4): line(Vector2(xx+114*n,128),Vector2(xx+114*n,138),INK,2)
		tx("SUPER READY" if f.meter >= 100 else "NEXUS  "+str(int(f.meter))+"%",xx,159,15,col if f.meter >= 100 else MUTED,456,alignment)
		for n in range(int((int(app.profile.data.settings.rounds)+1)/2)):
			var rx = xx+n*20+8 if i == 0 else xx+448-n*20
			var points = PackedVector2Array([Vector2(rx,172),Vector2(rx+6,178),Vector2(rx,184),Vector2(rx-6,178)])
			draw_colored_polygon(points,GOLD if n < app.wins[i] else Color("283748"))
		if f.combo >= 2:
			var cx = 85 if i == 0 else 920
			tx(str(f.combo),cx,283,76,col)
			tx("HIT",cx+88,270,29,WHITE)
			tx(str(int(f.combo_damage))+" DAMAGE",cx+3,309,19,MUTED)
	panel(Rect2(572,26,136,89),Color(0.025,0.04,0.065,0.91),Color("425365"))
	center("∞" if app.mode == "training" else str(ceili(app.combat.time_frames/60.0)).pad_zeros(2),91,65)
	center("ROUND "+str(app.round_number),137,16,GOLD)
	center(app.STAGES[app.stage],162,14,MUTED)
	if app.intro_frames > 0:
		if app.intro_frames > 120:
			for i in range(2):
				center("“"+str(info(app.chosen[i]).quote)+"”",395+i*44,24,WHITE)
		else:
			center("FIGHT!" if app.intro_frames <= 60 else ("FINAL ROUND" if app.is_final_round() and app.round_number > 1 else "ROUND "+str(app.round_number)),370,94,GOLD)
	if app.round_end_timer > 0:
		shade(0.30)
		center("TIME UP" if app.combat.time_frames <= 0 else "K.O.",376,146,GOLD)
		center("EMPATE • NOVO ROUND" if app.combat.winner == 2 else info(app.chosen[app.combat.winner]).name+" VENCE O ROUND",432,30,WHITE)
	for n in app.notices:
		var xx = 56 if n.player == 0 else 824
		var alpha = minf(1,(1.3-n.age)*2)
		tx(n.text,xx,230-n.age*16,28,Color(GOLD,alpha),400,HORIZONTAL_ALIGNMENT_LEFT if n.player == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
	for f in app.combat.fighters:
		if f.state == "super":
			draw_rect(Rect2(0,183,1280,52),Color(0.006,0.01,0.028,0.9))
			draw_rect(Rect2(0,593,1280,48),Color(0.006,0.01,0.028,0.9))
			center(str(info(f.id).super),221,32,fighter_color(f.id))
			center("NEXUS RELEASE  /  "+info(f.id).name,624,19,GOLD)
	draw_rect(Rect2(0,663,1280,57),Color(0.014,0.023,0.041,0.97))
	line(Vector2(40,663),Vector2(1240,663))
	for i in range(2):
		var xx = 40 if i == 0 else 835
		var col = CYAN if i == 0 else RED
		for n in range(3):
			var action = ["attack","power","block"][n]
			keycap(app.binding_label(i,action),xx+n*136,680,col,32)
			tx(["ATAQUE","PODER","DEFESA"][n],xx+41+n*136,700,16,MUTED)
	center("ESC  /  PAUSA" if app.mode != "training" else "TAB  TREINO  ·  R  RESET",700,15,MUTED,453,370)
	if app.mode == "attract":
		center("NEXUS KOMBAT",566,53,WHITE)
		center("PRESSIONE QUALQUER BOTÃO",623,27,GOLD if int(app.clock_time*2)%2 == 0 else WHITE)
	if app.mode == "training": draw_training_hud()
	if app.debug_view: draw_debug()

func draw_training_hud() -> void:
	if app.tutorial:
		var messages = ["MOVIMENTE-SE  /  A + D", "ACERTE TRÊS ATAQUES  /  F", "DEFENDA UM GOLPE  /  H", "PERFECT BLOCK  /  H POUCO ANTES DO IMPACTO", "QUEBRE A GUARDA  /  PRESSIONE COM GOLPES", "USE UM PODER  /  G", "CONECTE DOIS GOLPES  /  F, → + F, → + G", "ATIVE O SUPER  /  F + G COM NEXUS CHEIO", "TREINO CONCLUÍDO  /  EXPLORE SEUS GOLPES"]
		panel(Rect2(285,195,710,56),Color(0.02,0.04,0.07,0.95),GOLD)
		center(str(mini(8,app.tutorial_step+1))+" / 8    "+messages[mini(8,app.tutorial_step)],231,22,WHITE)
	else:
		tag("TRAINING",565,190,GOLD,150)
	var f: Dictionary = app.combat.fighters[0]
	panel(Rect2(44,377,218,239),Color(0.016,0.028,0.05,0.85))
	tx("INPUT HISTORY",60,403,18,GOLD)
	for i in range(app.input_history[0].size()):
		tx(str(app.input_history[0][i]).to_upper(),60,432+i*22,15,MUTED)
	if not f.move.is_empty():
		panel(Rect2(940,390,298,164),Color(0.016,0.028,0.05,0.87))
		tx(str(f.move.name),959,420,23,GOLD)
		tx("STARTUP / ACTIVE / RECOVERY",959,451,15,MUTED)
		tx("%s  /  %s  /  %s FRAMES"%[f.move.get("startup",0),f.move.get("active",0),f.move.get("recovery",0)],959,481,22)
		tx("DANO "+str(f.move.get("damage",0))+"    GUARDA "+str(f.move.get("guard_damage",0)),959,518,18,MUTED)

func draw_debug() -> void:
	panel(Rect2(390,505,505,127),Color(0.012,0.02,0.03,0.97),CYAN)
	tx("DEBUG  /  "+str(Engine.get_frames_per_second())+" FPS  /  60 HZ",404,532,18,CYAN)
	for i in range(2):
		var f: Dictionary = app.combat.fighters[i]
		tx("P%d %s  f:%d  x:%.1f y:%.1f v:(%.1f,%.1f)"%[i+1,f.state,f.frame,f.x,f.y,f.vel.x,f.vel.y],404,557+i*22,16,WHITE)
	tx("F3 FECHA  •  VERDE HURTBOX / VERMELHO HITBOX / AZUL PUSHBOX",404,611,13,MUTED)

func choice_list(options: Array,selected: int,x: float,y: float,width: float = 400,step: float = 48) -> void:
	for i in range(options.size()):
		if i == selected:
			draw_rect(Rect2(x,y+i*step-28,width,40),GOLD)
			tx("›",x+12,y+i*step+1,30,INK)
		tx(str(options[i]),x+38,y+i*step,24,INK if i == selected else WHITE)

func draw_pause() -> void:
	shade(0.86)
	panel(Rect2(370,115,540,511))
	tx("PAUSADO",407,178,43)
	tx("A ARENA ESPERA POR VOCÊ",409,207,17,MUTED)
	var options = ["CONTINUAR", "CONTROLES", "LISTA DE GOLPES", "REINICIAR PARTIDA", "SELEÇÃO", "MENU PRINCIPAL"]
	if app.mode == "training": options.insert(3,"OPÇÕES DE TREINO")
	choice_list(options,app.pause_index,402,259,476,47)

func draw_result() -> void:
	shade(0.88)
	var winner: int = maxi(0,app.match_winner)
	var id: int = app.chosen[winner]
	app.arena.draw_portrait(self,id,Rect2(64,99,490,543),3,false)
	topbar("MATCH RESULT", "05")
	tag("PLAYER "+str(winner+1)+" WINS",644,146,GOLD,182)
	tx(info(id).name,637,247,65)
	tx("VITÓRIA",641,301,42,fighter_color(id))
	tx(str(app.wins[0])+"  —  "+str(app.wins[1]),642,356,39,WHITE)
	tx("MAIOR COMBO  "+str(app.event_counts.biggest_combo)+" HIT",642,395,21,MUTED)
	choice_list(app.result_options(),app.result_index,634,474,528,52)
	footer("MENU", "CONTINUAR")

func draw_settings() -> void:
	topbar("SYSTEM SETTINGS", "06")
	tx("SEU GABINETE.",65,136,52)
	tx("SUAS REGRAS.",65,185,52,GOLD)
	wrap_text("Ajuste imagem, som e partida. As alterações são salvas automaticamente neste computador.",68,237,327,23,MUTED,29)
	panel(Rect2(67,394,328,192))
	tx("ACESSIBILIDADE",88,426,20,GOLD)
	wrap_text("Reduza os flashes e a vibração da câmera. Os jogadores compartilham os mesmos atributos e regras.",88,462,281,22,MUTED,28)
	var s: Dictionary = app.profile.data.settings
	var labels = ["MÚSICA", "EFEITOS E NARRADOR", "VIBRAÇÃO DA CÂMERA", "INTENSIDADE DE FLASH", "ROUNDS", "DIFICULDADE DA IA", "TELA CHEIA", "RESOLUÇÃO", "MODO FLIPERAMA", "REMAPEAR CONTROLES", "VOLTAR"]
	var values = [str(roundi(s.music*100))+"%",str(roundi(s.sfx*100))+"%",str(roundi(s.shake*100))+"%",str(roundi(s.flashes*100))+"%","BEST OF "+str(s.rounds),app.DIFFICULTIES[int(s.difficulty)],"SIM" if s.fullscreen else "NÃO","1280 × 720" if int(s.resolution) == 0 else "1920 × 1080","ATIVO" if s.arcade_mode else "DESATIVADO","→", "→"]
	for i in range(labels.size()):
		var yy = 133+i*46
		var selected = app.settings_index == i
		if selected: draw_rect(Rect2(455,yy-28,760,40),Color(GOLD,0.13))
		tx(labels[i],478,yy,21,GOLD if selected else WHITE)
		tx("‹  "+values[i]+"  ›" if selected else values[i],904,yy,21,GOLD if selected else MUTED,290,HORIZONTAL_ALIGNMENT_RIGHT)
	footer("MENU", "ALTERAR")

func draw_controls() -> void:
	topbar("INPUT CONFIGURATION", "07")
	tx("CONTROLES",65,127,48)
	tx("←  PLAYER "+str(app.controls_player+1)+"  →",835,126,29,CYAN if app.controls_player == 0 else RED,380,HORIZONTAL_ALIGNMENT_RIGHT)
	tx("TECLADO",502,165,14,MUTED)
	tx("PAD",595,165,14,MUTED)
	var labels = ["PULAR / CIMA","AGACHAR / BAIXO","ESQUERDA","DIREITA","ATAQUE","PODER","DEFESA","RESTAURAR PADRÕES","VOLTAR"]
	for i in range(labels.size()):
		var yy = 203+i*44
		if i == app.controls_index: draw_rect(Rect2(66,yy-26,592,38),Color(GOLD,0.15))
		tx(labels[i],86,yy,23,GOLD if i == app.controls_index else WHITE)
		if i < 7:
			keycap(app.binding_label(app.controls_player,app.controls_actions[i]),498,yy-23,CYAN if app.controls_player == 0 else RED,76)
			keycap(str(app.input.get_gamepad_binding(app.controls_player,app.controls_actions[i])),584,yy-23,GOLD,54)
	panel(Rect2(710,177,505,282))
	tx("GAMEPAD / ENCODER USB",733,211,25,GOLD)
	wrap_text("Padrão: direcional ou analógico move. A ataca. B usa poder. X defende. Start pausa. Back volta.",733,252,454,23,WHITE,30)
	wrap_text("Selecione uma ação e pressione a nova tecla ou botão do controle. PAD mostra o índice do botão. Encoders USB também podem usar as teclas ao lado.",733,353,454,21,MUTED,27)
	tx("TESTE DE TECLAS SIMULTÂNEAS",731,508,21,GOLD)
	for player in range(2):
		var held: Array = []
		for action in app.controls_actions:
			if Input.is_physical_key_pressed(app.input.get_binding(player,action)): held.append(app.binding_label(player,action))
		tx("P"+str(player+1)+"  [ "+"  ".join(held)+" ]",733,544+player*31,23,CYAN if player == 0 else RED)
	footer("VOLTAR", "REMAPEAR")
	if app.capturing_binding:
		shade(0.91)
		panel(Rect2(270,242,740,206),INK,GOLD)
		center("PRESSIONE A TECLA OU BOTÃO",312,38,GOLD)
		center(labels[app.controls_index]+"  /  PLAYER "+str(app.controls_player+1),355,27)
		center("ESC / BACK cancela a alteração",405,20,MUTED)

func draw_help() -> void:
	topbar("HOW TO PLAY  /  ← → MUDA A PÁGINA", "08")
	if app.help_page == 0:
		tx("FÁCIL DE APRENDER.",64,139,51)
		tx("PROFUNDO PARA DOMINAR.",64,190,51,GOLD)
		var titles = ["01  MOVA-SE", "02  ATAQUE", "03  USE ENERGIA", "04  DEFENDA"]
		var bodies = ["P1: W A S D. P2: setas. Pule sobre o rival para trocar de lado. Seus golpes acompanham a direção do adversário.","P1: F. P2: J. Frente + ataque pressiona. Baixo + ataque atinge a guarda alta. No ar, muda o golpe.","P1: G. P2: K. A direção escolhe um dos especiais. Ataque + poder libera o sexto golpe ou o SUPER com 100% de Nexus.","P1: H. P2: L. Segure para bloquear. Baixo + defesa cobre golpes baixos. Sua guarda se esgota sob pressão."]
		for i in range(4):
			var xx = 65+(i%2)*588
			var yy = 232+int(i/2)*172
			panel(Rect2(xx,yy,558,153))
			tx(titles[i],xx+20,yy+35,25,CYAN if i%2 == 0 else GOLD)
			wrap_text(bodies[i],xx+20,yy+68,513,22,MUTED,25)
	elif app.help_page == 1:
		tx("VÁ ALÉM DO PRIMEIRO GOLPE.",64,137,46)
		var rows = [["PERFECT BLOCK / PARRY","Defenda nos últimos 5 frames antes do impacto. Frente + defesa nos últimos 3 frames executa parry."],["GUARD BREAK","Pressionar uma guarda esgotada abre uma janela para punir. Afaste-se e solte a defesa para recuperar guarda."],["THROW / THROW BREAK","Ataque + defesa, bem perto do rival. A vítima pode apertar a mesma combinação na janela inicial para escapar."],["COMBO / CANCEL","Conecte ataques e cancele um normal confirmado em especial. Dano e hit stun diminuem; pushback e limites encerram sequências."],["NEXUS / SUPER","Acertar, defender e receber golpes gera Nexus. Os especiais custam energia; ataque + poder com 100% ativa o Super."],["RECUPERAÇÃO","Golpes fortes errados podem ser punidos. No chão, use ataque para levantar rápido ou direção + defesa para rolar."]]
		for i in range(rows.size()):
			var yy = 194+i*70
			tx(rows[i][0],66,yy,21,GOLD)
			wrap_text(rows[i][1],405,yy,792,21,MUTED,24)
			line(Vector2(65,yy+38),Vector2(1210,yy+38))
	else:
		var id: int = app.help_page-2
		var data = info(id)
		tx(data.name,64,134,48)
		tx(data.title,65,167,23,fighter_color(id))
		app.arena.draw_portrait(self,id,Rect2(67,197,330,410),1,false)
		var names = ["PODER", "FRENTE + PODER", "TRÁS + PODER", "BAIXO + PODER", "CIMA + PODER", "ATAQUE + PODER"]
		var specials: Array = data.specials
		tx("COMANDO RELATIVO AO RIVAL",444,206,16,MUTED)
		tx("GOLPE",737,206,16,MUTED)
		tx("NEXUS",1114,206,16,MUTED)
		for i in range(mini(6,specials.size())):
			var move = specials[i]
			var yy = 245+i*48
			tx(names[i],443,yy,20,WHITE)
			tx(str(move.name),737,yy,23,fighter_color(id))
			tx(str(int(move.get("cost",0)))+"%",1114,yy,21,MUTED)
			line(Vector2(444,yy+14),Vector2(1192,yy+14))
		tag("SUPER  /  100%",443,545,GOLD,165)
		tx(str(data.super),632,571,34,GOLD)
		tx("ASSINATURA  /  "+" → ".join(data.get("signature",[])),443,614,18,MUTED)
	footer("VOLTAR", "TUTORIAL" if app.previous_screen == "menu" else "")
	center(str(app.help_page+1)+" / 9",701,18,GOLD)

func draw_training_menu() -> void:
	shade(0.9)
	panel(Rect2(300,131,680,472))
	tx("LABORATÓRIO NEXUS",332,187,38)
	var opt: Dictionary = app.train_options
	var values = [["PARADO","DEFENDENDO","PULANDO","ATACANDO","IA"][int(opt.dummy)],"SIM" if opt.health else "NÃO","SIM" if opt.meter else "NÃO","SIM" if opt.guard else "NÃO","SIM" if opt.boxes else "NÃO","→","→"]
	for i in range(app.TRAIN_OPTIONS.size()):
		var yy = 247+i*47
		if i == app.train_index: draw_rect(Rect2(326,yy-29,628,40),Color(GOLD,0.14))
		tx(app.TRAIN_OPTIONS[i],345,yy,24,GOLD if i == app.train_index else WHITE)
		tx(values[i],767,yy,23,MUTED,161,HORIZONTAL_ALIGNMENT_RIGHT)

func draw_stats() -> void:
	topbar("STATISTICS", "09")
	tx("SUA HISTÓRIA NO NEXUS",64,137,47)
	var s: Dictionary = app.profile.data.stats
	var most = "—"
	var maximum = 0
	for k in s.get("most_played",{}):
		if int(s.most_played[k]) > maximum:
			maximum = int(s.most_played[k])
			most = str(info(int(k)).name)
	var labels = ["PARTIDAS JOGADAS","VITÓRIAS P1","VITÓRIAS P2","MAIOR COMBO","PERFECT BLOCKS","GUARD BREAKS","SUPERS UTILIZADOS","MAIS JOGADO"]
	var values = [str(s.get("matches",0)),str(s.get("p1_wins",0)),str(s.get("p2_wins",0)),str(s.get("biggest_combo",0))+" HIT",str(s.get("perfect_blocks",0)),str(s.get("guard_breaks",0)),str(s.get("supers",0)),most]
	for i in range(8):
		var xx = 65+(i%4)*294
		var yy = 204+int(i/4)*199
		panel(Rect2(xx,yy,272,175))
		tx(labels[i],xx+20,yy+39,18,MUTED)
		tx(values[i],xx+20,yy+113,46 if i != 7 else 28,GOLD)
	footer("MENU","VOLTAR")

func draw_credits() -> void:
	topbar("CREDITS", "10")
	tx("NEXUS KOMBAT",64,151,65)
	tx("UM UNIVERSO ORIGINAL",67,193,25,GOLD)
	wrap_text("Criação, programação e direção técnica: desenvolvimento assistido por IA. Elenco visual: Arthur, Vitor do Bem, Maria, Diogo, Mirkos, Felipe e Murilo, conforme referências autorizadas fornecidas.",69,255,760,25,WHITE,31)
	wrap_text("Arte: sprites gerados a partir das referências. Cenários e efeitos: composição procedural original. Música e efeitos sonoros: síntese original. Narrador: voz sintética Microsoft Zira, gerada localmente.",69,400,760,23,MUTED,30)
	wrap_text("Engine Godot 4.6 • licença MIT. Tipografia Rajdhani • Indian Type Foundry • SIL Open Font License. Nenhum personagem, música ou cenário de outras franquias foi incorporado.",69,530,760,21,MUTED,27)
	emblem(Vector2(1037,357),113)
	footer("MENU","VOLTAR")

func draw_ending() -> void:
	shade(0.87)
	var id: int = app.chosen[0]
	app.arena.draw_portrait(self,id,Rect2(67,94,452,545),3,false)
	topbar("ARCADE COMPLETE", "11")
	tag("O NEXUS FOI LIBERTADO",606,159,GOLD,249)
	tx(info(id).name,600,245,62)
	wrap_text(str(info(id).ending),606,321,574,28,WHITE,37)
	wrap_text("O núcleo silencia. Mas onde existe energia, uma nova história pode começar.",606,502,550,23,MUTED,30)
	center("PRESSIONE ATAQUE PARA VOLTAR AO MENU",695,20,GOLD)

func draw_tournament() -> void:
	shade(0.87)
	topbar("TOURNAMENT  /  INSCRIÇÃO", "12")
	tx("QUATRO LUTADORES. UM CAMPEÃO.",63,129,44)
	tx("ESCOLHA O PARTICIPANTE "+str(app.tournament_roster.size()+1)+" / 4",65,173,24,GOLD)
	for i in range(7):
		var rect = Rect2(65+i*166,225,151,226)
		panel(rect,Color(0.03,0.05,0.08,0.96),GOLD if i == app.tournament_cursor else Color("27394a"))
		app.arena.draw_portrait(self,i,Rect2(rect.position+Vector2(1,1),Vector2(149,187)),0,false)
		center(info(i).name,rect.position.y+213,19,GOLD if i == app.tournament_cursor else WHITE,rect.position.x,151)
	for i in range(4):
		var xx = 65+i*290
		panel(Rect2(xx,497,274,105))
		tx("PARTICIPANTE "+str(i+1),xx+17,527,18,MUTED)
		tx(info(app.tournament_roster[i]).name if i < app.tournament_roster.size() else "AGUARDANDO",xx+17,568,26,GOLD if i < app.tournament_roster.size() else MUTED)
	footer("MENU","INSCREVER")

func draw_bracket() -> void:
	shade(0.87)
	topbar("TOURNAMENT  /  CHAVEAMENTO", "12")
	center("CAMPEÃO DO NEXUS" if app.tournament_round >= 3 else "A DISPUTA CONTINUA",141,44,GOLD)
	for i in range(4):
		var yy = 230+i*82
		panel(Rect2(70,yy,300,61))
		tx(info(app.tournament_roster[i]).name,89,yy+39,27)
		line(Vector2(370,yy+30),Vector2(463,yy+30))
	for i in range(2):
		var yy = 271+i*164
		line(Vector2(463,yy-11),Vector2(463,yy+71))
		line(Vector2(463,yy+30),Vector2(527,yy+30))
		panel(Rect2(527,yy,300,61))
		tx(info(app.tournament_winners[i]).name if app.tournament_winners.size() > i else "AGUARDANDO",545,yy+39,27,GOLD)
		line(Vector2(827,yy+30),Vector2(889,yy+30))
	line(Vector2(889,301),Vector2(889,465))
	line(Vector2(889,383),Vector2(939,383))
	panel(Rect2(939,347,273,78),Color(0.07,0.065,0.054,1),GOLD)
	center(info(app.tournament_winners[2]).name if app.tournament_round >= 3 else "FINAL",396,29,GOLD,939,273)
	center("PRESSIONE ATAQUE PARA "+("VOLTAR AO MENU" if app.tournament_round >= 3 else "A PRÓXIMA PARTIDA"),640,24,WHITE)


