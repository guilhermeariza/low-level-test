# CLAUDE.md — Contexto do Projeto

## O que e este projeto
Clone do League of Legends em x86-64 NASM assembly puro para Linux.
Zero dependencias externas — sem libc, sem libX11, apenas syscalls diretos.

**Binario**: ~49KB | **Linhas**: ~15.5k | **Testes**: 33/33 | **Modulos**: 25 .asm

## Build e teste
```bash
make clean && make     # build completo (NASM + ld)
make test              # 33 unit tests
./lol                  # roda o jogo (precisa de X11)
```

## Arquitetura

### Rendering
- X11 via raw Unix socket (sem libX11)
- MIT-SHM zero-copy framebuffer (1280x720, 32bpp BGRA)
- AVX-512 para render_clear (64 bytes/iteracao)
- Game loop fixo 60 FPS com clock_nanosleep

### Entity System
- Structure of Arrays (SoA), cache-aligned 64 bytes
- MAX_ENTITIES=512, 19 entity types
- Arrays: ent_x/y (double), ent_hp/max_hp/mana/atk/range/speed (dword), ent_type/team/state/active (byte)

### Convencoes de codigo
- PIC: usar `lea reg, [rel symbol]` para acessar BSS/data, depois `[reg + idx*scale]`
- Chamadas: SysV AMD64 (rdi, rsi, rdx, rcx, r8, r9, xmm0-7)
- Callee-saved: rbx, r12-r15, rbp (push/pop ao redor)
- Doubles em xmm0/xmm1 para posicoes (vcvtsi2sd para converter int→double)
- entity_spawn retorna indice em eax (-1 se cheio)
- entity_set_stats: edi=idx, esi=hp, edx=mana, ecx=ad, r8d=range, r9d=speed, [rsp+8]=atk_speed

## Mapa de modulos (src/)

### Core (sempre carregados)
| Arquivo | Linhas | Funcao principal |
|---------|--------|------------------|
| main.asm | 248 | Entry point, game loop, state machine |
| game.asm | 1735 | **MAIOR** — input, camera, waves, combat, respawn, win condition |
| entities.asm | 280 | SoA arrays, spawn/kill/deactivate |
| map.asm | 483 | Mapa 280x280 tiles, render, waypoints |
| render.asm | 734 | clear, rect, circle, line, string, number, flush |
| input.asm | 233 | X11 events, mouse/keyboard state |
| x11.asm | 682 | X11 connection, window, MIT-SHM |

### Sistemas de jogo
| Arquivo | Linhas | O que faz |
|---------|--------|-----------|
| combat.asm | 878 | 3 damage types, armor/MR, pen, crit, shields, bounties, tower aggro |
| abilities.asm | 795 | QWER framework, 5 champions, projectiles, AoE, buffs |
| items.asm | 552 | 104 itens, shop, inventory 6-slot, sell, stat recalc |
| vision.asm | 732 | Fog of war, wards, sweeper, bush blocking |
| pathfinding.asm | 559 | A* com 8 direcoes, collision map |
| jungle.asm | 489 | 14 camps, dragon, baron, herald, respawn timers |
| summ_spells.asm | 378 | 10 summoner spells (Flash, Ignite, etc.) |
| level.asm | 204 | XP table 1-18, stat scaling, passive gold |

### UI e HUD
| Arquivo | Linhas | O que faz |
|---------|--------|-----------|
| hud.asm | 740 | HP bars, minimap, KDA, CS, death screen, FPS |
| ui.asm | 633 | Scoreboard, kill feed, ability bar, inventory display |
| effects.asm | 549 | Particulas, floating damage numbers |
| menu.asm | 589 | Main menu, champion select, victory/defeat |
| data.asm | 97 | Strings, radius/color tables (19 types) |

### Frameworks (scaffolding, precisam expansao)
| Arquivo | Linhas | Status |
|---------|--------|--------|
| ai.asm | 674 | Bot AI basico — falta ability usage real, item purchase |
| audio.asm | 220 | ALSA framework — falta SFX/musica real |
| network.asm | 460 | UDP sockets — falta sync de estado, prediction, lobby |

### Includes (include/)
| Arquivo | Linhas | Conteudo |
|---------|--------|----------|
| constants.inc | 710 | **TODAS** as constantes (entity types, stats, colors, sizes, game states) |
| syscalls.inc | 104 | Syscall numbers + macros SYSCALL0-6 |
| x11proto.inc | 107 | Constantes protocolo X11 |
| macros.inc | 116 | SIMD helpers, alignment macros |

## Estado do roadmap (152 tarefas)
- **Fases 1-7 (core gameplay)**: 77/77 = 100%
- **Fases 8-13 (polish/extras)**: ~28/75 = 37%
- **Total**: ~105/152 = 69%

### Principais gaps restantes
1. **Networking real** — tem socket UDP mas falta sync de estado, prediction, lobby
2. **Audio real** — tem framework ALSA mas falta gerar/tocar sons
3. **AI avancada** — bots nao usam abilities nem compram itens
4. **Sprites** — tudo e circulos/retangulos, sem sprites reais
5. **UI completa** — falta ping wheel, death recap, buff icons, chat

## Branch
- Desenvolvimento: `claude/lol-game-assembly-4int6`
- PR aberto: #2 (para main)

## Dicas para editar
- Testar assembly individual: `nasm -f elf64 -O3 -Iinclude/ -o /dev/null src/FILE.asm`
- game.asm e o maior (1735 linhas) — ler por secoes, nao inteiro
- constants.inc tem 710 linhas — buscar com grep ao inves de ler tudo
- Novos globals em BSS precisam de `global nome` antes da label
- Novo modulo: adicionar ao SOURCES no Makefile
