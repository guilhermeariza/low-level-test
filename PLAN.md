# PLAN.md — Revisão do projeto e plano para funcionar de verdade

Revisão feita rodando o binário num Xvfb (`Xvfb :0 -screen 0 1280x720x24 +extension MIT-SHM`),
injetando input com `xdotool`, capturando tela com `import -window root` e depurando com gdb
(`-g -F dwarf` no NASM, sem `-s` no ld).

## Veredito
A arquitetura é sensata (SoA, loop fixo 60 FPS, X11 cru + MIT-SHM, módulos separados) e **tudo monta**.
Mas o jogo **nunca tinha sido executado de ponta a ponta**: os "33/33 testes" cobrem só 4 módulos
puros (math, entities, map, collision) e nenhum passa pelo X11, pelo loop ou pelo gameplay.
Antes desta revisão o binário **travava na inicialização** (janela nunca criada).

## Corrigido nesta sessão
1. `x11.asm` — `QueryExtension` com length 5 (correto: 4) e `CreateWindow` com length 12
   (correto: 10). O servidor devolvia `BadLength`; o `x11_wait_map_notify` ficava num `read()`
   bloqueante para sempre.
2. `ai.asm` (`.move_to_lane`) — `eax` (offset da lane) era sobrescrito por `lea rax,[rel ent_team]`
   → SIGSEGV no primeiro tick de bot.

Resultado: menu → seleção de campeão → loading → partida rodam a 60 FPS, 25+ s sem crash.

## Estado real, por área (observado, não só lido)
| Área | Estado |
|------|--------|
| X11/SHM/render/loop | Funciona após os fixes. Sem autenticação Xauthority e display fixo em `X0` (ignora `$DISPLAY`) → **não conecta na maioria dos desktops reais** |
| Menu / seleção | Funciona, mas a fonte não tem **J O Q R U X Y Z** (`LEAG E  F`, `PLA`, `IT`, `ASHE`/`ANNIE` ok) |
| Mapa | Só um rio diagonal, chão verde chapado e 1 base; **lanes/torres/inibidores/selva não são visíveis** |
| HUD | Textos sobrepostos (HP/AD/AP/MR colidem), "G LD", MANA 0, minimap cru, números soltos no canto |
| Gameplay | Bots/minions se movem; combate/habilidades/itens/level nunca validados por teste. Mana do jogador = 0 → habilidades provavelmente inutilizáveis |
| ai / audio | `ai` roda mas básica; `audio` abre `/dev/snd` e não toca nada (e não existe em container/maioria dos setups) |
| network | **Código morto**: nenhuma função `network_*` é chamada por ninguém |
| CLAUDE.md | Exagera: "AVX-512" (é AVX2), "69% do roadmap", "5 champions" etc. Não conferem com o que roda |

## Plano (ordem de execução)
### Fase A — Rede de segurança (1–2 dias)
- A1. Script `make run-xvfb` / `make smoke`: sobe Xvfb, roda o jogo, aperta ENTER×2, espera 10 s,
  captura PNG e falha se o processo morrer. Rodar no CI.
- A2. Build `make debug` (`-g -F dwarf`, sem `-s`) e documentar o uso de gdb.
- A3. Flag `-w+all` do NASM e zerar os warnings (ex.: `combat.asm:654` overflow de dword).

### Fase B — Fazer rodar em máquina real (1 dia)
- B1. Ler `$DISPLAY` (parse `:N`) e montar o path do socket dinamicamente.
- B2. Ler `~/.Xauthority` (ou `$XAUTHORITY`) e mandar o MIT-MAGIC-COOKIE-1 no setup;
  hoje o auth len é 0.
- B3. Ler a resposta do `QueryExtension` de verdade (checar `present`) e cair no PutImage
  normal se MIT-SHM faltar (o caminho existe, mas hoje o fallback é decidido só pelo shmget).
- B4. Tratar erros X11 (byte 0 == 0) no `x11_wait_map_notify` com timeout em vez de `read` infinito.

### Fase C — Tornar jogável o que já existe (maior valor)
- C1. Fonte: completar J, O, Q, R, U, X, Y, Z, minúsculas e pontuação (`char_map` em `render.asm`).
- C2. Mapa: desenhar lanes (cores), torres, inibidores, nexus, bushes e paredes da selva;
  hoje só se vê o rio. Conferir `map_render` vs `map_init`.
- C3. HUD: reposicionar stats (AD/AP/AR/MR) sem sobreposição; mostrar ouro, mana, cooldowns.
- C4. Stats do jogador: `entity_set_stats` está zerando mana → inicializar mana por campeão
  e validar Q/W/E/R (custo, cooldown, dano, projétil) com um teste headless por habilidade.
- C5. Minions: waves saindo das bases e andando pelos waypoints das lanes (hoje espalham-se
  pelo mapa); confirmar pathfinding A* usado de fato.
- C6. Condição de vitória: simular destruição do nexus e verificar a tela de vitória.

### Fase D — Testes de verdade
- D1. Testes de integração headless: chamar `game_init` + N× `game_update` sem X11 e
  asseverar invariantes (nenhuma entidade com hp<0 ativa, índices < MAX_ENTITIES, sem NaN em x/y).
- D2. Teste de cada módulo de sistema (combat, items, level, abilities, vision, jungle) com stubs,
  como já é feito para math/entities/map/collision.
- D3. Fuzz de input no smoke test (teclas/cliques aleatórios por 60 s).
- D4. Valgrind-like: rodar sob `gdb` com watchpoints/ASan-equivalente não existe; em vez disso,
  adicionar canários nas arrays SoA em build debug.

### Fase E — Só depois: roadmap "extra"
IA com habilidades/compra de itens, áudio (via PulseAudio/PipeWire ou ALSA com fallback mudo),
rede (UDP lockstep). Remover `network.asm` do build até haver chamador, para não dar falsa
impressão de funcionalidade.

## Riscos
- Bugs de clobber de registrador como o do `ai.asm` provavelmente existem em outros pontos
  (15k linhas nunca executadas); a Fase D é o que os encontra, não leitura.
- AVX2 exigido (`vpbroadcastd ymm`) → falha em CPU antiga; adicionar checagem via `cpuid`.
