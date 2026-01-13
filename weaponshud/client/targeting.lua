Targeting = {}

local cache = {
  lastRefresh = 0,
  vehicles = {},
}

local function isAirVehicle(veh)
  if veh == 0 or not DoesEntityExist(veh) then return false end
  local cls = GetVehicleClass(veh)
  return (cls == 15 or cls == 16)
end

local function refreshPool()
  cache.vehicles = GetGamePool("CVehicle")
  cache.lastRefresh = GetGameTimer()
end

local function getPool()
  if (GetGameTimer() - cache.lastRefresh) > 250 then
    refreshPool()
  end
  return cache.vehicles
end

local function acquireFromPool(jet, coneDeg, rangeM, airOnly)
  local jetPos = GetEntityCoords(jet)
  local fwd, _ = Math3D.norm(GetEntityForwardVector(jet))
  local maxAng = Math3D.degToRad(coneDeg)

  local bestEnt = 0
  local bestScore = 1e9

  local pool = getPool()
  for i=1, #pool do
    local veh = pool[i]
    if veh ~= jet and DoesEntityExist(veh) then
      if (not airOnly) or isAirVehicle(veh) then
        local pos = GetEntityCoords(veh)
        local toT = pos - jetPos
        local dist = #(toT)
        if dist <= rangeM then
          local dir, _ = Math3D.norm(toT)
          local ang = Math3D.angleBetween(fwd, dir)
          if ang <= maxAng then
            local score = ang * 1000.0 + dist
            if score < bestScore then
              bestScore = score
              bestEnt = veh
            end
          end
        end
      end
    end
  end

  return bestEnt
end

function Targeting.AcquireAATarget(jet)
  return acquireFromPool(jet, Config.AA.ConeDeg, Config.AA.RangeM, Config.AA.AirOnly)
end

function Targeting.AcquireAGTarget(jet)
  return acquireFromPool(jet, Config.AG.ConeDeg, Config.AG.RangeM, Config.AG.AirOnly)
end

function Targeting.ScreenPointForEntity(ent)
  if ent == 0 or not DoesEntityExist(ent) then return nil end
  local pos = GetEntityCoords(ent)
  local ok, sx, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z)
  if ok then return { x = sx, y = sy } end
  return nil
end

local function getStealthMultipliers(veh)
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Stealth and Config.PvP.Stealth.Enabled) then
    return 1.0, 1.0
  end
  local m = GetEntityModel(veh)
  local entry = Config.PvP.Stealth.Models and Config.PvP.Stealth.Models[m]
  if entry then
    return (entry.rcs or 1.0), (entry.ir or 1.0)
  end
  return 1.0, 1.0
end

local function hasLOS(fromEnt, toEnt)
  local a = GetEntityCoords(fromEnt)
  local b = GetEntityCoords(toEnt)
  local ray = StartShapeTestRay(a.x, a.y, a.z, b.x, b.y, b.z, -1, fromEnt, 7)
  local _, hit, _, _, hitEnt = GetShapeTestResult(ray)
  if hit == 0 then return true end
  return hitEnt == toEnt
end

local function getAGL(ent)
  local p = GetEntityCoords(ent)
  local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z, 0)
  if ok then return (p.z - gz) end
  return 9999.0
end

function Targeting.AcquireRadarTarget(jet)
  if not (Config.PvP and Config.PvP.Enabled and Config.PvP.Radar and Config.PvP.Radar.Enabled) then
    return Targeting.AcquireAATarget(jet)
  end

  local baseRange = Config.PvP.Radar.RangeM or 4500.0
  local coneDeg = Config.PvP.Radar.ConeDeg or 35.0

  local jetPos = GetEntityCoords(jet)
  local fwd, _ = Math3D.norm(GetEntityForwardVector(jet))
  local maxAng = Math3D.degToRad(coneDeg)

  local bestEnt = 0
  local bestScore = 1e9

  local pool = getPool()
  for i=1, #pool do
    local veh = pool[i]
    if veh ~= jet and DoesEntityExist(veh) then
      if isAirVehicle(veh) then
        -- min height requirement (stops ground skimming locks)
        if getAGL(veh) >= (Config.PvP.Radar.MinTargetHeightAGL or 35.0) then
          local rcs, _ = getStealthMultipliers(veh)
          local effRange = baseRange * math.sqrt(math.max(0.05, rcs))

          local pos = GetEntityCoords(veh)
          local toT = pos - jetPos
          local dist = #(toT)
          if dist <= effRange then
            local dir, _ = Math3D.norm(toT)
            local ang = Math3D.angleBetween(fwd, dir)
            if ang <= maxAng then
              if (not Config.PvP.Radar.RequireLOS) or hasLOS(jet, veh) then
                local score = ang * 1000.0 + dist
                if score < bestScore then
                  bestScore = score
                  bestEnt = veh
                end
              end
            end
          end
        end
      end
    end
  end

  return bestEnt
end
