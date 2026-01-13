local Stats = {}
local Limits = {}

local function nowMs()
  return GetGameTimer()
end

local function getBucket(kind)
  if kind == "missile" then return "missile" end
  if kind == "bomb_guided" or kind == "bomb_dumb" then return "bomb" end
  return "other"
end

local function ensureLimits(src)
  if Limits[src] then return Limits[src] end
  Limits[src] = {
    lastLaunchAt = { missile = 0, bomb = 0 },
    active = { missile = 0, bomb = 0 },
    activeIds = {},
  }
  return Limits[src]
end

local function pruneExpired(limit)
  local now = nowMs()
  for id, info in pairs(limit.activeIds) do
    if info.expiresAt and now > info.expiresAt then
      limit.activeIds[id] = nil
      if info.bucket and limit.active[info.bucket] then
        limit.active[info.bucket] = math.max(0, limit.active[info.bucket] - 1)
      end
    end
  end
end

local function ensureStats(src)
  if Stats[src] then return Stats[src] end
  Stats[src] = {
    missilesFired = 0,
    missilesHit = 0,
    missilesMiss = 0,
    bombsFired = 0,
    bombsHit = 0,
    bombsMiss = 0,
    flaresUsed = 0,
    chaffUsed = 0,
  }
  return Stats[src]
end

RegisterNetEvent("hudguns:projectileSpawn", function(id, kind, model, targetNetId, pos, vel, missileType)
  local src = source
  local bucket = getBucket(kind)
  local limit = ensureLimits(src)
  pruneExpired(limit)
  local maxActive = 2
  local cooldownMs = 5000
  if bucket ~= "other" then
    if (limit.active[bucket] or 0) >= maxActive or (nowMs() - (limit.lastLaunchAt[bucket] or 0)) < cooldownMs then
      TriggerClientEvent("hudguns:projectileReject", src, id)
      return
    end
    limit.active[bucket] = (limit.active[bucket] or 0) + 1
    limit.lastLaunchAt[bucket] = nowMs()
    limit.activeIds[id] = {
      bucket = bucket,
      expiresAt = nowMs() + 25000,
    }
  end

  local stats = ensureStats(src)
  if kind == "missile" then
    stats.missilesFired = stats.missilesFired + 1
  elseif kind == "bomb_guided" or kind == "bomb_dumb" then
    stats.bombsFired = stats.bombsFired + 1
  end
  TriggerClientEvent("hudguns:projectileSpawn", -1, {
    id = id,
    kind = kind,
    model = model,
    targetNetId = targetNetId,
    pos = pos,
    vel = vel,
    owner = src,
    missileType = missileType,
  })
end)

RegisterNetEvent("hudguns:projectileUpdate", function(id, pos, vel)
  TriggerClientEvent("hudguns:projectileUpdate", -1, id, pos, vel)
end)

RegisterNetEvent("hudguns:projectileExplode", function(id, kind, pos, hitServerId)
  local limit = ensureLimits(source)
  local entry = limit.activeIds[id]
  if entry then
    limit.activeIds[id] = nil
    if entry.bucket and limit.active[entry.bucket] then
      limit.active[entry.bucket] = math.max(0, limit.active[entry.bucket] - 1)
    end
  end
  local stats = ensureStats(source)
  if kind == "missile" then
    if hitServerId and hitServerId ~= 0 then
      stats.missilesHit = stats.missilesHit + 1
    else
      stats.missilesMiss = stats.missilesMiss + 1
    end
  elseif kind == "bomb_guided" or kind == "bomb_dumb" then
    if hitServerId and hitServerId ~= 0 then
      stats.bombsHit = stats.bombsHit + 1
    else
      stats.bombsMiss = stats.bombsMiss + 1
    end
  end
  TriggerClientEvent("hudguns:projectileExplode", -1, id, pos)
end)

RegisterNetEvent("hudguns:countermeasure", function(kind, vehNetId)
  local src = source
  local stats = ensureStats(src)
  if kind == "flare" then
    stats.flaresUsed = stats.flaresUsed + 1
  elseif kind == "chaff" then
    stats.chaffUsed = stats.chaffUsed + 1
  end
  TriggerClientEvent("hudguns:countermeasure", -1, kind, vehNetId, src)
end)

RegisterNetEvent("hudguns:lockState", function(targetNetId, lockType, state)
  TriggerClientEvent("hudguns:lockState", -1, targetNetId, lockType, state)
end)

RegisterNetEvent("hudguns:requestStats", function()
  local src = source
  ensureStats(src)
  TriggerClientEvent("hudguns:stats", src, Stats[src])
end)

AddEventHandler("playerDropped", function()
  Stats[source] = nil
  Limits[source] = nil
end)
