Projectile = {
  ent = 0,
  kind = "none",
  targetEnt = 0,
  spawnedAt = 0,
  lastFireAt = -99999,

  -- kinematics
  vel = vector3(0,0,0),
  lastPos = nil,

  -- ownership (for raycast ignore / self-hit prevention)
  ownerEnt = 0,

  -- network sync (for remote visuals)
  netId = nil,
  netNextSync = 0,
}

Projectile_Limits = {
  lastLaunchAt = { missile = 0, bomb = 0 },
  active = { missile = 0, bomb = 0 },
}

local function kindBucket(kind)
  if kind == "missile" then return "missile" end
  if kind == "bomb_dumb" or kind == "bomb_guided" or kind == "bomb" then return "bomb" end
  return "other"
end

local function loadModel(model)
  if not IsModelInCdimage(model) then return false end
  RequestModel(model)
  local t = GetGameTimer() + 5000
  while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
  return HasModelLoaded(model)
end

local function loadPtfx(asset)
  RequestNamedPtfxAsset(asset)
  local t = GetGameTimer() + 3000
  while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < t do Wait(0) end
  return HasNamedPtfxAssetLoaded(asset)
end

function Projectile_CanFire(kind)
  local now = GetGameTimer() / 1000.0
  if (now - Projectile.lastFireAt) < Config.Weapon.CooldownSeconds then return false, "cooldown" end
  if Config.Weapon.OneAtATime and Projectile.ent ~= 0 and DoesEntityExist(Projectile.ent) then return false, "already_active" end
  if kind then
    local bucket = kindBucket(kind)
    if bucket ~= "other" then
      local active = Projectile_Limits.active[bucket] or 0
      local maxActive = Config.Weapon.MaxActivePerKind or 2
      if active >= maxActive then return false, "limit_active" end
      local last = Projectile_Limits.lastLaunchAt[bucket] or 0
      if (GetGameTimer() - last) < (Config.Weapon.CooldownSeconds * 1000.0) then return false, "cooldown" end
    end
  end
  return true, "ok"
end

-- NOTE: does NOT zero vel anymore (bombs need inherited velocity)
function Projectile_SetFired(ent, kind, ownerEnt)
  Projectile.ent = ent
  Projectile.kind = kind
  Projectile.spawnedAt = GetGameTimer()
  Projectile.lastFireAt = GetGameTimer() / 1000.0
  Projectile.lastPos = GetEntityCoords(ent)
  Projectile.ownerEnt = ownerEnt or 0
  Projectile.netId = nil
  Projectile.netNextSync = 0

  local bucket = kindBucket(kind)
  if bucket ~= "other" then
    Projectile_Limits.active[bucket] = (Projectile_Limits.active[bucket] or 0) + 1
    Projectile_Limits.lastLaunchAt[bucket] = GetGameTimer()
  end
end

function Projectile_Clear()
  local bucket = kindBucket(Projectile.kind)
  if bucket ~= "other" then
    Projectile_Limits.active[bucket] = math.max(0, (Projectile_Limits.active[bucket] or 0) - 1)
  end
  if Projectile.ent ~= 0 and DoesEntityExist(Projectile.ent) then DeleteEntity(Projectile.ent) end
  Projectile.ent = 0
  Projectile.kind = "none"
  Projectile.targetEnt = 0
  Projectile.spawnedAt = 0
  Projectile.vel = vector3(0,0,0)
  Projectile.lastPos = nil
  Projectile.ownerEnt = 0
  Projectile.netId = nil
  Projectile.netNextSync = 0
end

function Projectile_GetEntity()
  if Projectile.ent ~= 0 and DoesEntityExist(Projectile.ent) then return Projectile.ent end
  return 0
end

function Projectile_LoadModel(model) return loadModel(model) end
function Projectile_LoadPtfx(asset) return loadPtfx(asset) end

function Projectile_ExplodeAt(pos)
  AddExplosion(
    pos.x, pos.y, pos.z,
    Config.Explosion.Type,
    Config.Explosion.DamageScale,
    Config.Explosion.Audible,
    Config.Explosion.Invisible,
    Config.Explosion.CameraShake
  )
end

-- InteractSound support (safe if resource missing)
function Projectile_PlaySound(name, vol)
  pcall(function()
    TriggerEvent('InteractSound_CL:PlayOnOne', name, vol or 1.0)
  end)
end

function Projectile_Integrate(ent, newPos)
  SetEntityCoordsNoOffset(ent, newPos.x, newPos.y, newPos.z, true, true, true)
end

-- Raycast from A->B ignoring ONE entity (use owner to prevent “hit myself”)
function Projectile_SweepHitIgnore(ignoreEnt, fromPos, toPos)
  local ray = StartShapeTestRay(
    fromPos.x, fromPos.y, fromPos.z,
    toPos.x,   toPos.y,   toPos.z,
    -1,
    ignoreEnt or 0,
    7
  )
  local _, hit, endPos, _, hitEnt = GetShapeTestResult(ray)
  if hit == 1 then
    return true, endPos, hitEnt
  end
  return false, nil, 0
end
