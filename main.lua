return function(mod)
  if mod.generation ~= 3 then return end

  local okPokemon, Pokemon = pcall(require, "src.core.game3.pokemon")
  if not okPokemon or type(Pokemon) ~= "table" then
    mod.log:error("Gen 3 Pokemon renderer is unavailable")
    return
  end

  local originalMonIcon = Pokemon.monIcon
  if type(originalMonIcon) ~= "function" then
    mod.log:error("Gen 3 party icon renderer is unavailable")
    return
  end

  local PARTY_ICON_W, PARTY_ICON_H, PARTY_ICON_COLS = 40, 30, 32
  local iconSheets = {}

  -- Extra cells inserted after each National Dex species in the authored
  -- icon sheet. This mapping is the verified layout used by the original
  -- Gen 3 G9 adapter; Turtwig (#387) begins at sheet slot 447.
  local extraCells = {
    [3]=1,[6]=2,[9]=1,[65]=1,[94]=1,[115]=1,[127]=1,[130]=1,[142]=1,[150]=2,
    [181]=1,[201]=27,[212]=1,[229]=1,[248]=1,
    [254]=1,[257]=1,[260]=1,[282]=1,[303]=1,[306]=1,[308]=1,[310]=1,
    [354]=1,[359]=1,[362]=1,[373]=1,[376]=1,[386]=4,
    [412]=2,[413]=2,[422]=1,[423]=1,[428]=1,[445]=1,[448]=1,[460]=1,
    [475]=1,[479]=5,[487]=1,[492]=1,
  }

  local function partyIconSlot(nat)
    nat = tonumber(nat)
    if not nat or nat < 1 or nat > 493 then return nil end
    local slot = nat
    for base, extra in pairs(extraCells) do
      if base < nat then slot = slot + extra end
    end
    -- Verified against the 32-column PNG: Rayquaza=441, Jirachi=442,\n    -- Deoxys=443-446, Turtwig=447. The authored sheet has an\n    -- additional cell before Jirachi, but the Gen 4 boundary is aligned.\n    if nat == 385 or nat == 386 then slot = slot + 1 end\n    return slot\n  end

  local function partyIconSheet(shiny)
    local key = shiny and "shiny" or "normal"
    if iconSheets[key] ~= nil then return iconSheets[key] or nil end
    iconSheets[key] = false
    if not (love and love.graphics and mod.assets and mod.assets.path) then return nil end
    local file = shiny and "assets/party_icons_shiny.png" or "assets/party_icons.png"
    local okPath, path = pcall(mod.assets.path, mod.assets, file)
    if not okPath or not path then return nil end
    local okImg, img = pcall(love.graphics.newImage, path)
    if not okImg or not img then return nil end
    img:setFilter("nearest", "nearest")
    iconSheets[key] = img
    return img
  end

  local function sheetMonIcon(mon)
    if not mon then return nil end
    local species = Pokemon.monPicSpecies and Pokemon.monPicSpecies(mon)
      or (Pokemon.speciesOf and Pokemon.speciesOf(mon))
    local nat = species and Pokemon.national and tonumber(Pokemon.national(species))
    local slot = partyIconSlot(nat)
    if not slot then return nil end

    local shiny = Pokemon.isShiny and Pokemon.isShiny(mon) or false
    local sheet = partyIconSheet(shiny)
    if not sheet then return nil end
    local sw, sh = sheet:getDimensions()
    local zero = slot - 1
    local col = zero % PARTY_ICON_COLS
    local row = math.floor(zero / PARTY_ICON_COLS)
    local x, y = col * PARTY_ICON_W, row * PARTY_ICON_H
    if x + PARTY_ICON_W > sw or y + PARTY_ICON_H > sh then return nil end

    local quad = love.graphics.newQuad(x, y, PARTY_ICON_W, PARTY_ICON_H, sw, sh)
    return {
      image = sheet,
      w = PARTY_ICON_W,
      h = PARTY_ICON_H,
      sheetH = sh,
      frames = 2,
      quads = { [0] = quad, [1] = quad },
      trueColor = true,
      gen3PartyIconSheet = true,
    }
  end

  -- New G1R Gen3Compat.reseedSprites() wraps Pokemon.monIcon again after
  -- mods initialize, overriding direct replacements. Reinstall our adapter
  -- after engine updates, while preserving its latest fallback.
  local customMonIcon
  local function installIconAdapter()
    if Pokemon.monIcon == customMonIcon then return end
    local fallback = Pokemon.monIcon
    customMonIcon = function(mon)
      return sheetMonIcon(mon) or fallback(mon)
    end
    Pokemon.monIcon = customMonIcon
  end
  installIconAdapter()

  if love and type(love.update) == "function" then
    local previousUpdate = love.update
    love.update = function(...)
      local result = previousUpdate(...)
      installIconAdapter()
      return result
    end
  end

  -- Gen3Recomp's party renderer animates the selected slot only. Animate
  -- the custom icon sheet at draw time so unselected slots move as well,
  -- without changing the game's cursor, selection, or party state.
  if love and love.graphics and type(love.graphics.draw) == "function" then
    local originalDraw = love.graphics.draw
    love.graphics.draw = function(drawable, ...)
      if drawable == iconSheets.normal or drawable == iconSheets.shiny then
        local args = { ... }
        -- Quad draws use (image, quad, x, y, ...). Do not alter non-quad
        -- calls or draw calls that do not provide numeric coordinates.
        if type(args[2]) == "number" and type(args[3]) == "number" then
          local t = love.timer and love.timer.getTime and love.timer.getTime() or 0
          local x, y = args[2], args[3]
          -- A subtle 1-pixel idle bob, staggered by the icon's screen X.
          local phase = math.floor(x / 24) * 0.55
          args[3] = y + math.floor(math.sin(t * 5 + phase) * 1.25 + 0.5)
        end
        return originalDraw(drawable, unpack(args))
      end
      return originalDraw(drawable, ...)
    end
  end

  mod.log:info("Gen 3 Party Icons active")
end
