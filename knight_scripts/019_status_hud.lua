-- [INICIO] 019_status_hud.lua
--
-- Objetivo: labels de estado vindos de `storage` (preenchido por 002, 011, 012, 018):
--   atacou-me, ataquei, alvo, follow, push e modo deduzido por prioridade.

-- Painel compacto: quem te bateu, alvo, follow, push e modo (idle/lock/chase/follow/push).
storage = storage or {}
if knightEnsureStorage then
  knightEnsureStorage({
    lastAttackedMe = "",
    lastAttacked = "",
    _target = "",
    followLeader = "",
    pushVictimName = "",
    _targetEnabled = false,
    _chaseEnabled = false,
    _followEnabled = false,
    _pushActive = false,
    _pushDest = nil,
  })
end

local trim = knightTrim

-- Widgets do HUD (1 linha por indicador).
local hud = {
  addLabel("k_h1", "Atacou-me: -"),
  addLabel("k_h2", "Ataquei: -"),
  addLabel("k_h3", "Alvo: -"),
  addLabel("k_h4", "Follow: -"),
  addLabel("k_h5", "Push: -"),
  addLabel("k_h6", "Mode: idle"),
}

local function setHud(i, text, color)
  pcall(function()
    -- Atualiza texto e cor de uma linha especifica.
    hud[i]:setText(text)
    hud[i]:setColor(color or "#aaaaaa")
  end)
end

-- Atualiza o painel periodicamente sem depender dos outros scripts em runtime.
macro(280, function()
  -- Snapshot do estado atual.
  local am = storage.lastAttackedMe or ""
  local la = storage.lastAttacked or ""
  local tgt = storage._target or ""
  local fl = storage.followLeader or ""
  local pv = trim(storage.pushVictimName or "")
  local targetOn = storage._targetEnabled == true
  local chaseOn = storage._chaseEnabled == true
  local fOn = storage._followEnabled == true and fl ~= ""
  local pushOn = storage._pushActive == true
  local pd = storage._pushDest

  -- Converte vazio para "-" para leitura limpa.
  local function v(s) return s ~= "" and s or "-" end
  setHud(1, "Atacou-me: " .. v(am), am ~= "" and "#ff6666" or "red")
  setHud(2, "Ataquei: " .. v(la), la ~= "" and "#66ff66" or "red")
  setHud(3, "Alvo: " .. (targetOn and v(tgt) or "-"), targetOn and "green" or "red")
  setHud(4, "Follow: " .. (fOn and fl or "-"), fOn and "green" or "red")
  -- Linha Push com destino detalhado quando disponivel.
  if pv ~= "" and pd and pd.x and pd.y then
    setHud(5, "Push: [" .. pv .. "] > " .. pd.x .. "," .. pd.y .. (pushOn and " [ON]" or ""), pushOn and "#88ff88" or "#ffaa00")
  else
    setHud(5, "Push: " .. (pv ~= "" and ("[" .. pv .. "]") or "-"), pv ~= "" and "#ffaa00" or "red")
  end
  -- Determina modo principal por prioridade operacional.
  local mode = "Mode: idle"
  if pushOn then mode = "Mode: push"
  elseif fOn then mode = "Mode: follow"
  elseif chaseOn and targetOn and tgt ~= "" then mode = "Mode: chase"
  elseif targetOn and tgt ~= "" then mode = "Mode: lock"
  end
  setHud(6, mode, "#aaaaaa")
end)

-- [FIM] 019_status_hud.lua
