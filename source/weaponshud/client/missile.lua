local missileNoHitUntil = 0
local missileSmokeNextAt = 0
local missileSmokeActive = false

local seeker = {
  type = "IR",          -- "IR" or "RADAR"
  decoyUntil = 0,       -- ms; if > now, missile flies dumb
  lastKnownPos = nil,   -- vector3
  burnOutAt = 0,        -- ms; motor burnout
  lockActive = true,
}

local function nowMs() return GetGameTimer() end

local function stealthMultipliers(veh)
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Stealth and Config.PvP.Stealth.Enabled) then
    return 1.0, 1.0
  end
  local entry = Config.PvP.Stealth.Models and Config.PvP.Stealth.Models[GetEntityModel(veh)]
  if entry then
    return (entry.rcs or 1.0), (entry.ir or 1.0)
  end
  return 1.0, 1.0
end

local function estimateHeat(veh)
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Heat and Config.PvP.Heat.Enabled) then
    return 1.0
  end

  local base = Config.PvP.Heat.Base or 0.35
  local w = Config.PvP.Heat.ThrottleWeight or 0.75
  local ab = Config.PvP.Heat.AfterburnerBonus or 0.2

  local rpm = 0.0
  pcall(function() rpm = GetVehicleCurrentRpm(veh) end)
  rpm = math.max(0.0, math.min(1.0, rpm))

  local vx, vy, vz = table.unpack(GetEntityVelocity(veh))
  local spd = math.sqrt(vx*vx + vy*vy + vz*vz)
  local afterburner = (rpm > 0.92 and spd > 80.0) and ab or 0.0

  local heat = base + (rpm * w) + afterburner
  return math.max(0.05, math.min(1.5, heat))
end

local function shouldDecoyIR(targetVeh)
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Flare and Config.PvP.Flare.Enabled) then
    return false
  end
  if not CM_FlareActive(targetVeh) then return false end

  local _, ir = stealthMultipliers(targetVeh)
  local heat = estimateHeat(targetVeh) * ir

  local baseChance = Config.PvP.Flare.DecoyBaseChance or 0.35
  local maxChance = Config.PvP.Flare.DecoyChanceMax or 0.85

  local chance = baseChance + (1.0 - math.min(1.0, heat)) * 0.55
  chance = math.max(0.05, math.min(maxChance, chance))

  return (math.random() < chance)
end

local function shouldDecoyRadar(targetVeh)
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Chaff and Config.PvP.Chaff.Enabled) then
    return false
  end
  if not CM_ChaffActive(targetVeh) then return false end

  local rcs, _ = stealthMultipliers(targetVeh)

  local baseChance = Config.PvP.Chaff.DecoyBaseChance or 0.25
  local maxChance = Config.PvP.Chaff.DecoyChanceMax or 0.70

  -- smaller rcs => higher chance to break when chaff is active
  local chance = baseChance + (1.0 - math.sqrt(math.max(0.05, rcs))) * 0.45
  chance = math.max(0.05, math.min(maxChance, chance))

  return (math.random() < chance)
end

local function cfgForType(t)
  if t == "RADAR" and Config.MissileRadar then return Config.MissileRadar end
  if t == "IR" and Config.MissileIR then return Config.MissileIR end
  return Config.Missile
end

local function applyEnergyBleed(curSpeed, turnAngle)
  local bleed = (turnAngle / 1.2) * 22.0
  return math.max(120.0, curSpeed - bleed)
end

local function stopMissileSmoke()
  if missileSmokeHandle ~= 0 then
    StopParticleFxLooped(missileSmokeHandle, true)
    missileSmokeHandle = 0
  end
end

function Missile_TryFire(jet, targetEnt, missileType)
  local ok, reason = Projectile_CanFire("missile")
  if not ok then return false, reason end
  if targetEnt == 0 or not DoesEntityExist(targetEnt) then return false, "no_target" end

  seeker.type = missileType or "IR"
  seeker.decoyUntil = 0
  seeker.lastKnownPos = nil
  seeker.lockActive = (seeker.type ~= "RADAR") or true

  local model = Config.Missile.PropModel
  if not Projectile_LoadModel(model) then return false, "model_fail" end

  local pos = GetOffsetFromEntityInWorldCoords(jet, 0.0, 7.5, -0.4)
  local obj = CreateObject(model, pos.x, pos.y, pos.z, true, false, true)
  if obj == 0 then return false, "spawn_fail" end

  SetEntityAsMissionEntity(obj, true, true)
  SetEntityCollision(obj, false, false)
  SetEntityNoCollisionEntity(obj, jet, true)

  missileNoHitUntil = nowMs() + 700

  Projectile_SetFired(obj, "missile", jet)
  Projectile.targetEnt = targetEnt

  local fwd = GetEntityForwardVector(jet)
  local cfg = cfgForType(seeker.type)
  Projectile.vel = vector3(fwd.x, fwd.y, fwd.z) * (cfg.Speed or 285.0)

  -- burnout time per seeker type
  local burn = 18.0
  if Config.PvP and Config.PvP.MotorBurn then
    burn = (seeker.type == "RADAR") and (Config.PvP.MotorBurn.RADAR or 20.0) or (Config.PvP.MotorBurn.IR or 18.0)
  end
  seeker.burnOutAt = nowMs() + math.floor(burn * 1000.0)

  if Projectile_LoadPtfx(Config.Missile.SmokePtfxAsset) then
    missileSmokeActive = true
    missileSmokeNextAt = 0
  else
    missileSmokeActive = false
  end

  local targetNetId = NetworkGetNetworkIdFromEntity(targetEnt)
  local id = ("%d:%d"):format(GetPlayerServerId(PlayerId()), nowMs())
  Projectile.netId = id
  Net_SendProjectileSpawn(id, "missile", model, targetNetId, pos, Projectile.vel, seeker.type)
  Net_SendLockState(targetNetId, seeker.type, "track")

  -- launch sound
  if Config.PvP and Config.PvP.Sounds and Config.PvP.Sounds.Enabled then
    local s = (seeker.type == "RADAR") and (Config.PvP.Sounds.Fox1 or "fox1") or (Config.PvP.Sounds.Fox2 or "fox2")
    Projectile_PlaySound(s, 1.0)
  else
    Projectile_PlaySound('missile', 1.0)
  end

  if Spectate_IsOn() then
    Spectate_Follow(obj)
  end

  return true, "fired"
end

function Missile_CancelLocal()
  stopMissileSmoke()
  Projectile_Clear()
end

function Missile_SetRadarLock(lockReady, targetEnt)
  if Projectile.kind ~= "missile" or seeker.type ~= "RADAR" then return end
  if targetEnt ~= Projectile.targetEnt then
    if lockReady then
      Projectile.targetEnt = targetEnt
    end
  end
  seeker.lockActive = lockReady and (targetEnt == Projectile.targetEnt)
end

function Missile_Update()
  if Projectile.kind ~= "missile" then return end
  local obj = Projectile_GetEntity()
  if obj == 0 then Projectile_Clear(); return end

  if nowMs() > missileNoHitUntil then
    SetEntityCollision(obj, true, true)
  end

  local cfg = cfgForType(seeker.type)

  local age = (nowMs() - Projectile.spawnedAt) / 1000.0
  if age > (cfg.MaxLifeSeconds or Config.Missile.MaxLifeSeconds) then
    Projectile_ExplodeAt(GetEntityCoords(obj))
    stopMissileSmoke()
    if Projectile.netId then
      Net_SendProjectileExplode(Projectile.netId, "missile", GetEntityCoords(obj), 0)
    end
    Projectile_Clear()
    return
  end

  local dt = GetFrameTime()
  if dt <= 0.0 then return end

  local p = GetEntityCoords(obj)

  local tgt = Projectile.targetEnt
  if seeker.type == "RADAR" and not seeker.lockActive then
    tgt = 0
  end
  local tp = nil
  local toT = nil
  local dist = nil
  if tgt ~= 0 and DoesEntityExist(tgt) then
    tp = GetEntityCoords(tgt)
    if seeker.type ~= "RADAR" or seeker.lockActive then
      seeker.lastKnownPos = tp
    end
    toT = tp - p
    dist = #(toT)
  elseif seeker.type ~= "RADAR" or seeker.lockActive then
    Projectile_ExplodeAt(p)
    if Projectile.netId then
      Net_SendProjectileExplode(Projectile.netId, "missile", p, 0)
    end
    stopMissileSmoke()
    Projectile_Clear()
    return
  end

  if dist and dist <= (cfg.ProximityFuse or Config.Missile.ProximityFuse) then
    Projectile_ExplodeAt(p)
    if Projectile.netId then
      local owner = NetworkGetEntityOwner(tgt)
      local hitServerId = owner and GetPlayerServerId(owner) or 0
      Net_SendProjectileExplode(Projectile.netId, "missile", p, hitServerId)
    end
    stopMissileSmoke()
    Projectile_Clear()
    return
  end

  -- decoy logic
  if nowMs() >= seeker.decoyUntil and (seeker.type ~= "RADAR" or seeker.lockActive) then
    if seeker.type == "IR" and shouldDecoyIR(tgt) then
      seeker.decoyUntil = nowMs() + math.floor((Config.PvP.Flare.LoseLockSeconds or 1.2) * 1000.0)
    elseif seeker.type == "RADAR" and shouldDecoyRadar(tgt) then
      seeker.decoyUntil = nowMs() + math.floor((Config.PvP.Chaff.LoseLockSeconds or 1.4) * 1000.0)
    end
  end

  local desiredDir
  if seeker.type == "RADAR" and not seeker.lockActive then
    desiredDir, _ = Math3D.norm(Projectile.vel)
  elseif seeker.decoyUntil > nowMs() then
    desiredDir, _ = Math3D.norm(seeker.lastKnownPos - p)
  else
    desiredDir, _ = Math3D.norm(toT)
  end

  local curDir, curSpeed = Math3D.norm(Projectile.vel)
  if curSpeed < 1.0 then curDir = desiredDir; curSpeed = (cfg.Speed or 285.0) end

  local newDir = Math3D.lerpDir(curDir, desiredDir, cfg.TurnRate or Config.Missile.TurnRate)

  local turnAng = Math3D.angleBetween(curDir, newDir)
  local spd = applyEnergyBleed(curSpeed, turnAng)

  if nowMs() >= seeker.burnOutAt then
    spd = math.max(110.0, spd * 0.80)
  else
    spd = math.min((cfg.Speed or 285.0), spd + 10.0 * dt)
  end

  Projectile.vel = newDir * spd
  local newPos = p + Projectile.vel * dt

  if missileSmokeActive and nowMs() >= missileSmokeNextAt then
    UseParticleFxAssetNextCall(Config.Missile.SmokePtfxAsset)
    StartParticleFxNonLoopedAtCoord(
      Config.Missile.SmokePtfxName,
      p.x, p.y, p.z,
      0.0, 0.0, 0.0,
      0.6,
      false, false, false
    )
    missileSmokeNextAt = nowMs() + 45
  end

  if nowMs() > missileNoHitUntil then
    local hit, hitPos = Projectile_SweepHitIgnore(Projectile.ownerEnt, p, newPos)
    if hit then
      Projectile_ExplodeAt(hitPos)
      if Projectile.netId then
        Net_SendProjectileExplode(Projectile.netId, "missile", hitPos, 0)
      end
      stopMissileSmoke()
      Projectile_Clear()
      return
    end
  end

  Projectile_Integrate(obj, newPos)
  SetEntityHeading(obj, GetHeadingFromVector_2d(newDir.x, newDir.y))

  Spectate_Update()
end
