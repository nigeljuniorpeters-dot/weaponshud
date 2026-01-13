local hudOn = false

function Hud_SetEnabled(state)
  hudOn = state
  SetNuiFocus(false, false)
  SendNUIMessage({ type = "hud", enabled = state })
end

function Hud_Update(data)
  if not hudOn then return end
  SendNUIMessage({ type = "state", data = data })
end
