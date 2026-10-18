-- Appended to the scripts that drop nuggets: each one loads a different flag's copy of its entity
local flags = dofile_once("mods/pride_gold/files/flags.lua")
local PICKUP = "data/entities/items/pickup/"
local PAINTED = "mods/pride_gold/files/painted/"

local variants = {}
for _, n in ipairs(dofile_once("mods/pride_gold/files/nuggets.lua")) do
	variants[PICKUP .. n[1]] = n[1]
	if n[4] then
		variants[PICKUP .. n[4]] = n[4]
	end
end

local seeded = false

local function next_flag(x, y)
	if not seeded then
		math.randomseed(GameGetFrameNum() * 1000003 + x * 31 + y)
		seeded = true
	end
	local last = GlobalsGetValue("pride_gold.last_flag", ModSettingGet("pride_gold.painted") or "")
	local index = 1
	for i, f in ipairs(flags) do
		if f.id == last then
			index = i
		end
	end
	local id = flags[(index - 1 + math.random(#flags - 1)) % #flags + 1].id
	GlobalsSetValue("pride_gold.last_flag", id)
	return id
end

local function variant(entity_filename, x, y)
	local file = variants[entity_filename]
	if file then
		return PAINTED .. next_flag(x, y) .. "/" .. file
	end
	return entity_filename
end

if load_gold_entity then
	local load_gold_entity_unpainted = load_gold_entity
	function load_gold_entity(entity_filename, x, y, ...)
		return load_gold_entity_unpainted(variant(entity_filename, x, y), x, y, ...)
	end
end

if shoot_projectile then
	local shoot_projectile_unpainted = shoot_projectile
	function shoot_projectile(who_shot, entity_file, x, y, ...)
		return shoot_projectile_unpainted(who_shot, variant(entity_file, x, y), x, y, ...)
	end
end
