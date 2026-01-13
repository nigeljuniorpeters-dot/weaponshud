local bombArmedAt = 0
local guidedEngageAt = 0
local noHitUntil = 0

local dumbImpact = nil

local function groundAt(pos)
  local ok, gZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 500.0, 0)
  if ok then return gZ end
  return nil
end

local function lerp(a, b, t)
  return (((b - a) / (1.0 - 0.0)) * (t - 0.0)) + a
end

local function lerpVec(a, b, t)
  return vector3(
    lerp(a.x, b.x, t),
    lerp(a.y, b.y, t),
    lerp(a.z, b.z, t)
  )
end

local bombDropOffsets = {
  [`cuban800`] = 0.5,
  [`mogul`] = 0.45,
  [`rogue`] = 0.46,
  [`starling`] = 0.55,
  [`seabreeze`] = 0.5,
  [`tula`] = 0.6,
  [`bombushka`] = 0.43,
  [`hunter`] = 0.5,
  [`avenger`] = 0.36,
  [`akula`] = 0.4,
  [`volatol`] = 0.54,
}

local function bombDropOffset(veh)
  return bombDropOffsets[GetEntityModel(veh)] or 0.5
end

local function getBombDropPoints(veh)
  local minDim, maxDim = GetModelDimensions(GetEntityModel(veh))
  local v0 = GetOffsetFromEntityInWorldCoords(veh, minDim.x, maxDim.y, minDim.z)
  local v1 = GetOffsetFromEntityInWorldCoords(veh, maxDim.x, maxDim.y, minDim.z)
  local v2 = GetOffsetFromEntityInWorldCoords(veh, minDim.x, minDim.y, minDim.z)
  local v3 = GetOffsetFromEntityInWorldCoords(veh, maxDim.x, maxDim.y, minDim.z)

  local midFront = lerpVec(v0, v1, 0.5)
  local midRear = lerpVec(v2, v3, 0.5)

  midFront = midFront + vector3(0.0, 0.0, 0.4)
  midRear = midRear + vector3(0.0, 0.0, 0.4)

  local factor = bombDropOffset(veh)
  local pos = lerpVec(midFront, midRear, factor)

  midFront = midFront - vector3(0.0, 0.0, 0.2)
  midRear = midRear - vector3(0.0, 0.0, 0.2)

  local offset = lerpVec(midFront, midRear, math.max(0.0, factor - 0.0001))
  return pos, offset
end

local function predictImpact(startPos, vel)
  -- quick ballistic estimate (for HUD marker only)
  local g = -9.81
  local gz = groundAt(vector3(startPos.x, startPos.y, startPos.z))
  if not gz then return nil end

  local a = 0.5 * g
  local b = vel.z
  local c = (startPos.z - gz)

  local disc = b*b - 4*a*c
  if disc < 0.0 then return vector3(startPos.x, startPos.y, gz) end

  local t1 = (-b + math.sqrt(disc)) / (2*a)
  local t2 = (-b - math.sqrt(disc)) / (2*a)
  local t = nil
  if t1 > 0 and t2 > 0 then t = math.min(t1, t2)
  elseif t1 > 0 then t = t1
  elseif t2 > 0 then t = t2 end
  if not t then return vector3(startPos.x, startPos.y, gz) end

  return vector3(startPos.x + vel.x*t, startPos.y + vel.y*t, gz)
end

local function spawnBomb(jet)
  local model = Config.Bomb.PropModel
  if not Projectile_LoadModel(model) then return 0, "model_fail" end

  local pos = GetOffsetFromEntityInWorldCoords(jet, 0.0, -1.4, -2.4)
  local dropPos = nil
  local dropOffset = nil
  if DoesEntityExist(jet) then
    dropPos, dropOffset = getBombDropPoints(jet)
  end
  if dropPos then pos = dropPos end
  local obj = CreateObject(model, pos.x, pos.y, pos.z, true, false, true)
  if obj == 0 then return 0, "spawn_fail" end

  SetEntityAsMissionEntity(obj, true, true)

  -- disable collision briefly to avoid spawning inside own aircraft
  SetEntityCollision(obj, false, false)
  SetEntityNoCollisionEntity(obj, jet, true)

  noHitUntil = GetGameTimer() + 1100
  bombArmedAt = GetGameTimer() + math.floor(Config.Bomb.ArmDelaySeconds * 1000)

  if Projectile_LoadPtfx(Config.Bomb.SmokePtfxAsset) then
    UseParticleFxAssetNextCall(Config.Bomb.SmokePtfxAsset)
    StartParticleFxLoopedOnEntity(
      Config.Bomb.SmokePtfxName,
      obj,
      0.0,0.0,0.0,
      0.0,0.0,0.0,
      0.8,
      false,false,false
    )
  end

  -- sound
  Projectile_PlaySound('bomb', 1.0)

  if Spectate_IsOn() then
    Spectate_Follow(obj)
  end

  return obj, "ok"
end

function Bomb_TryDropDumb(jet)
  local ok, reason = Projectile_CanFire("bomb")
  if not ok then return false, reason end

  local obj, r = spawnBomb(jet)
  if obj == 0 then return false, r end

  Projectile_SetFired(obj, "bomb_dumb", jet)
  Projectile.targetEnt = 0
  guidedEngageAt = 0

  -- inherit aircraft velocity AFTER SetFired
  local vx, vy, vz = table.unpack(GetEntityVelocity(jet))
  Projectile.vel = vector3(vx, vy, vz)

  dumbImpact = predictImpact(GetEntityCoords(obj), Projectile.vel)

  local id = ("%d:%d"):format(GetPlayerServerId(PlayerId()), GetGameTimer())
  Projectile.netId = id
  local pos = GetEntityCoords(obj)
  Net_SendProjectileSpawn(id, "bomb_dumb", Config.Bomb.PropModel, 0, pos, Projectile.vel, nil)

  return true, "dropped"
end

function Bomb_TryDropGuided(jet, targetEnt)
  local ok, reason = Projectile_CanFire("bomb")
  if not ok then return false, reason end
  if targetEnt == 0 or not DoesEntityExist(targetEnt) then return false, "no_target" end

  local obj, r = spawnBomb(jet)
  if obj == 0 then return false, r end

  Projectile_SetFired(obj, "bomb_guided", jet)
  Projectile.targetEnt = targetEnt
  guidedEngageAt = GetGameTimer() + math.floor(Config.Bomb.Guided.EngageDelaySeconds * 1000)

  local vx, vy, vz = table.unpack(GetEntityVelocity(jet))
  Projectile.vel = vector3(vx, vy, vz)

  dumbImpact = nil
  local id = ("%d:%d"):format(GetPlayerServerId(PlayerId()), GetGameTimer())
  Projectile.netId = id
  local pos = GetEntityCoords(obj)
  local targetNetId = NetworkGetNetworkIdFromEntity(targetEnt)
  Net_SendProjectileSpawn(id, "bomb_guided", Config.Bomb.PropModel, targetNetId, pos, Projectile.vel, nil)
  return true, "dropped"
end

function Bomb_CancelLocal()
  Projectile_Clear()
end

local function shouldExplode(obj, fromPos, toPos)
  -- enable collision after a bit
  if GetGameTimer() > noHitUntil then
    SetEntityCollision(obj, true, true)
  end

  if GetGameTimer() < bombArmedAt then
    return false, nil
  end

  -- don’t raycast-hit while still overlapping with our own aircraft
  if GetGameTimer() > noHitUntil then
    local hit, hitPos, hitEnt = Projectile_SweepHitIgnore(Projectile.ownerEnt, fromPos, toPos)
    if hit then return true, hitPos, hitEnt end
  end

  local gz = groundAt(toPos)
  if gz and toPos.z <= gz + 0.2 then
    return true, vector3(toPos.x, toPos.y, gz)
  end

  return false, nil, 0
end

function Bomb_Update()
  if Projectile.kind ~= "bomb_dumb" and Projectile.kind ~= "bomb_guided" then return end
  local obj = Projectile_GetEntity()
  if obj == 0 then Projectile_Clear(); return end

  local age = (GetGameTimer() - Projectile.spawnedAt) / 1000.0
  if age > Config.Bomb.MaxLifeSeconds then
    Projectile_ExplodeAt(GetEntityCoords(obj))
    if Projectile.netId then
      Net_SendProjectileExplode(Projectile.netId, Projectile.kind, GetEntityCoords(obj), 0)
    end
    Projectile_Clear()
    return
  end

  local dt = GetFrameTime()
  if dt <= 0.0 then return end

  local p = GetEntityCoords(obj)

  if Projectile.kind == "bomb_guided" then
    -- guided bomb: missile-style homing but ground targets only
    local tgt = Projectile.targetEnt
    if GetGameTimer() < guidedEngageAt then
      Projectile.vel = Projectile.vel + vector3(0,0,-9.81) * dt
    elseif tgt ~= 0 and DoesEntityExist(tgt) then
      local tp = GetEntityCoords(tgt)
      local toT = tp - p
      local dist = #(toT)

      if dist <= Config.Bomb.Guided.ProximityFuse then
        Projectile_ExplodeAt(p)
        Projectile_Clear()
        return
      end

      local desired, _ = Math3D.norm(toT)
      local cur, spd = Math3D.norm(Projectile.vel)
      if spd < 1.0 then cur = desired end

      local newDir = Math3D.lerpDir(cur, desired, Config.Bomb.Guided.TurnRate)
      local targetSpeed = math.max(spd, Config.Bomb.Guided.Speed)
      Projectile.vel = newDir * targetSpeed
    else
      Projectile.vel = Projectile.vel + vector3(0,0,-9.81) * dt
    end
  else
    -- dumb bomb: ballistic with proper inherited forward velocity
    Projectile.vel = Projectile.vel + vector3(0,0,-9.81) * dt
  end

  local newPos = p + Projectile.vel * dt

  local boom, boomPos, hitEnt = shouldExplode(obj, p, newPos)
  if boom then
    Projectile_ExplodeAt(boomPos)
    if Projectile.netId then
      local hitServerId = 0
      if hitEnt and hitEnt ~= 0 then
        local owner = NetworkGetEntityOwner(hitEnt)
        hitServerId = owner and GetPlayerServerId(owner) or 0
      end
      Net_SendProjectileExplode(Projectile.netId, Projectile.kind, boomPos, hitServerId)
    end
    Projectile_Clear()
    return
  end

  Projectile_Integrate(obj, newPos)

  if Projectile.netId then
    if not Projectile.netNextSync then Projectile.netNextSync = 0 end
    if GetGameTimer() >= Projectile.netNextSync then
      Net_SendProjectileUpdate(Projectile.netId, newPos, Projectile.vel)
      Projectile.netNextSync = GetGameTimer() + 140
    end
  end

  -- keep spectate aligned if active
  Spectate_Update()
end

function Bomb_GetDumbImpact()
  return dumbImpact
end

function Bomb_GetPredictedImpact(jet)
  if jet == 0 or not DoesEntityExist(jet) then return nil end
  local pos, _ = getBombDropPoints(jet)
  if not pos then return nil end

  local vx, vy, vz = table.unpack(GetEntityVelocity(jet))
  local vel = vector3(vx, vy, vz)
  return predictImpact(pos, vel)
end
