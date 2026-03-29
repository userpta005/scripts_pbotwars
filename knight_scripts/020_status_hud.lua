--[[
  020_status_hud.lua — Painel de estado (storage alimentado por 003, 012, 013, push scripts, etc.).

  Linhas: último que te atacou, último alvo atacado, lock/chase, follow, push, modo derivado
  por prioridade (push > follow > chase > lock > idle).

  No pack ordenado: último script (depois de `019_exiva.lua`).
  Depende de: 002_storage_init.lua (`knightEnsureStorage`, `knightTrim`).
]]

storage = (type(storage) == "table" and storage) or {}
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
local DIM = "#888888"
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
    hud[i]:setText(text)
    hud[i]:setColor(color or DIM)
  end)
end

macro(280, function()
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

  local function v(s) return s ~= "" and s or "-" end

  setHud(1, "Atacou-me: " .. v(am), am ~= "" and "#ff6666" or DIM)
  setHud(2, "Ataquei: " .. v(la), la ~= "" and "#66ff66" or DIM)
  setHud(3, "Alvo: " .. (targetOn and v(tgt) or "-"), targetOn and "#66ff66" or DIM)
  setHud(4, "Follow: " .. (fOn and fl or "-"), fOn and "#66ccff" or DIM)

  if pv ~= "" and pd and type(pd.x) == "number" and type(pd.y) == "number" then
    setHud(5, "Push: [" .. pv .. "] > " .. pd.x .. "," .. pd.y .. (pushOn and " [ON]" or ""),
        pushOn and "#88ff88" or "#ffaa00")
  else
    setHud(5, "Push: " .. (pv ~= "" and ("[" .. pv .. "]") or "-"), pv ~= "" and "#ffaa00" or DIM)
  end

  local mode, mc = "Mode: idle", DIM
  if pushOn then mode, mc = "Mode: push", "#ffaa00"
  elseif fOn then mode, mc = "Mode: follow", "#66ccff"
  elseif chaseOn and targetOn and tgt ~= "" then mode, mc = "Mode: chase", "#88ff88"
  elseif targetOn and tgt ~= "" then mode, mc = "Mode: lock", "#66ff66"
  end
  setHud(6, mode, mc)
end)
