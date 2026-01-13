Math3D = {}

function Math3D.norm(v)
  local m = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
  if m < 1e-6 then return vector3(0,0,0), 0.0 end
  return vector3(v.x/m, v.y/m, v.z/m), m
end

function Math3D.lerpDir(a, b, t)
  local x = a.x + (b.x - a.x) * t
  local y = a.y + (b.y - a.y) * t
  local z = a.z + (b.z - a.z) * t
  local v, _ = Math3D.norm(vector3(x,y,z))
  return v
end

function Math3D.angleBetween(a, b)
  local dot = a.x*b.x + a.y*b.y + a.z*b.z
  if dot > 1.0 then dot = 1.0 end
  if dot < -1.0 then dot = -1.0 end
  return math.acos(dot)
end

function Math3D.degToRad(d) return d * 0.017453292519943295 end

function Math3D.leadPoint(shooterPos, shooterVel, targetPos, targetVel, projectileSpeed)
  local p = targetPos - shooterPos
  local v = targetVel - shooterVel
  local s = projectileSpeed

  local a = (v.x*v.x + v.y*v.y + v.z*v.z) - (s*s)
  local b = 2.0 * (p.x*v.x + p.y*v.y + p.z*v.z)
  local c = (p.x*p.x + p.y*p.y + p.z*p.z)

  local t = nil
  if math.abs(a) < 1e-6 then
    if math.abs(b) > 1e-6 then t = -c / b end
  else
    local disc = b*b - 4*a*c
    if disc >= 0.0 then
      local sqrtDisc = math.sqrt(disc)
      local t1 = (-b + sqrtDisc) / (2*a)
      local t2 = (-b - sqrtDisc) / (2*a)
      if t1 > 0 and t2 > 0 then t = math.min(t1, t2)
      elseif t1 > 0 then t = t1
      elseif t2 > 0 then t = t2 end
    end
  end

  if not t or t < 0.0 then
    local dist = math.sqrt(c)
    t = dist / math.max(s, 1.0)
  end

  return targetPos + targetVel * t
end
