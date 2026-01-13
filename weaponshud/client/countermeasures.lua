Countermeasures = {
  lastFlareAt = {},     -- [veh] = ms
  lastChaffAt = {},     -- [veh] = ms
  lastFlareUse = 0,
  lastChaffUse = 0,

  flarePressed = false,
  chaffPressed = false,
}

local flareSpeed = -4.0
local flareSound = "flares_released"
local flareSoundEmpty = "flares_empty"
local flareSoundDict = "DLC_SM_Countermeasures_Sounds"
local flareHash = GetHashKey("weapon_flaregun")

local function nowMs() return GetGameTimer() end

local function activeSince(map, veh, seconds)
  local t = map[veh] or 0
  if t == 0 then return false end
  return (nowMs() - t) <= (seconds * 1000.0)
end

function CM_RegisterKeybind()
  if not Config.PvP or not Config.PvP.Enabled then return end

  if Config.PvP.Flare and Config.PvP.Flare.Enabled and Config.PvP.Flare.Keybind then
    local kb = Config.PvP.Flare.Keybind
    RegisterCommand(kb.cmd, function() Countermeasures.flarePressed = true end, false)
    RegisterCommand(kb.cmd:gsub("^%+","-"), function() end, false)
    RegisterKeyMapping(kb.cmd, kb.desc, "keyboard", kb.default)
  end

  if Config.PvP.Chaff and Config.PvP.Chaff.Enabled and Config.PvP.Chaff.Keybind then
    local kb = Config.PvP.Chaff.Keybind
    RegisterCommand(kb.cmd, function() Countermeasures.chaffPressed = true end, false)
    RegisterCommand(kb.cmd:gsub("^%+","-"), function() end, false)
    RegisterKeyMapping(kb.cmd, kb.desc, "keyboard", kb.default)
  end
end

function CM_Consume()
  local f = Countermeasures.flarePressed
  local c = Countermeasures.chaffPressed
  Countermeasures.flarePressed = false
  Countermeasures.chaffPressed = false
  return f, c
end

function CM_CanFlare()
  if not (Config.PvP and Config.PvP.Flare and Config.PvP.Flare.Enabled) then return false end
  local cd = (Config.PvP.Flare.CooldownSeconds or 3.0) * 1000.0
  return (nowMs() - Countermeasures.lastFlareUse) >= cd
end

function CM_CanChaff()
  if not (Config.PvP and Config.PvP.Chaff and Config.PvP.Chaff.Enabled) then return false end
  local cd = (Config.PvP.Chaff.CooldownSeconds or 12.0) * 1000.0
  return (nowMs() - Countermeasures.lastChaffUse) >= cd
end

function CM_DeployFlare(veh)
  if veh == 0 or not DoesEntityExist(veh) then return false end
  if not CM_CanFlare() then return false end

  Countermeasures.lastFlareUse = nowMs()
  Countermeasures.lastFlareAt[veh] = nowMs()

  RequestScriptAudioBank(flareSoundDict)
  RequestModel(flareHash)
  RequestWeaponAsset(flareHash, 31, 26)
  while not HasWeaponAssetLoaded(flareHash) do
    Wait(0)
  end

  local pos = GetEntityCoords(veh)
  local offsets = {
    GetOffsetFromEntityInWorldCoords(veh, -6.0, -4.0, -0.2),
    GetOffsetFromEntityInWorldCoords(veh, -3.0, -4.0, -0.2),
    GetOffsetFromEntityInWorldCoords(veh, 6.0, -4.0, -0.2),
    GetOffsetFromEntityInWorldCoords(veh, 3.0, -4.0, -0.2),
  }

  PlaySoundFromEntity(-1, flareSound, veh, flareSoundDict, true)
  for _, off in ipairs(offsets) do
    ShootSingleBulletBetweenCoordsWithExtraParams(
      pos,
      off,
      0,
      true,
      flareHash,
      PlayerPedId(),
      true,
      true,
      flareSpeed,
      veh,
      false,
      false,
      false,
      true,
      true,
      false
    )
  end

  return true
end

function CM_DeployChaff(veh)
  if veh == 0 or not DoesEntityExist(veh) then return false end
  if not CM_CanChaff() then return false end

  Countermeasures.lastChaffUse = nowMs()
  Countermeasures.lastChaffAt[veh] = nowMs()

  local p = GetEntityCoords(veh)
  UseParticleFxAssetNextCall("core")
  StartParticleFxNonLoopedAtCoord("exp_grd_grenade_smoke", p.x, p.y, p.z, 0.0,0.0,0.0, 0.25, false,false,false)

  return true
end

function CM_FlareActive(veh)
  if not (Config.PvP and Config.PvP.Flare and Config.PvP.Flare.Enabled) then return false end
  return activeSince(Countermeasures.lastFlareAt, veh, (Config.PvP.Flare.EffectSeconds or 3.0))
end

function CM_ChaffActive(veh)
  if not (Config.PvP and Config.PvP.Chaff and Config.PvP.Chaff.Enabled) then return false end
  return activeSince(Countermeasures.lastChaffAt, veh, (Config.PvP.Chaff.EffectSeconds or 4.0))
end
