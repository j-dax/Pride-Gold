dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "pride_gold"
mod_settings_version = 1

local RESTART = MOD_SETTING_SCOPE_RUNTIME_RESTART

mod_settings = {
	{
		id = "blood_money",
		ui_name = "Blood money",
		ui_description = "How the healing nuggets from the Blood Money perk look.",
		value_default = "outline",
		values = { { "outline", "Flag with red outline" }, { "vanilla", "Unchanged" } },
		scope = RESTART,
	},
	{
		id = "flag",
		ui_name = "Flag",
		ui_description = "Which pride flag gold is painted with. Applies after restarting the game.",
		value_default = "trans",
		values = {
			{ "trans", "Transgender" },
			{ "rainbow", "Rainbow" },
			{ "bi", "Bisexual" },
			{ "pan", "Pansexual" },
			{ "nonbinary", "Non-binary" },
			{ "lesbian", "Lesbian" },
			{ "gay", "Gay (MLM)" },
			{ "asexual", "Asexual" },
			{ "aromantic", "Aromantic" },
			{ "aroace", "Aroace" },
			{ "genderfluid", "Genderfluid" },
			{ "genderqueer", "Genderqueer" },
			{ "agender", "Agender" },
			{ "polysexual", "Polysexual" },
		},
		scope = RESTART,
	},
	{
		id = "glow",
		ui_name = "Gold glow",
		ui_description = "Keep the glow on gold nuggets. Turning it off makes pale stripes easier to see.",
		value_default = true,
		scope = RESTART,
	},
	{
		id = "icons",
		ui_name = "Gold icons",
		ui_description = "Paint the gold counter icon and the nugget item icon.",
		value_default = true,
		scope = RESTART,
	},
	{
		id = "gold_material",
		ui_name = "Gold material",
		ui_description = "Paint gold dust, gold veins and molten gold with the flag.",
		value_default = true,
		scope = RESTART,
	},
	{
		id = "nuggets",
		ui_name = "Gold nuggets",
		ui_description = "Paint gold nuggets, idols and the gold statue with the flag.",
		value_default = true,
		scope = RESTART,
	},
	{
		id = "random_flag",
		ui_name = "Random flag",
		ui_description = "Switch to a different random flag each time Noita is launched. New games keep the current flag.",
		value_default = false,
		scope = RESTART,
	},
	{
		id = "random_nuggets",
		ui_name = "Random nugget flags",
		ui_description = "Paint each nugget and blood money dropped by enemies, chests, eggs and gold orbs with a different random flag. The gold counter keeps the main flag.",
		value_default = false,
		scope = RESTART,
	},
}

function ModSettingsUpdate(init_scope)
	mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
	return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
	mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end
