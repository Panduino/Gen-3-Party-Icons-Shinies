return function(mod)
  if mod.generation ~= 3 then return end

  local Pokemon = require("src.core.game3.pokemon")
  local COLS, W, H = 32, 40, 30
  local extra = {
    [3]=1,[6]=2,[9]=1,[65]=1,[94]=1,[115]=1,[127]=1,[130]=1,[142]=1,[150]=2,
    [181]=1,[201]=27,[212]=1,[229]=1,[248]=1,[254]=1,[257]=1,[260]=1,
    [282]=1,[303]=1,[306]=1,[308]=1,[310]=1,[354]=1,[359]=1,[362]=1,
    [373]=1,[376]=1,[386]=4,[412]=2,[413]=2,[422]=1,[423]=1,[428]=1,
    [445]=1,[448]=1,[460]=1,[475]=1,[479]=5,[487]=1,[492]=1,
  }
  local sheets = {}

  local function slotFor(nat)
    local slot = nat
    for species, count in pairs(extra) do
      if species < nat then slot = slot + count end
    end
    if nat == 385 or nat == 386 then slot = slot + 1 end
    return slot
  end

  local function sheetFor(shiny)
    local key = shiny and "shiny" or "normal"
    if sheets[key] then return sheets[key] end
    local file = shiny and "assets/party_icons_shiny.png" or "assets/party_icons.png"
    local ok, data = pcall(love.image.newImageData, mod.assets:path(file))
    if not ok or not data then return nil end
    sheets[key] = data
    return data
  end

  -- The current engine's pokemon.icon hook expects a *path*, not a
  -- sprite descriptor. Crop the requested 40x30 cell in memory and
  -- expose it as a virtual PNG path. No individual files are shipped.
  local cache = {}
  local function iconPath(nat, shiny)
    local key = (shiny and "s" or "n") .. nat
    if cache[key] then return cache[key] end
    local sheet = sheetFor(shiny)
    if not sheet then return nil end
    local slot = slotFor(nat) - 1
    local x, y = (slot % COLS) * W, math.floor(slot / COLS) * H
    if x + W > sheet:getWidth() or y + H > sheet:getHeight() then return nil end

    -- Engine icon loader clamps width to 32px. Keep the original 40px
    -- artwork centered within a 32x30 icon instead of shifting the crop.
    local out = love.image.newImageData(32, 30)
    out:paste(sheet, 0, 0, x + 4, y, 32, 30)
    local path = ("gen3_party_icon_%s_%03d.png"):format(shiny and "s" or "n", nat)
    local ok, bytes = pcall(function() return out:encode("png"):getString() end)
    if not ok then return nil end
    if not (love.filesystem and love.filesystem.write and love.filesystem.write(path, bytes)) then return nil end
    cache[key] = path
    return path
  end

  mod.hooks:wrap("pokemon.icon", function(next, path, ctx)
    local original = next(path, ctx)
    if not ctx or not ctx.mon then return original end
    local nat = Pokemon.national and tonumber(Pokemon.national(ctx.gen3Species))
    if not nat or nat < 1 or nat > 493 then return original end
    local shiny = Pokemon.isShiny and Pokemon.isShiny(ctx.mon) or false
    return iconPath(nat, shiny) or original
  end)

  mod.log:info("Gen 3 Party Icons: sprite sheet icon hook active")
end
