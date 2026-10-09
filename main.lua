return function(mod)
  if mod.generation ~= 3 then return end

  local Pokemon = require("src.core.game3.pokemon")
  local W, H, COLS = 40, 30, 32
  local extra = {
    [3]=1,[6]=2,[9]=1,[65]=1,[94]=1,[115]=1,[127]=1,[130]=1,[142]=1,[150]=2,
    [181]=1,[201]=27,[212]=1,[229]=1,[248]=1,[254]=1,[257]=1,[260]=1,
    [282]=1,[303]=1,[306]=1,[308]=1,[310]=1,[354]=1,[359]=1,[362]=1,
    [373]=1,[376]=1,[386]=4,[412]=2,[413]=2,[422]=1,[423]=1,[428]=1,
    [445]=1,[448]=1,[460]=1,[475]=1,[479]=5,[487]=1,[492]=1,
  }

  local sheets, icons = {}, {}
  local function iconSlot(nat)
    local slot = nat
    for species, count in pairs(extra) do
      if species < nat then slot = slot + count end
    end
    if nat == 385 or nat == 386 then slot = slot + 1 end
    return slot
  end

  local function getSheet(shiny)
    local key = shiny and "shiny" or "normal"
    if sheets[key] then return sheets[key] end
    local file = shiny and "assets/party_icons_shiny.png" or "assets/party_icons.png"
    local ok, img = pcall(mod.assets.image, mod.assets, file)
    if not ok or not img then
      mod.log:warn("Could not load party icon sheet: " .. file)
      return nil
    end
    if img.setFilter then img:setFilter("nearest", "nearest") end
    sheets[key] = img
    return img
  end

  local function sheetIcon(mon)
    if not mon or (Pokemon.isEgg and Pokemon.isEgg(mon)) then return nil end
    local species = Pokemon.monPicSpecies and Pokemon.monPicSpecies(mon)
    local nat = species and Pokemon.national and tonumber(Pokemon.national(species))
    if not nat or nat < 1 or nat > 493 then return nil end
    local shiny = Pokemon.isShiny and Pokemon.isShiny(mon) or false
    local key = (shiny and "s" or "n") .. nat
    if icons[key] then return icons[key] end

    local sheet = getSheet(shiny)
    if not sheet then return nil end
    local sw, sh = sheet:getDimensions()
    local index = iconSlot(nat) - 1
    local x, y = (index % COLS) * W, math.floor(index / COLS) * H
    if x + W > sw or y + H > sh then return nil end
    -- Center 40px source art in the 32px party icon slot.
    local quad = love.graphics.newQuad(x + 4, y, 32, H, sw, sh)
    local icon = {
      image = sheet, w = 32, h = H, sheetH = sh,
      frames = 2, quads = { [0] = quad, [1] = quad },
      trueColor = true, gen3PartyIconSheet = true,
    }
    icons[key] = icon
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
    if sprite and (sprite.image == sheets.normal or sprite.image == sheets.shiny)
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
  mod.log:info("Gen 3 Party Icons: direct sprite-sheet quads active")
end
