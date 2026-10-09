from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXTRA = {3:1,6:2,9:1,65:1,94:1,115:1,127:1,130:1,142:1,150:2,181:1,201:27,212:1,229:1,248:1,254:1,257:1,260:1,282:1,303:1,306:1,308:1,310:1,354:1,359:1,362:1,373:1,376:1,386:4,412:2,413:2,422:1,423:1,428:1,445:1,448:1,460:1,475:1,479:5,487:1,492:1}
for variant, name in (("normal", "party_icons.png"), ("shiny", "party_icons_shiny.png")):
    source = ROOT / "assets" / name
    if not source.exists():
        raise SystemExit(f"Missing {source}")
    sheet = Image.open(source).convert("RGBA")
    if sheet.width % 40 or sheet.height % 30:
        raise SystemExit(f"Unexpected sheet dimensions: {sheet.size}")
    columns = sheet.width // 40
    out = ROOT / "assets" / "icons" / variant
    out.mkdir(parents=True, exist_ok=True)
    for nat in range(1, 494):
        slot = nat + sum(count for species, count in EXTRA.items() if species < nat)
        if nat in (385, 386):
            slot += 1
        index = slot - 1
        x, y = (index % columns) * 40, (index // columns) * 30
        if x + 40 > sheet.width or y + 30 > sheet.height:
            raise SystemExit(f"Missing {variant} sprite for #{nat} at slot {slot}")
        icon = sheet.crop((x, y, x + 40, y + 30))
        icon.save(out / f"{nat:03d}.png", optimize=True)
print("Generated normal and shiny icons for National Dex #001-493")
