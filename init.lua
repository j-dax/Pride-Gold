local ROOT = "mods/pride_gold/files/"
local flags = dofile_once(ROOT .. "flags.lua")
local paint = dofile_once(ROOT .. "paint.lua")
local nuggets = dofile_once(ROOT .. "nuggets.lua")

local PICKUP = "data/entities/items/pickup/"

local function setting(id, default)
	local value = ModSettingGet("pride_gold." .. id)
	if value == nil then
		return default
	end
	return value
end

local function edit(path, fn)
	ModTextFileSetContent(path, fn(ModTextFileGetContent(path)))
end

local function utc_seconds()
	local y, m, d, h, mi, s = GameGetDateAndTimeUTC()
	if m <= 2 then
		y = y - 1
	end
	local days = y * 365 + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400)
		+ math.floor((153 * ((m + 9) % 12) + 2) / 5) + d
	return ((days * 24 + h) * 60 + mi) * 60 + s
end

-- Painted images stay cached until Noita is relaunched, so keep one flag per launch
local launch = utc_seconds() - GameGetRealWorldTimeSinceStarted()
local same_launch = math.abs(launch - setting("launch", -1e9)) <= 2

local flag = flags[1]
local index = 1
local wanted = same_launch and setting("painted", nil) or setting("flag", "trans")
for i, f in ipairs(flags) do
	if f.id == wanted then
		index = i
		flag = f
	end
end
if setting("random_flag", false) and not same_launch then
	flag = flags[(index - 1 + math.random(#flags - 1)) % #flags + 1]
	ModSettingSetNextValue("pride_gold.flag", flag.id, false)
end
ModSettingSet("pride_gold.launch", launch)
ModSettingSet("pride_gold.painted", flag.id)

local colors = paint.colors(flag)
local recolor_nuggets = setting("nuggets", true)
local blood_mode = setting("blood_money", "outline")

edit("data/materials.xml", function(xml)
	if recolor_nuggets then
		xml = xml:gsub('(name="gold_box2d".-<Graphics)', '%1 normal_mapped="0"', 1)
		if not setting("glow", true) then
			xml = xml:gsub('(name="gold_box2d".-)gfx_glow_color', '%1gfx_glow="0" gfx_glow_color', 1)
		end
	end
	if blood_mode == "outline" then
		xml = xml:gsub('(name="bloodgold_box2d".-<Graphics)', '%1 normal_mapped="0"', 1)
	end
	return xml
end)

local random_nuggets = recolor_nuggets and setting("random_nuggets", false)

for _, n in ipairs(nuggets) do
	local file, image, blood_file = n[1], n[2], n[4]
	local xml = ModTextFileGetContent(PICKUP .. file)
	local blood_xml = blood_file and ModTextFileGetContent(PICKUP .. blood_file)

	local function write(dir, id)
		local name = ROOT .. "painted/" .. id .. "/" .. image:match("([^/]+)%.png$")
		if recolor_nuggets then
			ModTextFileSetContent(dir .. file, (xml:gsub(image, name .. ".png")))
		end

		local blood_image
		if blood_mode == "outline" then
			blood_image = name .. "_blood.png"
		elseif recolor_nuggets then
			blood_image = image
		end
		if blood_xml and blood_image then
			ModTextFileSetContent(
				dir .. blood_file,
				(
					blood_xml:gsub(
						'material="bloodgold_box2d"',
						'image_file="' .. blood_image .. '" material="bloodgold_box2d"',
						1
					)
				)
			)
		end
	end

	write(PICKUP, flag.id)
	if random_nuggets then
		for _, f in ipairs(flags) do
			write(ROOT .. "painted/" .. f.id .. "/", f.id)
		end
	end
end

if random_nuggets then
	ModLuaFileAppend("data/scripts/game_helpers.lua", ROOT .. "drops.lua")
end

if setting("gold_material", true) then
	paint.recolor("data/materials_gfx/gold.png", colors, 1.0, true)
	paint.recolor("data/materials_gfx/gold_dark.png", colors, 0.7, true)
end

if setting("icons", true) then
	paint.recolor("data/ui_gfx/hud/money.png", colors, 0.8, false)
	paint.recolor("data/ui_gfx/items/goldnugget.png", colors, 1.0, false)
end
