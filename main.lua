return function(mod)
  if mod.generation ~= 3 then return end

  local Pokemon = require("src.core.game3.pokemon")
  -- Use the individually numbered PokéSprite files instead of the packed
  -- atlas. The atlas interleaves alternate forms, which caused wrong icons
  -- (notably Treecko/Celebi) whenever a form count was off.
  local icons, iconImages = {}, setmetatable({}, {__mode = "k"})

  -- Alternate-form artwork is stored in the original 32-column atlas.
  -- Base species still use individually numbered PNGs, avoiding offset drift.
  local W,H,COLS=40,30,32
  -- Explicit 1-based atlas positions supplied by the sheet author.
  -- The remaining positions are filled in National Pokédex order.
  local extraPositions={
    4,8,9,13,70,100,122,135,139,152,161,162,194,
    214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,
    253,256,272,292,302,328,350,354,357,360,
    402,403,404,408,414,436,438,444,445,446,
    473,474,476,477,488,490,513,517,530,
    550,551,552,553,554,564,570,
  }
  local formPositions={
    [3]={4},[6]={8,9},[9]={13},[65]={70},[94]={100},
    [115]={122},[127]={135},[130]={139},[142]={152},
    [150]={161,162},[181]={194},
    [201]={},[212]={253},[214]={256},[229]={272},[248]={292},
    [257]={302},[282]={328},[303]={350},[306]={354},
    [308]={357},[310]={360},[351]={402,403,404},
    [354]={408},[359]={414},[380]={436},[381]={438},
    [386]={444,445,446},[412]={473,474},[413]={476,477},
    [422]={488},[423]={490},[445]={513},[448]={517},
    [460]={530},[479]={550,551,552,553,554},
    [487]={564},[492]={570},
  }
  -- Unown base is row 7 col 21 (slot 213); its 27 other forms
  -- occupy slots 214-240. Wobbuffet follows at slot 241.
  for slot=214,240 do formPositions[201][#formPositions[201]+1]=slot end
  local extras={}
  for nat,positions in pairs(formPositions) do extras[nat]=#positions end
  local isExtra={}
  for _,slot in ipairs(extraPositions) do
    assert(slot>=1 and slot<=576 and not isExtra[slot],"Duplicate/out-of-range extra slot "..slot)
    isExtra[slot]=true
  end
  local baseSlots={}
  local national=0
  for slot=1,576 do
    if not isExtra[slot] then
      national=national+1
      if national<=493 then baseSlots[national]=slot end
    end
  end
  assert(national>=493,"Not enough base sprite positions for National Dex")
  local atlases={}
  local function atlasSlot(nat) return baseSlots[nat] end
  local function formIndex(mon,nat)
    if nat==201 and Pokemon.unownLetter then
      return Pokemon.unownLetter(mon.personality)
    end
    local f=tonumber(mon.form or mon.formId or mon.formIndex or mon.alternateForm)
    if f and f>=1 and f<=(extras[nat] or 0) then return f end
    return 0
  end
  local function formIcon(nat,form,shiny)
    local key=(shiny and "s" or "n")..nat..":"..form
    if icons[key] then return icons[key] end
    local atlasKey=shiny and "shiny" or "normal"
    local img=atlases[atlasKey]
    if not img then
      local path=shiny and "assets/party_icons_shiny.png" or "assets/party_icons.png"
      local ok,result=pcall(mod.assets.image,mod.assets,path)
      if not ok or not result then return nil end
      img=result
      if img.setFilter then img:setFilter("nearest","nearest") end
      atlases[atlasKey]=img
    end
    local sw,sh=img:getDimensions()
    local slot=(formPositions[nat] or {})[form]
    if not slot then return nil end
    slot=slot-1
    local x,y=(slot%COLS)*W,math.floor(slot/COLS)*H
    if x+W>sw or y+H>sh then return nil end
    local quad=love.graphics.newQuad(x+4,y,32,H,sw,sh)
    local icon={image=img,w=32,h=H,sheetH=sh,frames=2,
      quads={[0]=quad,[1]=quad},trueColor=true,gen3PartyIconSheet=true}
    icons[key]=icon
    iconImages[img]=true
    return icon
  end

  -- Full National Dex mapping uses the packed sheet's explicit insertion
  -- counts, rather than assuming 001.png ... 493.png are National IDs.
  -- The latter are merely the first 493 artwork slots (including forms).
  -- Every National species and alternate form is therefore addressed from
  -- its position in the complete atlas, including species after slot 493.
  local function baseIcon(nat,shiny)
    local key=(shiny and "s" or "n")..nat..":base"
    if icons[key] then return icons[key] end
    local atlasKey=shiny and "shiny" or "normal"
    local img=atlases[atlasKey]
    if not img then
      local path=shiny and "assets/party_icons_shiny.png" or "assets/party_icons.png"
      local ok,result=pcall(mod.assets.image,mod.assets,path)
      if not ok or not result then return nil end
      img=result
      if img.setFilter then img:setFilter("nearest","nearest") end
      atlases[atlasKey]=img
    end
    local sw,sh=img:getDimensions()
    local slot=atlasSlot(nat)-1
    local x,y=(slot%COLS)*W,math.floor(slot/COLS)*H
    if x+W>sw or y+H>sh then return nil end
    local quad=love.graphics.newQuad(x+4,y,32,H,sw,sh)
    local icon={image=img,w=32,h=H,sheetH=sh,frames=2,
      quads={[0]=quad,[1]=quad},trueColor=true,gen3PartyIconSheet=true}
    icons[key]=icon
    iconImages[img]=true
    return icon
  end
  local function sheetIcon(mon)
    if not mon or (Pokemon.isEgg and Pokemon.isEgg(mon)) then return nil end
    -- Resolve the underlying species first: monPicSpecies changes Unown
    -- into an internal letter species which need not have a Dex mapping.
    local species = Pokemon.speciesOf and Pokemon.speciesOf(mon)
    local nat = species and Pokemon.national and tonumber(Pokemon.national(species))
    if not nat or nat < 1 or nat > 493 then return nil end

    local shiny = Pokemon.isShiny and Pokemon.isShiny(mon) or false
    local form=formIndex(mon,nat)
    if form>0 then
      local alternate=formIcon(nat,form,shiny)
      if alternate then return alternate end
    end
    return baseIcon(nat,shiny)
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
