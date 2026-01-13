local spectating = false
local cam = nil
local lookYaw = 0.0
local lookPitch = 0.0

function Spectate_IsOn()
  return spectating
end

local function stop()
  if not spectating then return end
  spectating = false
  RenderScriptCams(false, true, 150, true, true)
  if cam then DestroyCam(cam, false); cam = nil end
end

local function start(ent)
  if ent == 0 or not DoesEntityExist(ent) then return end
  if spectating then return end

  spectating = true
  lookYaw = 0.0
  lookPitch = 0.0

  cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
  SetCamFov(cam, 70.0)
  RenderScriptCams(true, true, 150, true, true)
end

function Spectate_Toggle(ent)
  if spectating then stop() else start(ent) end
end

function Spectate_Follow(_ent)
  -- chase cam handled in Spectate_Update
end

local function getDirFromVelocity(ent)
  local vx, vy, vz = table.unpack(GetEntityVelocity(ent))
  local v = vector3(vx, vy, vz)
  local dir, spd = Math3D.norm(v)
  if spd < 2.0 then
    dir = GetEntityForwardVector(ent)
    dir, _ = Math3D.norm(dir)
  end
  return dir
end

function Spectate_Update()
  if not spectating then return end

  local ent = Projectile_GetEntity()
  if ent == 0 or not DoesEntityExist(ent) then
    stop()
    return
  end

  -- mouse look
  DisableControlAction(0, 1, true)
  DisableControlAction(0, 2, true)
  local mx = GetDisabledControlNormal(0, 1)
  local my = GetDisabledControlNormal(0, 2)
  lookYaw   = lookYaw   + (mx * 2.1)
  lookPitch = lookPitch + (my * 2.1)
  if lookPitch > 1.5 then lookPitch = 1.5 end
  if lookPitch < -1.5 then lookPitch = -1.5 end
  if lookYaw > math.pi then lookYaw = lookYaw - (math.pi * 2.0) end
  if lookYaw < -math.pi then lookYaw = lookYaw + (math.pi * 2.0) end

  local p = GetEntityCoords(ent)
  local dir = getDirFromVelocity(ent)

  local dist = 9.0
  local heading = math.atan(dir.y, dir.x)
  local yaw = heading + lookYaw
  local pitch = lookPitch

  local cosPitch = math.cos(pitch)
  local offset = vector3(
    math.cos(yaw) * cosPitch * dist,
    math.sin(yaw) * cosPitch * dist,
    math.sin(pitch) * dist
  )

  SetCamCoord(cam, p.x - offset.x, p.y - offset.y, p.z - offset.z)
  PointCamAtCoord(cam, p.x, p.y, p.z)
end
