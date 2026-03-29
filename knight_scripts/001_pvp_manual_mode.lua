--[[
  001_pvp_manual_mode.lua — Um clique: desliga TargetBot/CaveBot/AttackBot (vBot) e liga
  Auto Exori Strike, Auto Target e Auto Chase (knight_scripts).

  Carregar primeiro no perfil: só regista o botão; ao clicar resolve as macros globalmente.

  Depende de (macros ao clicar): 011_auto_exori_strike.lua, 012_auto_target.lua (`knightExoriStrikeMacro`,
  `knightAutoTargetMacro`, `knightAutoChaseMacro`). Se vBot não estiver carregado, os `setOff`
  são ignorados em segurança.
]]

local function safeCall(fn)
  if type(fn) ~= "function" then return end
  pcall(fn)
end

local function modoPvpManual()
  if type(TargetBot) == "table" and type(TargetBot.setOff) == "function" then
    safeCall(function() TargetBot.setOff() end)
  end
  if type(CaveBot) == "table" and type(CaveBot.setOff) == "function" then
    safeCall(function() CaveBot.setOff() end)
  end
  if type(AttackBot) == "table" and type(AttackBot.setOff) == "function" then
    safeCall(function() AttackBot.setOff() end)
  end

  if knightExoriStrikeMacro and knightExoriStrikeMacro.setOn then
    safeCall(function() knightExoriStrikeMacro:setOn() end)
  end
  if knightAutoTargetMacro and knightAutoTargetMacro.setOn then
    safeCall(function() knightAutoTargetMacro:setOn() end)
  end
  if knightAutoChaseMacro and knightAutoChaseMacro.setOn then
    safeCall(function() knightAutoChaseMacro:setOn() end)
  end
end

local btnPvpManual = addButton("btn_pvp_manual", "Modo PVP manual (bots off)", function()
  modoPvpManual()
  if knightFlashBtn then knightFlashBtn(btnPvpManual) end
end)
