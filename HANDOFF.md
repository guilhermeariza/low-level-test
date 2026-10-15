# HANDOFF.md — Contexto para continuar no Claude Code local

Cole no início da sessão local: "Leia HANDOFF.md, PLAN.md e CLAUDE.md e continue."

## Projeto
Clone do LoL em x86-64 NASM puro (Linux, sem libc, X11 cru + MIT-SHM). Branch: `claude/lol-game-assembly-4int6`.
Build: `make clean && make` · testes: `make test` (só math/entities/map/collision) · rodar: `./lol`.

## O que foi feito (commit f1fd0c4, já no remoto)
1. `src/x11.asm`: `QueryExtension` length 5→4 (envia 16 bytes) e `CreateWindow` length 12→10 (envia 40 bytes). Antes: `BadLength`, janela nunca criada, travava em `read()` bloqueante.
2. `src/ai.asm` `.move_to_lane`: offset da lane em `eax` era sobrescrito por `lea rax,[rel ent_team]` → usa `r8d` agora. Antes: SIGSEGV no 1º tick de bot.
3. `PLAN.md`: revisão completa e plano em fases A–E.

Resultado: menu → seleção (ENTER) → loading → partida a 60 FPS, sem crash em ~25 s (testado em Xvfb).

## Pendência na máquina do usuário (WSL) — NÃO está no repo
O usuário relatou um patch local, **sem commit**, em `src/x11.asm`: depois do `ShmAttach` espera a resposta do servidor e, se vier erro (BadAccess), cai no `PutImage` sem SHM. Motivo: numa 1ª execução o servidor recusou o ShmAttach e todos os frames falharam (pode ser intermitente; WSLg).
- Primeiro passo local: `git diff src/x11.asm`, revisar, commitar e dar push (ou me passar o diff).
- Ressalvas: forçar a resposta com `GetInputFocus` logo após o attach (o erro é assíncrono); testar o fallback de propósito (ex.: `shm_major_opcode=0`), pois nunca foi exercitado; o segmento é marcado `IPC_RMID` logo após `shmat`.
- Áudio: sem `/dev/snd` no WSL → jogo roda sem som (esperado).

## Fatos úteis do debug
- O jogo **ignora `$DISPLAY`** (socket fixo `/tmp/.X11-unix/X0` em `include/x11proto.inc`) e **não envia cookie Xauthority**. Em desktop com auth, sai sem mensagem. Workaround: `Xephyr :0 -ac -screen 1280x720 &` e `DISPLAY=:0 ./lol`.
- Debug com gdb: build com `NASMFLAGS = -f elf64 -O3 -g -F dwarf` e `LDFLAGS =` (sem `-s`).
- Teste automatizado: Xvfb `:0` + `xdotool key Return` (×2 passa menu e seleção; loading dura ~5 s) + `import -window <id>` para capturar.
- **Privacidade:** capturar só a janela do jogo (`xwd -id`/`import -window <id>`), nunca `-window root` (já pegou o navegador do usuário).
- Controles: ENTER avança menus, clique direito move, Q/W/E/R habilidades.

## Problemas conhecidos (observados)
- Fonte sem J O Q R U X Y Z (`render.asm` `char_map`): "LEAG E  F", "PLA", "IT".
- Mapa: só rio diagonal em chão verde; lanes/torres/inibidores/selva não visíveis.
- HUD com textos sobrepostos (HP/AD/AP/MR), "G LD", mana do jogador = 0 (habilidades provavelmente inúteis).
- Minions se espalham em vez de seguir as lanes.
- `network.asm` é código morto (ninguém chama `network_*`); áudio só abre `/dev/snd`.
- CLAUDE.md exagera ("AVX-512" é AVX2; % do roadmap).
- Provavelmente há mais bugs de clobber de registrador (15k linhas nunca executadas).

## Próximos passos sugeridos (ordem)
1. Trazer/commitar o patch SHM do WSL.
2. Fase B: `$DISPLAY` + Xauthority + checar `present` do QueryExtension + timeout em `x11_wait_map_notify`.
3. Fase A: `make smoke` (Xvfb + ENTER×2 + captura + falha se morrer) e `make debug`.
4. Fase C: fonte → mapa (lanes/torres) → HUD → mana/habilidades → waves nas lanes → vitória.
5. Fase D: testes de integração headless e por módulo.

Ver `PLAN.md` para o plano completo.
