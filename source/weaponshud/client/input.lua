Input = {
  firePressed = false,
  camPressed  = false,
  modeNext    = false,
  modePrev    = false,
  wpnNext     = false,
  wpnPrev     = false,
}

local function pulse(name) Input[name] = true end

local function makeKeybind(cmdPlus, desc, defaultKey, fieldName)
  RegisterCommand(cmdPlus, function() pulse(fieldName) end, false)
  RegisterCommand(cmdPlus:gsub("^%+","-"), function() end, false)
  RegisterKeyMapping(cmdPlus, desc, "keyboard", defaultKey)
end

CreateThread(function()
  makeKeybind(Config.Keybinds.Fire.cmd, Config.Keybinds.Fire.desc, Config.Keybinds.Fire.default, "firePressed")
  makeKeybind(Config.Keybinds.Spectate.cmd, Config.Keybinds.Spectate.desc, Config.Keybinds.Spectate.default, "camPressed")
  makeKeybind(Config.Keybinds.ModeNext.cmd, Config.Keybinds.ModeNext.desc, Config.Keybinds.ModeNext.default, "modeNext")
  makeKeybind(Config.Keybinds.ModePrev.cmd, Config.Keybinds.ModePrev.desc, Config.Keybinds.ModePrev.default, "modePrev")
  makeKeybind(Config.Keybinds.WeaponNext.cmd, Config.Keybinds.WeaponNext.desc, Config.Keybinds.WeaponNext.default, "wpnNext")
  makeKeybind(Config.Keybinds.WeaponPrev.cmd, Config.Keybinds.WeaponPrev.desc, Config.Keybinds.WeaponPrev.default, "wpnPrev")
end)

function Input_Consume()
  local s = {
    firePressed = Input.firePressed,
    camPressed  = Input.camPressed,
    modeNext    = Input.modeNext,
    modePrev    = Input.modePrev,
    wpnNext     = Input.wpnNext,
    wpnPrev     = Input.wpnPrev,
  }
  Input.firePressed = false
  Input.camPressed  = false
  Input.modeNext    = false
  Input.modePrev    = false
  Input.wpnNext     = false
  Input.wpnPrev     = false
  return s
end
