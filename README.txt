scripts_pbotwars — pacote knight_scripts (OTClient / game_bot)

Scripts independentes extraidos de knight_scripts.lua

Ordenacao dos ficheiros (prefixo NNN_ = tres digitos, ordem estavel no bot):
  001_pvp_manual_mode.lua — primeiro (so UI; macros resolvidas ao clicar).
  002_storage_init.lua … 018_push_control.lua — nucleo.
  019_exiva.lua — penultimo.
  020_status_hud.lua — ultimo.

Padrao de qualidade:
- um arquivo por funcionalidade principal
- carregar `002_storage_init.lua` logo apos o 001 (`knightChatOpen`, `knightSupportGap`, `knightMsSinceSupportCast`,
  `knightAttackingCreature` / `knightAttackingPosition`, prioridade de suporte, `storage`)
- early return, nil-guard, cooldowns, estado em `storage`

Arquivos e objetivo:
- 001_pvp_manual_mode.lua — botao: desliga TargetBot/CaveBot/AttackBot (vBot) e liga Strike + Auto Target + Auto Chase.
- 002_storage_init.lua — `storage`, defaults, `KNIGHT_SUPPORT_CAST_GAP`, prioridade `KNIGHT_SUPPORT_PRIORITY_ORDER`, helpers.
- 003_damage_capture.lua — `lastAttackedMe`, `lastAttacked`.
- 004_auto_exori_gauge.lua — exori gauge.
- 005_auto_utamo_tempo.lua — utamo tempo.
- 006_auto_haste.lua — utani tempo hur.
- 007_exeta_res.lua — exeta res melee (PVE/PVP).
- 008_anti_paralyze.lua — anti paralyse.
- 009_anti_kick.lua — rotacao anti-kick.
- 010_combo_knight.lua — mas exori hur (turn + passo lateral).
- 011_auto_exori_strike.lua — exori strike melee.
- 012_auto_target.lua — PVP: lock alvo, auto chase (ataca + segue), recover.
- 013_follow.lua — PvE: auto follow (só seguir, sem atacar); vertical igual ao chase.
- 014_bugmap.lua — bug map por teclas.
- 015_id_cursor_map.lua — IDs sob cursor.
- 016_pull_items.lua — puxar itens ao redor.
- 017_anti_push.lua — anti-push moedas.
- 018_push_control.lua — push assistido.
- 019_exiva.lua — exiva + grelha (penultimo no pack ordenado).
- 020_status_hud.lua — painel de estado (ultimo).

Opcional: antes de `002_storage_init.lua` (ou no proprio 002) definir `KNIGHT_SUPPORT_CAST_GAP` (padrao 1500 ms) e/ou
  `KNIGHT_SUPPORT_PRIORITY_ORDER` — array de IDs (ver comentario no 002): ordem = prioridade para `lastSupportCastAt`.

Contrato `storage` (quando relevante):
- `lastAttackedMe`, `lastAttacked`
- `_target`, `_targetId`, `_targetEnabled`, `_chaseEnabled`
- `followLeader`, `_followEnabled`
- `pushVictimName`, `_pushActive`, `_pushDest`
- `lastExivaName`, `lastExivaMessage`, `lastExivaDist`, `exivaManualName`, `lastExivaTime`

Hotkeys padrao:
- 004_auto_exori_gauge.lua: `Shift+0`
- 005_auto_utamo_tempo.lua: `Shift+1`
- 006_auto_haste.lua: `Shift+2`
- 008_anti_paralyze.lua: `Shift+3`
- 009_anti_kick.lua: `Shift+4`
- 010_combo_knight.lua: `Shift+5`
- 007_exeta_res.lua: `Shift+6`
- 011_auto_exori_strike.lua: `Shift+7`
- 012_auto_target.lua: `Shift+Q`, `4`, `Shift+E`, `2`
- 013_follow.lua: `3`, `1`
- 019_exiva.lua: `5`, `Shift+R`
- 014_bugmap.lua: `Shift+T`
- 015_id_cursor_map.lua: `Shift+Y`
- 016_pull_items.lua: `Shift+F`
- 017_anti_push.lua: `Shift+G`
- 018_push_control.lua: `Shift+V`, `Shift+B`, `Shift+X`, `Shift+Z`
