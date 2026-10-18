"""Paints every flag's nugget images into pride_gold/files/painted/, then renders a preview
of all graphics and the XML changes using the real game data, no Noita needed.

  python preview.py --game "<folder containing data/>" [--assets]
"""
import argparse, difflib, os, re, shutil
from PIL import Image, ImageDraw
from lupa import luajit21

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE) + os.sep
OUT = os.path.join(HERE, "out") + os.sep
MOD_PREFIX = "mods/pride_gold/"


def lua_env(game, settings):
    """Lua state with the Mod* API faked; returns (lua, images, changed_text_files, printed_lines, real_path)."""
    def real_path(p):
        return MOD + p[len(MOD_PREFIX):] if p.startswith(MOD_PREFIX) else os.path.join(game, p)

    L = luajit21.LuaRuntime(unpack_returned_tuples=True)
    images, ids, texts, log, appends = {}, [], {}, [], []

    def make_editable(path, w, h):
        if path not in images:
            if os.path.exists(real_path(path)):
                images[path] = Image.open(real_path(path)).convert("RGBA")
            elif w > 0:
                images[path] = Image.new("RGBA", (int(w), int(h)), (0, 0, 0, 0))
            else:
                return 0, 0, 0
            ids.append(path)
        img = images[path]
        return ids.index(path) + 1, img.width, img.height

    def get_pixel(i, x, y):
        r, g, b, a = images[ids[i - 1]].getpixel((int(x), int(y)))
        return r | g << 8 | b << 16 | a << 24

    def set_pixel(i, x, y, c):
        c = int(c) & 0xFFFFFFFF
        images[ids[i - 1]].putpixel((int(x), int(y)), (c & 255, c >> 8 & 255, c >> 16 & 255, c >> 24 & 255))

    def get_text(p):
        if p in texts:
            return texts[p]
        rp = real_path(p)
        return open(rp, encoding="utf-8", errors="replace").read() if os.path.exists(rp) else None

    g = L.globals()
    g.ModImageMakeEditable = make_editable
    g.ModImageGetPixel = get_pixel
    g.ModImageSetPixel = set_pixel
    g.ModTextFileGetContent = get_text
    g.ModTextFileSetContent = lambda p, s: texts.__setitem__(p, s)
    g.ModSettingGet = lambda k: settings.get(k.split(".", 1)[1])
    g.ModSettingSet = lambda k, v: None
    g.ModLuaFileAppend = lambda target, path: appends.append((target, path))
    g.ModSettingSetNextValue = lambda k, v, d: None
    g.GameGetDateAndTimeUTC = lambda: (2026, 1, 1, 0, 0, 0)
    g.GameGetRealWorldTimeSinceStarted = lambda: 0
    g.print = lambda *a: log.append(" ".join(str(x) for x in a))
    lua_dofile = L.eval("dofile")
    g.dofile = lambda p: lua_dofile(real_path(p))
    L.execute("""
        local cache = {}
        function dofile_once(p)
            if cache[p] == nil then cache[p] = dofile(p) or true end
            return cache[p]
        end
    """)
    return L, images, texts, log, real_path


def run_init(game, settings):
    """Runs init.lua; returns (images, changed_text_files, printed_lines, real_path)."""
    L, images, texts, log, real_path = lua_env(game, settings)
    L.execute(open(MOD + "init.lua").read())
    return images, texts, log, real_path


PAINTED = "files/painted/"


def bake(game):
    """Paints every flag's nuggets with paint.lua and saves them where init.lua points the game."""
    L, images, _, log, real_path = lua_env(game, {})
    L.execute("""
        local root = "mods/pride_gold/files/"
        local paint = dofile_once(root .. "paint.lua")
        for _, flag in ipairs(dofile_once(root .. "flags.lua")) do
            local colors = paint.colors(flag)
            for _, n in ipairs(dofile_once(root .. "nuggets.lua")) do
                local src = paint.read(n[2])
                local name = root .. "painted/" .. flag.id .. "/" .. n[2]:match("([^/]+)%.png$")
                paint.body(src, name .. ".png", colors, n[3], false)
                if n[4] then
                    paint.body(src, name .. "_blood.png", colors, n[3], true)
                end
            end
        end
    """)
    shutil.rmtree(MOD + PAINTED, ignore_errors=True)
    for path, img in images.items():
        if path.startswith(MOD_PREFIX + PAINTED):
            os.makedirs(os.path.dirname(real_path(path)), exist_ok=True)
            img.save(real_path(path))
    if log:
        print(*log, sep="\n")


def flag_ids():
    return re.findall(r'id = "(\w+)"', open(MOD + "files/flags.lua").read())


SHAPES = ["goldnugget_01", "goldnugget_6px", "goldnugget_9px", "goldnugget_12px", "goldnugget_20px",
          "golden_idol", "golden_idol_big", "gold_reward_sprite"]


def painted(flag, name):
    return Image.open(MOD + PAINTED + flag + "/" + name + ".png").convert("RGBA")


def scaled(img, s):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


def contact_sheet(game, path):
    scale, rows = 4, []
    for flag in flag_ids():
        images, _, log, _ = run_init(game, {"flag": flag})
        if log:
            print(flag, *log, sep="\n  ")
        parts = [painted(flag, n) for n in SHAPES] + [painted(flag, n + "_blood") for n in SHAPES[1:]]
        parts += [images["data/materials_gfx/gold.png"], images["data/materials_gfx/gold_dark.png"],
                  images["data/ui_gfx/hud/money.png"], images["data/ui_gfx/items/goldnugget.png"]]
        rows.append((flag, parts))
    width = 110 + sum(p.width * scale + 6 for p in rows[0][1])
    height = sum(max(p.height for p in r) * scale + 6 for _, r in rows)
    sheet = Image.new("RGBA", (width, height), (38, 34, 44, 255))
    draw, y = ImageDraw.Draw(sheet), 0
    for flag, parts in rows:
        draw.text((4, y + 4), flag, fill=(230, 230, 230, 255))
        x = 110
        for p in parts:
            q = scaled(p, scale)
            sheet.paste(q, (x, y), q)
            x += q.width + 6
        y += max(p.height for p in parts) * scale + 6
    sheet.save(path)


def change_log(game, path):
    _, texts, log, real_path = run_init(game, {})
    with open(path, "w") as out:
        for line in log:
            out.write(line + "\n")
        for p, new in sorted(texts.items()):
            old = open(real_path(p), encoding="utf-8", errors="replace").read()
            out.write("== %s\n" % p)
            for l in difflib.unified_diff(old.splitlines(), new.splitlines(), lineterm="", n=0):
                if l[:1] in "+-" and l[:3] not in ("+++", "---"):
                    out.write(l + "\n")


def assets(game):
    icon = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    nugget = painted("rainbow", "goldnugget_20px")
    icon.paste(nugget, (0, 0), nugget)
    icon.save(MOD + "icon.png")

    # 16:9 Workshop image: one big nugget per flag, blood money in the corner.
    preview = Image.new("RGBA", (1920, 1080), (30, 26, 36, 255))
    flags = flag_ids()
    cols, cell = 7, 240
    left = (1920 - cols * cell) // 2
    for i, flag in enumerate(flags):
        q = scaled(painted(flag, "goldnugget_20px"), 10)
        x, y = left + (i % cols) * cell + (cell - q.width) // 2, 200 + (i // cols) * 340
        preview.paste(q, (x, y), q)
        b = scaled(painted(flag, "goldnugget_20px_blood"), 5)
        preview.paste(b, (x + q.width - b.width // 2, y + q.height - b.height // 2), b)
    preview.convert("RGB").save(MOD + "workshop_preview_image.png")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--game", required=True, help="folder containing the unpacked data/ folder")
    ap.add_argument("--assets", action="store_true", help="also regenerate icon.png and workshop_preview_image.png")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    bake(args.game)
    contact_sheet(args.game, OUT + "sheet.png")
    change_log(args.game, OUT + "changes.txt")
    if args.assets:
        assets(args.game)
    print("Wrote", OUT)
