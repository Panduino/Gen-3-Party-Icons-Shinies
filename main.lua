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
  local extras={
    [3]=1,[6]=2,[9]=1,[65]=1,[94]=1,[115]=1,[127]=1,[130]=1,[142]=1,[150]=2,
    [181]=1,[201]=27,[212]=1,[229]=1,[248]=1,[254]=1,[257]=1,[260]=1,
    [282]=1,[303]=1,[306]=1,[308]=1,[310]=1,[354]=1,[359]=1,[362]=1,
    [373]=1,[376]=1,[386]=4,[412]=2,[413]=2,[422]=1,[423]=1,[428]=1,
    [445]=1,[448]=1,[460]=1,[475]=1,[479]=5,[487]=1,[492]=1,
  }
  local atlases={}
  local function atlasSlot(nat)
    local slot=nat
    for species,count in pairs(extras) do
      if species<nat then slot=slot+count end
    end
    return slot
  end
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
    local slot=atlasSlot(nat)+form-1
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
    local species = Pokemon.monPicSpecies and Pokemon.monPicSpecies(mon)
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

  -- Debug: preview all National Dex icons in PC storage, 420 at a time.
  -- The original PC contents are retained in memory and restored when
  -- the toggle is turned off. Do not save while preview is active.
  mod.options:define({
    {key="debug_all_icons",label="DEBUG: FILL PC WITH ICON TEST POKEMON",type="toggle",default=false},
    {key="debug_next_batch",label="DEBUG: NEXT ICON TEST BATCH",type="toggle",default=false},
  })
  local GameRuntime=require("src.core.game3.runtime")
  local Storage=require("src.core.game3.storage")
  local previewSession,originalBoxes,previewBatch,wasEnabled,wasNext
  local function debugTick()
    local ok,s=pcall(GameRuntime.getSession)
    if not ok or not s then return end
    local enabled=mod.options:get("debug_all_icons")
    local nextBatch=mod.options:get("debug_next_batch")
    if previewSession and (not enabled or s~=previewSession) then
      if previewSession.storage and originalBoxes then
        previewSession.storage.boxes=originalBoxes
      end
      previewSession,originalBoxes,previewBatch=nil,nil,nil
      mod.log:info("Icon debug: original PC boxes restored")
    end
    if enabled and (not previewSession or (nextBatch and not wasNext)) then
      local storage=Storage.ensure(s)
      if not previewSession then
        previewSession=s
        originalBoxes=storage.boxes
        previewBatch=0
      else
        previewBatch=previewBatch+1
      end
      local boxes=Storage.new().boxes
      local first=previewBatch*420+1
      local last=math.min(first+419,493)
      if first>493 then
        previewBatch=0
        first,last=1,420
      end
      for nat=first,last do
        local species=Pokemon.speciesFromNational(nat)
        if species then
          local pos=nat-first
          local mon={
            species=species,speciesNumbering=Pokemon.NUMBERING_INTERNAL,level=5,personality=nat*10007,
            ivs={},evs={},moves={},hp=20,maxHp=20,
          }
          boxes[math.floor(pos/30)+1].mons[pos%30+1]=mon
        end
      end
      storage.boxes=boxes
      storage.currentBox=1
      mod.log:info("Icon debug: stored "..tostring(Storage.countTotalMons(storage)).." preview Pokemon")
      mod.log:info(("Icon debug: displaying species %d-%d in PC"):format(first,last))
    end
    wasEnabled,wasNext=enabled,nextBatch
  end
  -- Options are changed in the mod settings menu, not on map entry.
  -- Poll at runtime so switching either toggle actually applies immediately.
  -- Hook the actual PC opening path as well: engine callers may cache
  -- GameRuntime.update before a mod wraps it.
  local BoxUI=require("src.ui.game3.box_storage_ui")
  local originalBoxShow=BoxUI.show
  BoxUI.show=function(...)
    local ok,err=pcall(debugTick)
    if not ok then mod.log:error("Icon debug on PC open: "..tostring(err)) end
    return originalBoxShow(...)
  end
  local originalRuntimeUpdate=GameRuntime.update
  GameRuntime.update=function(...)
    local result=originalRuntimeUpdate(...)
    local ok,err=pcall(debugTick)
    if not ok then mod.log:error("Icon debug: "..tostring(err)) end
    return result
  end
  if mod.events and mod.events.on then
    mod.events:on("game.ready",debugTick)
    mod.events:on("world.mapEnter",debugTick)
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
