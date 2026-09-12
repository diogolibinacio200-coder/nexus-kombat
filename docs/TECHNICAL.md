# NEXUS KOMBAT — guia técnico

Projeto Godot 4.6, GDScript, renderizador Compatibility/OpenGL. A simulação usa 60 passos por segundo; a composição visual usa coordenadas de 1280 × 720. O jogo funciona localmente, sem servidor, conta ou serviço externo.

## Módulos e contratos

| Arquivo | Responsabilidade |
| --- | --- |
| `scenes/main.tscn` | Entrada da aplicação. |
| `scripts/main.gd` | Fluxo de telas, rounds, modos, treinamento, estatísticas e integração dos módulos. |
| `scripts/combat.gd` | Simulação em frames, comandos relativos, colisões, recursos, projéteis e resolução dos golpes. |
| `scripts/fighter.gd` | Estado inicial comum, atributos-base, hurtbox e pushbox. |
| `scripts/move_db.gd` | Elenco, golpes, técnicas defensivas, supers e leitura dos ajustes externos. |
| `scripts/ai.gd` | Decisões com atraso e gerador aleatório com semente; observa o estado da luta, sem ler comandos do oponente. |
| `scripts/input_manager.gd` | Teclado físico, gamepads, remapeamento e estados/arestas dos comandos. |
| `scripts/arena_view.gd` | Arenas, poses, transformações, efeitos, câmera e apresentação dos supers. |
| `scripts/interface.gd` | Desenho dos menus, HUD e ajuda. |
| `scripts/audio_manager.gd` | Música, efeitos e narrador com canais e jogadores de áudio reutilizados. |
| `scripts/save_manager.gd` | Perfil JSON, validação, gravação temporária e recuperação por backup. |

O combate é um `RefCounted`, sem consulta direta ao teclado, relógio real ou árvore visual. `setup([id_p1, id_p2], treino)` inicia uma luta; `tick([comandos_p1, comandos_p2])` avança a simulação. `fighters`, `projectiles` e `events` fornecem os dados para apresentação; `snapshot()` retorna cópias dos estados para testes. A apresentação lê esses dados e não determina o acerto de um golpe.

O estado de cada lutador é um dicionário criado por `Fighter.create()`. Os estados incluem neutralidade, deslocamento, ataque, defesa, stun, queda, recuperação, arremesso e sequência de super. As caixas retangulares de combate são independentes do tamanho desenhado dos sprites. O chão está em `y = 590`; o centro dos lutadores permanece entre `x = 90` e `x = 1190`.

## Ajustar golpes e dados de frames

`data/balance.json` contém o objeto `moves`, indexado pelo nome exato do golpe. O arquivo é lido ao criar o banco de golpes; reinicie o jogo depois de alterar os valores. Golpes ausentes continuam usando as definições de `move_db.gd`. `data/roster.json` é uma exportação de referência; os nomes e identidades usados em execução estão em `MoveDB.ROSTER`.

Exemplo de ajuste parcial:

```json
{
  "moves": {
    "NEXUS JAB": { "damage": 45, "startup": 6, "active": 3, "recovery": 11 },
    "STATIC REBOUND [DEFENSE]": { "cost": 40, "active": 14 }
  }
}
```

O sufixo ` [DEFENSE]` distingue uma técnica defensiva de um especial que tenha o mesmo nome. Os campos `name`, `kind` e `family` definem a identidade e o comportamento e permanecem no código. Use valores numéricos coerentes: startup/active/recovery positivos; custo entre 0 e 100; dano e alcance não negativos.

| Campos | Unidade e efeito |
| --- | --- |
| `startup`, `active`, `recovery` | Frames de preparação, contato e recuperação. |
| `damage`, `guard_damage` | Dano de vida e desgaste da guarda. Vida-base: 1000; guarda-base: 100. |
| `cost` | Gasto de Nexus; capacidade-base de 100. |
| `range`, `height`, `offset_y` | Geometria da caixa de contato em coordenadas do jogo. |
| `level` | `mid`, `low` ou `high`; determina a altura de defesa válida. |
| `hitstun`, `blockstun` | Frames de vulnerabilidade e de reação ao bloqueio. |
| `push`, `pull`, `speed`, `launch` | Deslocamento e lançamento; velocidade vertical negativa sobe. |
| `chip` | Fração de dano que atravessa um bloqueio comum. |
| `invuln`, `freeze`, `duration` | Frames de invulnerabilidade, congelamento e duração de certos objetos/efeitos. |
| `chargeable` | Permite alteração de dano/preparação/recuperação quando há carga suficiente. |

Os atributos-base compartilhados estão em `Fighter.BASE`. A lógica de cancelamento usa família do golpe, confirmação de acerto e limite de cancelamentos em `Combat._command()`; o campo `cancel` permite habilitar ou desabilitar o cancelamento de cada normal. Tentativas sem energia não consomem o limite de cancelamentos.

Mecânicas que merecem atenção ao balancear:

- Buffer de comando: 7 frames; as arestas também são capturadas durante hit stop.
- Perfect Block: até 5 frames após pressionar defesa. Parry: frente + defesa, até 3 frames, para contato corpo a corpo. Esses limites têm testes de fronteira.
- Defesa baixa bloqueia `low` e `mid`; defesa em pé bloqueia `high` e `mid`. Chip de bloqueio comum preserva ao menos 1 HP.
- Esgotar a guarda cria 52 frames de Guard Break. Recuperação de guarda exige soltar defesa e respeitar o atraso após bloqueios.
- Dano de combo cai progressivamente; hitstun e limites de juggle/cancel também restringem sequências. O oitavo acerto ou o limite aéreo força saída por queda.
- Ataque + poder com 100 Nexus solicita o super; abaixo disso solicita o sexto especial, sujeito ao custo. Um super que conecta pode iniciar uma sequência de 270 frames, com dano total repartido entre os impactos da apresentação.
- Contatos simultâneos são coletados antes de resolver ataques. Arremessos simultâneos próximos se anulam por escape. Defesas comuns contra projéteis absorvem; a técnica digital pode refletir.

`tools/export_frame_data.gd` reexporta as fichas ativas. Ele grava os arquivos de dados; mantenha uma cópia dos ajustes antes de utilizá-lo como ferramenta de manutenção.

## Elenco, sprites, skins e arenas

Para substituir um lutador existente, preserve seu ID e ajuste a entrada em `MoveDB.ROSTER`, seus seis especiais, técnica defensiva e super. Isso permite testar a troca usando o mesmo núcleo de colisões e comandos. O chefe usa o ID 7 e possui uma mudança de fase específica.

Para acrescentar IDs, também amplie os limites e tabelas atualmente dimensionados para oito personagens: `character()`/`super_move()`, seleção e fluxo em `main.gd`/`interface.gd`, listas de cores e texturas em `arena_view.gd` e sequências do modo Arcade. O código atual não carrega automaticamente um personagem novo apenas por adicionar um JSON.

Os oito PNGs (sete integrantes e Nexus Prime) em `assets/fighters/` são folhas transparentes com **4 colunas × 2 linhas**. A seleção da célula está em `_frame_for()` e `_source_rect()`. Ordem dos oito quadros:

| Índice | Pose usada |
| --- | --- |
| 0 | Base/idle e preparação. |
| 1 | Deslocamento. |
| 2 | Ataque frontal. |
| 3 | Chute/ataque baixo. |
| 4 | Defesa/agachamento. |
| 5 | Salto/elevação. |
| 6 | Reação a impacto/queda. |
| 7 | Poder/pose de energia. |

A animação atual combina essas poses com movimento, escala, rotação e efeitos procedurais. Não há um conjunto de dezenas de quadros desenhados individualmente por golpe. Para adotar animação quadro a quadro, substitua o seletor de poses por atlas e sequências por estado, mantendo a simulação de frames do combate como autoridade. Preserve a transparência, o alinhamento dos pés e a proporção de células ao trocar as imagens.

O visual alternativo em partidas espelhadas usa modulação de cor. Uma skin com figurino próprio requer outra textura e sua seleção em `load_art()`/`draw_fighter()`; ela não deve alterar atributos ou caixas.

As dez arenas são desenhadas por funções em `arena_view.gd`, com movimento de camadas, detalhes e cores próprios. Não são cenas 3D independentes. Para adicionar uma arena, amplie a seleção de cenário, nomes/descrições em `main.gd`, cores/desenho em `arena_view.gd` e o mapeamento de trilha em `AudioManager.music()`.

## Input e gabinete

Chame `update()` **uma vez por passo de física**, depois `sample(0)` e `sample(1)`. Cada amostra possui `left`, `right`, `up`, `down`, `attack`, `power`, `block` e as versões `_pressed`/`_released`. Ler uma amostra várias vezes não consome a aresta. O teclado é consultado por código físico; repetição automática de tecla não gera novos ataques.

| API | Uso |
| --- | --- |
| `set_binding(player, action, physical_key)` | Remapeia tecla; conflitos, inclusive entre jogadores, trocam as duas teclas. |
| `get_binding(player, action)` | Retorna o código físico atual. |
| `set_gamepad_binding(player, action, button, device = -1)` | Remapeia botão e pode atribuir o dispositivo capturado. |
| `get_gamepad_binding(player, action)` | Retorna o índice do botão. |
| `set_gamepad_device(player, device)` | Atribui controle; troca a atribuição se o outro jogador já o utiliza. |
| `set_gamepad_axis(player, "horizontal"/"vertical", index, inverted)` | Configura eixos analógicos. |
| `set_gamepad_deadzone(player, value)` | Ajusta a zona morta, limitada a 0,1–0,9. |
| `get_gamepad_config(player)` | Retorna cópia da configuração de dispositivo, eixos e botões. |
| `defaults()` | Restaura teclado e gamepads. |
| `export_bindings()` / `load_bindings(data)` | Serialização integrada ao perfil, incluindo controles. |

Padrão de gamepad: analógico esquerdo/D-pad para movimento, A para ataque, B para poder e X para defesa. P1 e P2 usam inicialmente dispositivos 0 e 1. Botões podem ser capturados pela tela de controles; eixos, inversão e zona morta também têm API persistente para adaptação de encoders.

Esc, Enter, Enter numérico, Tab, F3, F11 e R ficam reservados à navegação, pausa, diagnóstico e treinamento. Start/Back do gamepad também são reservados. Os setters rejeitam esses códigos para evitar que um novo comando de luta dispare uma ação de sistema.

Software não recupera teclas que um teclado deixa de transmitir por ghosting. Teste no gabinete as duas diagonais e os três botões de cada jogador simultaneamente. Encoders que aparecem como teclado usam os códigos físicos; encoders que aparecem como gamepad usam a configuração de dispositivo. Os testes automatizados validam o contrato de input e a simulação simultânea; não certificam o hardware conectado.

## Áudio e perfil

`play(event, character)` resolve os aliases de eventos e reutiliza 18 players de efeito. Dois players de música permitem transições de volume; um player atende o narrador e sua fila curta. Os buses `NexusMusic`, `NexusSFX` e `NexusVoice` são criados centralmente. `set_levels(music, sfx)` controla os volumes, com narrador acompanhando efeitos.

Há 14 loops de música, 17 efeitos e 11 falas em WAV. As faixas incluem menu, seleção, VS, vitória e as dez arenas. A síntese de música/efeitos é reproduzível por `tools/generate_audio.py` com Python e NumPy. As falas foram sintetizadas com Microsoft Zira Desktop; `tools/generate_announcer.ps1` depende dessa voz local para regenerá-las. O jogador não precisa instalar Python, voz TTS ou bibliotecas para ouvir os WAVs distribuídos.

Para trocar uma faixa, mantenha o nome em `assets/audio/` ou ajuste o resolvedor do módulo. Música WAV usa loop do início ao fim; produza arquivos com transição adequada nas bordas. Eventos desconhecidos sem arquivo correspondente são ignorados. Novas falas precisam de entrada em `ANNOUNCER` e arquivo `voice_<evento>.wav`.

Antes de encerrar a árvore, use `await sound.shutdown()`. O método interrompe as reproduções e dá tempo ao AudioServer para liberar referências. `_exit_tree()` também remove os recursos e buses que o módulo criou, mas o encerramento imediato do processo não concede a mesma janela ao mixer.

O perfil padrão fica em `user://profile.json`, no diretório de dados do aplicativo da Godot. O formato contém `version`, `settings`, `stats` e `bindings`. A gravação escreve `.tmp`, sincroniza o arquivo, preserva `.bak` e então renomeia o temporário. JSON inválido tenta recuperar o backup; valores ausentes recebem padrões. `Profile.new(outro_caminho)` permite testes isolados sem tocar no perfil do jogador.

## Build, dependências e verificação

Não há addon nativo, DLL própria, GDExtension ou pacote de rede exigido pelo projeto. O executável usa o runtime e os templates de exportação da Godot. Uma integração futura com hardware nativo pode ser adicionada como GDExtension, mas não existe um plugin desse tipo implementado aqui.

Na pasta do projeto, com Godot 4.6 e o template Windows correspondente:

```powershell
.\tools\test.ps1 -Godot 'C:\Ferramentas\Godot_v4.6-stable_win64_console.exe'
.\tools\build.ps1 -Godot 'C:\Ferramentas\Godot_v4.6-stable_win64_console.exe'
```

`build.ps1` também aceita `-WindowsReleaseTemplate` e `-Output`. O preset `Windows Desktop` exporta x86_64, incorpora o PCK e inclui os JSONs de dados. A saída padrão é `../Windows/NexusKombat.exe`. Docs, testes e ferramentas ficam no projeto-fonte, fora do executável exportado.

Testes específicos podem ser executados com `godot --headless --path . --script res://tests/<arquivo>.gd`: `combat_test.gd`, `modules_test.gd`, `defense_test.gd`, `audio_test.gd` e `flow_test.gd`. O teste de áudio requer a importação dos assets primeiro. Ao alterar frame data, execute combate e defesa novamente; ao modificar menus, confirme o fluxo; ao mudar áudio, execute com `--verbose` para detectar recursos ainda referenciados no encerramento.

Os testes não substituem uma sessão real com dois jogadores, calibração do gabinete e medição de FPS na máquina de destino. A validação local do renderizador encontrou OpenGL 3.3 em Intel UHD Graphics 770; isso não garante desempenho idêntico em outro computador.


