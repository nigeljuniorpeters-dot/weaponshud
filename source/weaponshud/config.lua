Config = {}

Config.AllowedModels = {
      [`f35b`] = { rcs = 0.45, ir = 0.65 },
      [`f35c`] = { rcs = 0.45, ir = 0.65 },
      [`f22a`] = { rcs = 0.40, ir = 0.60 },
            [`ah6m`] = { rcs = 0.40, ir = 0.60 },
                      [`ahz1`] = { rcs = 0.40, ir = 0.60 },
    }

Config.CommandHud = "hud"

Config.Weapon = {
  CooldownSeconds = 5.0,
  OneAtATime = true,
  MaxActivePerKind = 2,
}

Config.AA = {
  RangeM = 2500.0,
  ConeDeg = 45.0,
  AirOnly = true,
}

Config.AG = {
  RangeM = 3500.0,
  ConeDeg = 45.0,
  AirOnly = false,
}

Config.Explosion = {
  Type = 32,
  DamageScale = 5.9,
  Audible = true,
  Invisible = false,
  CameraShake = 1.0
}

Config.Missile = {
  Speed = 340.0,
  TurnRate = 1.09,
  ProximityFuse = 3.0,
  MaxLifeSeconds = 15.0,
  PropModel = `h4_prop_h4_airmissile_01a`,
  SmokePtfxAsset = "scr_ar_planes",
  SmokePtfxName = "scr_ar_trail_smoke",
}

Config.Bomb = {
  MaxLifeSeconds = 22.0,
  PropModel = `w_ex_vehiclemissile_2`,
  ArmDelaySeconds = 0.95,
  SpawnNoCollisionMs = 950,
  Guided = {
    EngageDelaySeconds = 0.6,
    Speed = 175.0,
    TurnRate = 1.355,
    ProximityFuse = 3.5
  },
  SmokePtfxAsset = "scr_ar_planes",
  SmokePtfxName = "scr_ar_trail_smoke",
}

Config.GunHud = {
  Enabled = true,
  BulletSpeed = 900.0
}

Config.Keybinds = {
  Fire = { cmd = "+f16_fire", desc = "F16 HUD: Fire/Release", default = "mouse1" },
  Spectate = { cmd = "+f16_cam", desc = "F16 HUD: Toggle weapon camera", default = "e" },
  ModeNext = { cmd = "+f16_mode_next", desc = "F16 HUD: Next mode", default = "right" },
  ModePrev = { cmd = "+f16_mode_prev", desc = "F16 HUD: Previous mode", default = "left" },
  WeaponNext = { cmd = "+f16_wpn_next", desc = "F16 HUD: Next weapon", default = "up" },
  WeaponPrev = { cmd = "+f16_wpn_prev", desc = "F16 HUD: Previous weapon", default = "down" },
}

Config.Controls = {
  VehAttack = 69,
  Attack = 24,
}

-- =========================
-- PvP / seeker realism layer
-- =========================
Config.PvP = {
  Enabled = true,

  -- Countermeasures (flare)
  Flare = {
    Enabled = true,
    Keybind = { cmd = "+f16_flare", desc = "F16 HUD: Deploy flare", default = "g" },
    CooldownSeconds = 3.0,
    EffectSeconds = 3.0,        -- seconds flares influence IR seekers
    DecoyBaseChance = 0.35,     -- baseline chance IR seeker breaks after flare
    DecoyChanceMax = 0.85,      -- clamp
    LoseLockSeconds = 1.2,      -- if decoyed, missile flies dumb for this long
  },

  -- Countermeasures (chaff) - affects RADAR missiles
  Chaff = {
    Enabled = true,
    Keybind = { cmd = "+f16_chaff", desc = "F16 HUD: Deploy chaff", default = "h" },
    CooldownSeconds = 12.0,
    EffectSeconds = 4.0,
    DecoyBaseChance = 0.25,
    DecoyChanceMax = 0.70,
    LoseLockSeconds = 1.4,
  },



  -- Stealth: makes radar detect harder + tracking slightly worse
  Stealth = {
    Enabled = true,
    -- model hash -> multipliers (lower = stealthier)
    Models = {
      [`f35b`] = { rcs = 0.45, ir = 0.65 },
      [`f35c`] = { rcs = 0.45, ir = 0.65 },
      [`f22a`] = { rcs = 0.40, ir = 0.60 },
    },
  },

  -- Heat model (for IR missiles)
  Heat = {
    Enabled = true,
    Base = 0.35,
    ThrottleWeight = 0.75,
    AfterburnerBonus = 0.20,
  },

  -- Sounds (InteractSound)
  Sounds = {
    Enabled = true,
    LockTone = "lockwarn",
    MissileIR = "fox2",
    MissileRadar = "fox3",
    Bomb = "bomb",
    MissileTone = "missile"
  },

  -- Radar missile rules (LOS, min height, lock time)
  Cones = { IR = 0.42, RADAR = 0.30 },

  Radar = {
    Enabled = true,
    RangeM = 4500.0,
    ConeDeg = 35.0,
    MinTargetHeightAGL = 35.0,
    RequireLOS = true,
    LockTimeSeconds = 1.5,
  },
}

Config.MissileIR = {
  Speed = Config.Missile.Speed,
  TurnRate = Config.Missile.TurnRate,
  ProximityFuse = Config.Missile.ProximityFuse,
  MaxLifeSeconds = Config.Missile.MaxLifeSeconds,
}

Config.MissileRadar = {
  Speed = 270.0,
  TurnRate = 1.075,
  ProximityFuse = 3.0,
  MaxLifeSeconds = 25.0,
}
