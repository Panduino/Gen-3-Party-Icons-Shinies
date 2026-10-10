return function(mod)
  if mod.generation ~= 3 then return end

  local Pokemon = require("src.core.game3.pokemon")
  -- Use the individually numbered PokéSprite files instead of the packed
  -- atlas. The atlas interleaves alternate forms, which caused wrong icons
  -- (notably Treecko/Celebi) whenever a form count was off.
  local icons, iconImages = {}, setmetatable({}, {__mode = "k"})

  local function sheetIcon(mon)
    if not mon or (Pokemon.isEgg and Pokemon.isEgg(mon)) then return nil end
    local species = Pokemon.monPicSpecies and Pokemon.monPicSpecies(mon)
    local nat = species and Pokemon.national and tonumber(Pokemon.national(species))
    if not nat or nat < 1 or nat > 493 then return nil end

    local shiny = Pokemon.isShiny and Pokemon.isShiny(mon) or false
    local key = (shiny and "s" or "n") .. nat
    if icons[key] then return icons[key] end

    local file = ("assets/icons/%s/%03d.png"):format(
      shiny and "shiny" or "normal", nat)
    local ok, img = pcall(mod.assets.image, mod.assets, file)
    if not ok or not img then
      mod.log:warn("Could not load party icon: " .. file)
      return nil
    end
    if img.setFilter then img:setFilter("nearest", "nearest") end
    local sw, sh = img:getDimensions()
    if sw < 32 or sh < 30 then
      mod.log:warn("Invalid party icon dimensions: " .. file)
      return nil
    end
    local x = math.floor((sw - 32) / 2)
    local quad = love.graphics.newQuad(x, 0, 32, 30, sw, sh)
    local icon = {
      image = img, w = 32, h = 30, sheetH = sh,
      frames = 2, quads = { [0] = quad, [1] = quad },
      trueColor = true, gen3PartyIconSheet = true,
    }
    icons[key] = icon
    iconImages[img] = true
    return icon
  end

  -- The Gen 3 party and PC screens call Pokemon.monIcon directly.
  -- Install after Gen3Compat's initial wrapping and reinstall only if
  -- a later engine reseed replaces our function.
  local installed
  local function install()
    if Pokemon.monIcon == installed then return end
    local fallback = Pokemon.monIcon
    installed = function(mon)
      return sheetIcon(mon) or fallback(mon)
    end
    Pokemon.monIcon = installed
  end

  install()

  -- Make every custom party icon use the same bounce as the selected
  -- icon. The engine's party menu installs different OAM callbacks for
  -- selected and unselected slots; replace only the unselected callback
  -- for our sheets, without touching the selected callback.
  local Oam = require("src.core.game3.oam")
  local originalSetCallback = Oam.setCallback
  local function bounceAll(sprite)
    if not sprite then return end
    local hpLevel = sprite.data and sprite.data[3] or 0
    local duration = ({ [0]=5/60, [1]=5/60, [2]=16/60, [3]=32/60, [4]=5/60 })[hpLevel] or 8/60
    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local last = sprite._lastAnimTime or now
    local dt = math.max(0, math.min(now - last, 0.1))
    sprite._lastAnimTime = now
    sprite._animElapsed = (sprite._animElapsed or 0) + dt
    if duration > 0 then
      while sprite._animElapsed >= duration do
        sprite._animElapsed = sprite._animElapsed - duration
        sprite.data[2] = 1 - (sprite.data[2] or 0)
      end
    end
    local frame = sprite.data[2] or 0
    sprite.x2 = 0
    sprite.y2 = hpLevel == 4 and 0 or (frame == 0 and -3 or 1)
    if sprite._quads and sprite._quads[frame] then
      sprite.quad = sprite._quads[frame]
    end
  end

  Oam.setCallback = function(id, callback)
    local sprite = Oam.get(id)
    if sprite and iconImages[sprite.image]
       and type(callback) == "function" then
      -- Both selected and unselected custom icons get the same bounce.
      return originalSetCallback(id, bounceAll)
    end
    return originalSetCallback(id, callback)
  end

  -- Gen3Compat.reseedSprites() may replace the function on map changes.
  -- Use a mod event rather than patching global love.update/draw.
  if mod.events and mod.events.on then
    mod.events:on("game.ready", function() install() end)
    mod.events:on("world.mapEnter", function() install() end)
  end
  mod.log:info("Gen 3 Party Icons: per-species sprite files active")
end
