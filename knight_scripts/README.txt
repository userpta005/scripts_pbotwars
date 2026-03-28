Scripts independentes extraidos de knight_scripts.lua

Ordenacao dos ficheiros (prefixo NNN_ = tres digitos, ordem estavel no bot):
  001_storage_init.lua  … 019_status_hud.lua

Padrao de qualidade:
- um arquivo por funcionalidade principal
- carregar `001_storage_init.lua` primeiro (`knightChatOpen`, `knightSupportGap`, `knightMsSinceSupportCast`,
  `knightAttackingCreature` / `knightAttackingPosition`, prioridade de suporte, `storage`)
- early return, nil-guard, cooldowns, estado em `storage`

Arquivos e objetivo:
- 001_storage_init.lua — `storage`, defaults, `KNIGHT_SUPPORT_CAST_GAP`, prioridade `KNIGHT_SUPPORT_PRIORITY_ORDER`, helpers. Antes de `002_`.
- 002_damage_capture.lua — `lastAttackedMe`, `lastAttacked`.
- 003_auto_exori_gauge.lua — exori gauge.
- 004_auto_utamo_tempo.lua — utamo tempo.
- 005_auto_haste.lua — utani tempo hur.
- 006_exeta_res.lua — exeta res melee (PVE/PVP).
- 007_anti_paralyze.lua — anti paralyse.
- 008_anti_kick.lua — rotacao anti-kick.
- 009_combo_knight.lua — mas exori hur (turn + passo lateral).
- 010_auto_exori_strike.lua — exori strike melee.
- 011_auto_target.lua — lock alvo, chase, recover.
- 012_follow.lua — follow PVP / floors.
- 013_exiva.lua — exiva + HUD.
- 014_bugmap.lua — bug map por teclas.
- 015_id_cursor_map.lua — IDs sob cursor.
- 016_pull_items.lua — puxar itens ao redor.
- 017_anti_push.lua — anti-push moedas.
- 018_push_control.lua — push assistido.
- 019_status_hud.lua — painel de estado.

Opcional: antes de `001_storage_init.lua` definir `KNIGHT_SUPPORT_CAST_GAP` (padrao 1500 ms) e/ou
  `KNIGHT_SUPPORT_PRIORITY_ORDER` — array de IDs (ver comentario no 001): ordem = prioridade para `lastSupportCastAt`.

Contrato `storage` (quando relevante):
- `lastAttackedMe`, `lastAttacked`
- `_target`, `_targetId`, `_targetEnabled`, `_chaseEnabled`
- `followLeader`, `_followEnabled`
- `pushVictimName`, `_pushActive`, `_pushDest`
- `lastExivaName`, `lastExivaMessage`, `lastExivaDist`, `exivaManualName`, `lastExivaTime`

Hotkeys padrao:
- 003_auto_exori_gauge.lua: `Shift+0`
- 004_auto_utamo_tempo.lua: `Shift+1`
- 005_auto_haste.lua: `Shift+2`
- 007_anti_paralyze.lua: `Shift+3`
- 008_anti_kick.lua: `Shift+4`
- 009_combo_knight.lua: `Shift+5`
- 006_exeta_res.lua: `Shift+6`
- 010_auto_exori_strike.lua: `Shift+7`
- 011_auto_target.lua: `Shift+Q`, `4`, `Shift+E`, `2`
- 012_follow.lua: `3`, `1`
- 013_exiva.lua: `5`, `Shift+R`
- 014_bugmap.lua: `Shift+T`
- 015_id_cursor_map.lua: `Shift+Y`
- 016_pull_items.lua: `Shift+F`
- 017_anti_push.lua: `Shift+G`
- 018_push_control.lua: `Shift+V`, `Shift+B`, `Shift+X`, `Shift+Z`
