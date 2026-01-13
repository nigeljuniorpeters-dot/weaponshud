Network = {
  remoteProjectiles = {},
  nextWarnAt = 0,
}

local function nowMs() return GetGameTimer() end

local function createRemoteProjectile(data)
  local model = data.model
  if not Projectile_LoadModel(model) then return end

  local ent = CreateObject(model, data.pos.x, data.pos.y, data.pos.z, false, false, false)
  if ent == 0 then return end

  SetEntityCollision(ent, false, false)

  Network.remoteProjectiles[data.id] = {
    ent = ent,
    kind = data.kind,
    vel = data.vel,
    lastUpdate = nowMs(),
    owner = data.owner,
    targetNetId = data.targetNetId or 0,
    smokeHandle = 0,
    smokeKind = data.kind,
  }

  if data.kind == "missile" and Projectile_LoadPtfx(Config.Missile.SmokePtfxAsset) then
    UseParticleFxAssetNextCall(Config.Missile.SmokePtfxAsset)
    Network.remoteProjectiles[data.id].smokeHandle = StartParticleFxLoopedOnEntity(
      Config.Missile.SmokePtfxName,
      ent,
      0.0, 0.0, 0.0,
      0.0, 0.0, 0.0,
      0.85,
      false, false, false
    )
  elseif (data.kind == "bomb_guided" or data.kind == "bomb_dumb") and Projectile_LoadPtfx(Config.Bomb.SmokePtfxAsset) then
    UseParticleFxAssetNextCall(Config.Bomb.SmokePtfxAsset)
    Network.remoteProjectiles[data.id].smokeHandle = StartParticleFxLoopedOnEntity(
      Config.Bomb.SmokePtfxName,
      ent,
      0.0, 0.0, 0.0,
      0.0, 0.0, 0.0,
      0.8,
      false, false, false
    )
  end
end

local function removeRemoteProjectile(id)
  local entry = Network.remoteProjectiles[id]
  if not entry then return end
  if entry.smokeHandle and entry.smokeHandle ~= 0 then
    StopParticleFxLooped(entry.smokeHandle, true)
  end
  if entry.ent and DoesEntityExist(entry.ent) then
    DeleteEntity(entry.ent)
  end
  Network.remoteProjectiles[id] = nil
end

function Net_SendLockState(targetNetId, lockType, state)
  if not targetNetId or targetNetId == 0 then return end
  TriggerServerEvent("hudguns:lockState", targetNetId, lockType, state)
end

function Net_SendCountermeasure(kind, vehNetId)
  if not vehNetId or vehNetId == 0 then return end
  TriggerServerEvent("hudguns:countermeasure", kind, vehNetId)
end

function Net_SendProjectileSpawn(id, kind, model, targetNetId, pos, vel, missileType)
  TriggerServerEvent("hudguns:projectileSpawn", id, kind, model, targetNetId, pos, vel, missileType)
end

function Net_SendProjectileUpdate(id, pos, vel)
  TriggerServerEvent("hudguns:projectileUpdate", id, pos, vel)
end

function Net_SendProjectileExplode(id, kind, pos, hitServerId)
  TriggerServerEvent("hudguns:projectileExplode", id, kind, pos, hitServerId or 0)
end

RegisterNetEvent("hudguns:projectileSpawn", function(data)
  if data.owner == GetPlayerServerId(PlayerId()) then return end
  createRemoteProjectile(data)
end)

RegisterNetEvent("hudguns:projectileUpdate", function(id, pos, vel)
  local entry = Network.remoteProjectiles[id]
  if not entry then return end
  entry.vel = vel
  entry.lastUpdate = nowMs()
  if entry.ent and DoesEntityExist(entry.ent) then
    SetEntityCoordsNoOffset(entry.ent, pos.x, pos.y, pos.z, true, true, true)
  end
end)

RegisterNetEvent("hudguns:projectileExplode", function(id, pos)
  local entry = Network.remoteProjectiles[id]
  if entry then
    if entry.smokeHandle and entry.smokeHandle ~= 0 then
      StopParticleFxLooped(entry.smokeHandle, true)
    end
  end
  Projectile_ExplodeAt(pos)
  removeRemoteProjectile(id)
end)

RegisterNetEvent("hudguns:projectileReject", function(id)
  if Projectile.netId ~= id then return end
  if Projectile.kind == "missile" then
    Missile_CancelLocal()
  elseif Projectile.kind == "bomb_dumb" or Projectile.kind == "bomb_guided" then
    Bomb_CancelLocal()
  else
    Projectile_Clear()
  end
end)

RegisterNetEvent("hudguns:countermeasure", function(kind, vehNetId, ownerId)
  if ownerId == GetPlayerServerId(PlayerId()) then return end
  local veh = NetToVeh(vehNetId)
  if veh == 0 or not DoesEntityExist(veh) then return end

  if kind == "flare" then
    CM_DeployFlareRemote(veh)
  elseif kind == "chaff" then
    CM_DeployChaffRemote(veh)
  end
end)

RegisterNetEvent("hudguns:lockState", function(targetNetId, lockType, state)
  local myVeh = GetVehiclePedIsIn(PlayerPedId(), false)
  if myVeh == 0 then return end
  if NetworkGetNetworkIdFromEntity(myVeh) ~= targetNetId then return end
  if not (Config.PvP and Config.PvP.Sounds and Config.PvP.Sounds.Enabled) then return end

  if nowMs() < Network.nextWarnAt then return end
  if state == "lock" then
    Network.nextWarnAt = nowMs() + 800
    Projectile_PlaySound(Config.PvP.Sounds.LockTone or "lock", 0.6)
  elseif state == "track" then
    Network.nextWarnAt = nowMs() + 1200
    Projectile_PlaySound(Config.PvP.Sounds.MissileTone or "missile", 0.7)
  end
end)

CreateThread(function()
  while true do
    Wait(0)
    local now = nowMs()
    for id, entry in pairs(Network.remoteProjectiles) do
      if entry.ent and DoesEntityExist(entry.ent) then
        local dt = (now - entry.lastUpdate) / 1000.0
        if dt > 0.0 and dt < 0.25 then
          local pos = GetEntityCoords(entry.ent)
          local newPos = pos + (entry.vel * dt)
          SetEntityCoordsNoOffset(entry.ent, newPos.x, newPos.y, newPos.z, true, true, true)
        end
        local velDir, _ = Math3D.norm(entry.vel)
        SetEntityHeading(entry.ent, GetHeadingFromVector_2d(velDir.x, velDir.y))
      else
        removeRemoteProjectile(id)
      end
    end
  end
end)
