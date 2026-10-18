local ROOT = "mods/pride_gold/files/"
local flags = dofile_once(ROOT .. "flags.lua")
local paint = dofile_once(ROOT .. "paint.lua")

local PICKUP = "data/entities/items/pickup/"

local NUGGETS = {
	{ "goldnugget.xml", "data/items_gfx/goldnugget_01.png", "normal" },
	{ "goldnugget_10.xml", "data/items_gfx/goldnugget_6px.png", "normal", "bloodmoney_10.xml" },
	{ "goldnugget_50.xml", "data/items_gfx/goldnugget_9px.png", "normal", "bloodmoney_50.xml" },
	{ "goldnugget_200.xml", "data/items_gfx/goldnugget_12px.png", "normal", "bloodmoney_200.xml" },
	{ "goldnugget_1000.xml", "data/items_gfx/goldnugget_20px.png", "normal", "bloodmoney_1000.xml" },
	{ "goldnugget_10000.xml", "data/items_gfx/easter/golden_idol.png", "color", "bloodmoney_10000.xml" },
	{ "goldnugget_200000.xml", "data/items_gfx/easter/golden_idol_big.png", "normal", "bloodmoney_200000.xml" },
	{
		"goldnugget_x.xml",
		"data/entities/animals/boss_centipede/rewards/gold_reward_sprite.png",
		"color",
		"bloodmoney_x.xml",
	},
}

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

for _, n in ipairs(NUGGETS) do
	local file, image, kind, blood_file = n[1], n[2], n[3], n[4]
	local src = paint.read(image)
	local name = ROOT .. "generated/" .. image:match("([^/]+)%.png$")

	if src and recolor_nuggets then
		paint.body(src, name .. ".png", colors, kind, false)
		edit(PICKUP .. file, function(xml)
			return (xml:gsub(image, name .. ".png"))
		end)
	end

	local blood_image
	if src and blood_mode == "outline" then
		blood_image = name .. "_blood.png"
		paint.body(src, blood_image, colors, kind, true)
	elseif recolor_nuggets then
		blood_image = image
	end
	if blood_file and blood_image then
		edit(PICKUP .. blood_file, function(xml)
			return (
				xml:gsub(
					'material="bloodgold_box2d"',
					'image_file="' .. blood_image .. '" material="bloodgold_box2d"',
					1
				)
			)
		end)
	end
end

if setting("gold_material", true) then
	paint.recolor("data/materials_gfx/gold.png", colors, 1.0, true)
	paint.recolor("data/materials_gfx/gold_dark.png", colors, 0.7, true)
end

if setting("icons", true) then
	paint.recolor("data/ui_gfx/hud/money.png", colors, 0.8, false)
	paint.recolor("data/ui_gfx/items/goldnugget.png", colors, 1.0, false)
end
