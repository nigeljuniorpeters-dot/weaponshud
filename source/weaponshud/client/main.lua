local armed = false

local modes = { "A-A", "A-G", "GUN" }
local modeIdx = 1

local weapons = {
  ["A-A"] = { "IR", "RADAR", "CM-FLARE", "CM-CHAFF" },
  ["A-G"] = { "DUMB", "GUIDED" },
  ["GUN"] = { "LEAD" },
}
local weaponIdx = { ["A-A"]=1, ["A-G"]=1, ["GUN"]=1 }

local lockToneNextAt = 0
local missileToneNextAt = 0

local radarLockStartAt = 0
local radarLockedTarget = 0
local radarLockProgress = 0.0
local radarLockReady = false

local function isAllowedAircraft(veh)
  if veh == 0 then return false end
  local entry = Config.AllowedModels[GetEntityModel(veh)]
  return entry ~= nil and entry ~= false
end

local function getPilotJet()
  local ped = PlayerPedId()
  local jet = GetVehiclePedIsIn(ped, false)
  if jet == 0 then return 0 end
  if GetPedInVehicleSeat(jet, -1) ~= ped then return 0 end
  if not isAllowedAircraft(jet) then return 0 end
  return jet
end

RegisterCommand(Config.CommandHud, function()
  armed = not armed
  Hud_SetEnabled(armed)
end)

local function cycleMode(dir)
  modeIdx = modeIdx + dir
  if modeIdx < 1 then modeIdx = #modes end
  if modeIdx > #modes then modeIdx = 1 end
end

local function cycleWeapon(dir)
  local m = modes[modeIdx]
  local list = weapons[m]
  weaponIdx[m] = weaponIdx[m] + dir
  if weaponIdx[m] < 1 then weaponIdx[m] = #list end
  if weaponIdx[m] > #list then weaponIdx[m] = 1 end
end

local function playLockTone()
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Sounds and Config.PvP.Sounds.Enabled) then return end
  local name = Config.PvP.Sounds.LockTone
  if not name or name == "" then return end
  local now = GetGameTimer()
  if now < lockToneNextAt then return end
  lockToneNextAt = now + 650
  Projectile_PlaySound(name, 0.7)
end

local function playMissileTone()
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Sounds and Config.PvP.Sounds.Enabled) then return end
  local name = Config.PvP.Sounds.MissileTone
  if not name or name == "" then return end
  local now = GetGameTimer()
  if now < missileToneNextAt then return end
  missileToneNextAt = now + 1200
  Projectile_PlaySound(name, 0.7)
end

CreateThread(function()
  local hudVisible = false

  while true do
    Wait(0)

    local jet = getPilotJet()
    local m = modes[modeIdx]
    local wpn = weapons[m][weaponIdx[m]]

    local kb = Input_Consume()

    if armed then
      if kb.modeNext then cycleMode(1) end
      if kb.modePrev then cycleMode(-1) end
      if kb.wpnNext then cycleWeapon(1) end
      if kb.wpnPrev then cycleWeapon(-1) end
    end

    local aaTarget = 0
    local agTarget = 0
    local box = nil

    local coneMode = nil
    local coneRadius = 0.0

    radarLockProgress = 0.0
    radarLockReady = false

    if armed and jet ~= 0 then
      if m == "A-A" then
        if wpn == "RADAR" then
          coneMode = "RADAR"
          coneRadius = (Config.PvP and Config.PvP.Cones and Config.PvP.Cones.RADAR) or 0.30

          aaTarget = Targeting.AcquireRadarTarget(jet)
          box = Targeting.ScreenPointForEntity(aaTarget)

          if aaTarget ~= 0 then
            playLockTone()
            if radarLockedTarget ~= aaTarget then
              radarLockedTarget = aaTarget
              radarLockStartAt = GetGameTimer()
            end
          else
            radarLockedTarget = 0
            radarLockStartAt = 0
          end

          if radarLockedTarget ~= 0 and radarLockStartAt ~= 0 then
            local need = (Config.PvP and Config.PvP.Radar and Config.PvP.Radar.LockTimeSeconds or 1.5) * 1000.0
            radarLockProgress = math.min(1.0, (GetGameTimer() - radarLockStartAt) / need)
            radarLockReady = radarLockProgress >= 1.0
          end

          if kb.firePressed and radarLockReady and aaTarget ~= 0 then
            Missile_TryFire(jet, aaTarget, "RADAR")
          end

          if radarLockReady ~= lastRadarLockReady or aaTarget ~= lastRadarTarget then
            if radarLockReady and aaTarget ~= 0 then
              Net_SendLockState(NetworkGetNetworkIdFromEntity(aaTarget), "RADAR", "lock")
            else
              if lastRadarTarget ~= 0 then
                Net_SendLockState(NetworkGetNetworkIdFromEntity(lastRadarTarget), "RADAR", "lost")
              end
            end
            lastRadarLockReady = radarLockReady
            lastRadarTarget = aaTarget
          end

          Missile_SetRadarLock(radarLockReady, aaTarget)

        elseif wpn == "IR" then
          coneMode = "IR"
          coneRadius = (Config.PvP and Config.PvP.Cones and Config.PvP.Cones.IR) or 0.42

          aaTarget = Targeting.AcquireAATarget(jet)
          box = Targeting.ScreenPointForEntity(aaTarget)
          if aaTarget ~= 0 then playLockTone() end

          if kb.firePressed and aaTarget ~= 0 then
            Missile_TryFire(jet, aaTarget, "IR")
          end

          if aaTarget ~= lastIrTarget then
            if aaTarget ~= 0 then
              Net_SendLockState(NetworkGetNetworkIdFromEntity(aaTarget), "IR", "lock")
            else
              if lastIrTarget ~= 0 then
                Net_SendLockState(NetworkGetNetworkIdFromEntity(lastIrTarget), "IR", "lost")
              end
            end
            lastIrTarget = aaTarget
          end

        elseif wpn == "CM-FLARE" then
          if kb.firePressed then CM_DeployFlare(jet) end
        elseif wpn == "CM-CHAFF" then
          if kb.firePressed then CM_DeployChaff(jet) end
        end

      elseif m == "A-G" then
        agTarget = Targeting.AcquireAGTarget(jet)
        box = Targeting.ScreenPointForEntity(agTarget)

        if kb.firePressed then
          if wpn == "DUMB" then
            Bomb_TryDropDumb(jet)
          elseif wpn == "GUIDED" then
            if agTarget ~= 0 then Bomb_TryDropGuided(jet, agTarget) end
          end
        end

      elseif m == "GUN" then
        aaTarget = Targeting.AcquireAGTarget(jet)
        box = Targeting.ScreenPointForEntity(aaTarget)
      end

      if m ~= "A-A" or wpn ~= "RADAR" then
        Missile_SetRadarLock(false, 0)
      end

      if kb.camPressed then
        Spectate_Toggle(Projectile_GetEntity())
      end
    else
      if kb.camPressed then
        Spectate_Toggle(Projectile_GetEntity())
      end
      radarLockedTarget = 0
      radarLockStartAt = 0
      if lastRadarTarget ~= 0 then
        Net_SendLockState(NetworkGetNetworkIdFromEntity(lastRadarTarget), "RADAR", "lost")
        lastRadarTarget = 0
        lastRadarLockReady = false
      end
      if lastIrTarget ~= 0 then
        Net_SendLockState(NetworkGetNetworkIdFromEntity(lastIrTarget), "IR", "lost")
        lastIrTarget = 0
      end
    end

    Missile_Update()
    Bomb_Update()
    Spectate_Update()

    -- inbound tone (local-only; reliable in PvP needs sync)
    if Config.PvP and Config.PvP.Enabled and Config.PvP.Sounds and Config.PvP.Sounds.Enabled then
      local ped = PlayerPedId()
      local myVeh = GetVehiclePedIsIn(ped, false)
      if myVeh ~= 0 and Projectile.kind == "missile" and Projectile.targetEnt == myVeh then
        playMissileTone()
      end
    end

    local lead = nil
    local showFunnel = false
    if armed and jet ~= 0 and m == "GUN" and Config.GunHud and Config.GunHud.Enabled and aaTarget ~= 0 and DoesEntityExist(aaTarget) then
      showFunnel = true
      local shooterPos = GetEntityCoords(jet)
      local svx, svy, svz = table.unpack(GetEntityVelocity(jet))
      local tpos = GetEntityCoords(aaTarget)
      local tvx, tvy, tvz = table.unpack(GetEntityVelocity(aaTarget))
      local aimPoint = Math3D.leadPoint(shooterPos, vector3(svx,svy,svz), tpos, vector3(tvx,tvy,tvz), Config.GunHud.BulletSpeed)
      local ok2, lx, ly = GetScreenCoordFromWorldCoord(aimPoint.x, aimPoint.y, aimPoint.z)
      if ok2 then lead = { x = lx, y = ly } end
    end

    local impact = nil
    if armed and jet ~= 0 and m == "A-G" and wpn == "DUMB" then
      local pt = Bomb_GetDumbImpact()
      if pt then
        local ok, ix, iy = GetScreenCoordFromWorldCoord(pt.x, pt.y, pt.z)
        if ok then impact = { x = ix, y = iy } end
      end
    end

    local bombTarget = nil
    if armed and jet ~= 0 and m == "A-G" and wpn == "DUMB" then
      local pt = Bomb_GetPredictedImpact(jet)
      if pt then
        local ok, ix, iy = GetScreenCoordFromWorldCoord(pt.x, pt.y, pt.z)
        if ok then
          bombTarget = {
            x = ix,
            y = iy,
            rot = GetEntityHeading(jet) or 0.0,
          }
        end
      end
    end

    local rng = 0.0
    if armed and jet ~= 0 then
      local t = (m == "A-G") and agTarget or aaTarget
      if t ~= 0 and DoesEntityExist(t) then
        rng = #(GetEntityCoords(t) - GetEntityCoords(jet))
      end
    end

    local shouldShowHud = armed and not IsPauseMenuActive() and not Spectate_IsOn()
    if shouldShowHud ~= hudVisible then
      Hud_SetEnabled(shouldShowHud)
      hudVisible = shouldShowHud
    end

    if shouldShowHud then
      Hud_Update({
        armed = true,
        mode = m,
        weapon = wpn,
        range = rng,
        targetBox = box,
        lead = lead,
        showFunnel = showFunnel,
        impact = impact,
        bombTarget = bombTarget,
        projectileActive = (Projectile_GetEntity() ~= 0),
        projectileKind = Projectile.kind,

        coneMode = coneMode,
        coneRadius = coneRadius,
        lockProgress = radarLockProgress,
        lockReady = radarLockReady,
      })
    end
  end
end)
