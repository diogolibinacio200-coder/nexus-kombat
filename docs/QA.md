# Verificação da entrega 0.1

Validação local em Windows, Godot 4.6 Standard, renderer Compatibility/OpenGL 3.3 e Intel UHD Graphics 770.

## Testes automatizados

Última execução integrada: **522 verificações, zero falhas**. Sem mensagens de erro de script, recursos pendentes ou vazamentos ao encerrar essa execução.

| Suíte | Verificações | Cobertura principal |
|---|---:|---|
| `combat_test.gd` | 245 | Atributos iguais, normais/especiais, contato, defesa, Perfect Block, parry, guard break, throw/tech, projéteis, troca de lado, combos, Supers, IA reproduzível, boss e wake-up |
| `modules_test.gd` | 56 | Remapeamento, conflito entre jogadores, gamepads, dispositivos/eixos, hotkeys reservadas, perfil e backup |
| `audio_test.gd` | 47 | 42 assets reais, crossfades, narração, pool de áudio e liberação ao fechar |
| `defense_test.gd` | 11 | Fronteiras 5/6 de Perfect Block e 3/4 de parry, altura de defesa e ataques simultâneos |
| `data_test.gd` | 12 | Arquivo de balanceamento, tipos, identidades protegidas, entradas inválidas e cancelamento configurável |
| `flow_test.gd` | 151 | Menu, seleção simultânea, arena, VS, luta, rounds, empate, best-of 1/3/5, revanche, Arcade, torneio, treino, tutorial, captura de controles e attract |

Os testes de fluxo injetam comandos e resultados específicos para verificar transições. Os testes de combate exercitam a simulação de golpes. Esse conjunto não é uma simulação de mãos humanas pressionando o teclado físico.

## Renderização e desempenho

`presentation_test.gd` executou **2.400 passos em 39,916 segundos**, alternando as dez arenas e os sete lutadores, com dois agentes de IA e energia para Supers. As amostras de FPS coletadas a cada segundo registraram **mínimo 60, mediana 60 e máximo 60**, em janela de **1280 × 720**.

Resultados detalhados: [`performance.json`](performance.json). A coleta periódica não mede a latência física do controle nem garante a ausência de um frame isolado mais lento. A meta de 60 FPS deve ser conferida no computador do gabinete e em 1920 × 1080.

Foram renderizadas e inspecionadas capturas de menu, seleção, VS, luta, pausa, controles, configurações, ajuda e resultado. As dez arenas e as oito sequências cinematográficas também foram percorridas no renderizador real. Foram corrigidos o retrato espelhado de P2 e recortes de atlas que mostravam pixels da célula vizinha.

O executável Windows foi exportado com PCK embutido, aberto sem editor e encerrado com código 0. Capturas do executável confirmaram a composição em janela 1280 × 720 e tela cheia 1920 × 1080. A captura de teste usa parâmetros próprios para pular às telas; esses parâmetros não são necessários para jogar.

## Limites de aceitação

- A animação usa oito poses por atlas e transformações procedurais. Ainda há espaço para animações com mais quadros, transições desenhadas e maior variedade de poses de vitória.
- A equivalência dos atributos base está testada. A equivalência competitiva dos kits exige partidas humanas e análise de resultados; os testes não comprovam que todos os confrontos estão balanceados.
- A IA respeita os mesmos recursos e possui atraso de reação; sua dificuldade ainda pode ser refinada com jogadores.
- Keyboard ghosting, encoder USB, gamepad físico, diagonais e combinações com os dois jogadores precisam ser testados no gabinete real.
- A versão atual tem sete participantes selecionáveis e um chefe. Ampliar o elenco pede ampliar as tabelas de conteúdo e a interface, conforme o guia técnico.

Antes do evento, percorra com duas pessoas: seleção, troca de lados, ataque+poder, ataque+defesa, bloqueio baixo, Perfect Block, Guard Break, Super, KO, último round, revanche e retorno ao menu. Verifique o volume do gabinete, contraste, resolução e combinações simultâneas de teclas.

