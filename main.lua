return function(mod)
  if mod.generation ~= 3 then return end
  local Pokemon = require("src.core.game3.pokemon")
  local function nativeToNational(species)
    return Pokemon.national and tonumber(Pokemon.national(species))
  end
  mod.hooks:wrap("pokemon.icon", function(next, path, ctx)
    local original = next(path, ctx)
    if not ctx or not ctx.mon then return original end
    local nat = nativeToNational(ctx.gen3Species or (ctx.mon and ctx.mon.species))
    if not nat or nat < 1 or nat > 493 then return original end
    local shiny = Pokemon.isShiny and Pokemon.isShiny(ctx.mon)
    local file = ("assets/icons/%s/%03d.png"):format(shiny and "shiny" or "normal", nat)
    if not (mod.assets and mod.assets.info and mod.assets:info(file)) then
      return original
    end
    ctx.trueColor = true
    return mod.assets:path(file)
  end)
  mod.log:info("Gen 3 Party Icons: pokemon.icon hook registered")
end
