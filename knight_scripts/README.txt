Scripts independentes extraidos de knight_scripts.lua

Padrao de qualidade adotado:
- um arquivo por funcionalidade principal
- sem dependencia obrigatoria entre arquivos
- early return para reduzir custo por tick
- nil-guard em acessos de tile/creature/item
- cooldown/throttle em casts e autowalk para evitar spam e exhausted
- estado explicito em `storage` para HUD e interoperabilidade segura

Arquivos e objetivo:
- 00a_storage_init.lua: inicializa defaults compartilhados em `storage`.
- 00_damage_capture.lua: captura de combate unificada (`lastAttackedMe` e `lastAttacked`).
- 02_auto_exori_gauge.lua: macro de exori gauge.
- 02b_auto_utamo_tempo.lua: macro de utamo tempo com cheque de mana/shield.
- 03_auto_haste.lua: haste com controle de intervalo para evitar spam.
- 04_exeta_res.lua: exeta res somente em distancia valida e mana adequada.
- 05_anti_paralyze.lua: anti paralyze com cooldown anti-flood.
- 06_anti_kick.lua: rotacao ciclica continua.
- 07_combo_knight.lua: combo de strikes + alinhamento para mas exori hur.
- 08_auto_target.lua: lock de alvo + clear + recover + chase.
- 12_follow.lua: follow por lider atacado + troca de floor + clear follow.
- 13_exiva.lua: exiva manual/ultimo alvo + parser de direcao/distancia + HUD exiva.
- 14_bugmap.lua: uso de tiles em direcao de teclado (bug map).
- 15_id_cursor_map.lua: identifica creature/item sob cursor no mapa.
- 16_pull_items.lua: puxa itens pickupaveis ao redor.
- 17_anti_push.lua: anti-push com moedas (gold/plat/crystal).
- 18_push_control.lua: definir destino, marcar vitima, iniciar/parar sequencia de push.
- 19_status_hud.lua: HUD de estado (ataque, alvo, follow, push, modo).

Contrato de storage compartilhado (somente quando relevante):
- `lastAttackedMe`, `lastAttacked`
- `_target`, `_targetId`, `_targetEnabled`, `_chaseEnabled`
- `followLeader`, `_followEnabled`
- `pushVictimName`, `_pushActive`, `_pushDest`
- `lastExivaName`, `lastExivaMessage`, `lastExivaDist`, `exivaManualName`, `lastExivaTime`

Hotkeys padrao:
- 02_auto_exori_gauge.lua: `Shift+0`
- 02b_auto_utamo_tempo.lua: `Shift+1`
- 03_auto_haste.lua: `Shift+2`
- 05_anti_paralyze.lua: `Shift+3`
- 06_anti_kick.lua: `Shift+4`
- 07_combo_knight.lua: `Shift+5`
- 08_auto_target.lua: `Shift+Q` (toggle), `4` (clear), `Shift+E` (recover), `2` (auto chase)
- 12_follow.lua: `3` (toggle follow), `1` (clear follow)
- 13_exiva.lua: `5` (exiva nome), `Shift+R` (exiva last)
- 14_bugmap.lua: `Shift+T`
- 15_id_cursor_map.lua: `Shift+Y`
- 16_pull_items.lua: `Shift+F`
- 17_anti_push.lua: `Shift+G`
- 18_push_control.lua: `Shift+V` (destino), `Shift+B` (marcar), `Shift+X` (iniciar), `Shift+Z` (parar)
