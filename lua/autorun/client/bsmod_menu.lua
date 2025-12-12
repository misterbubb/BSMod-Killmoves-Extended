local BSMOD_VERSION = "2.1"
local HEADER_COLOR = Color(100, 180, 255)
local HELP_COLOR = Color(140, 140, 140)
local VERSION_COLOR = Color(100, 255, 100)

local function AddVersionInfo(Panel)
	local version = vgui.Create("DLabel")
	version:SetText("BSMod Fork v" .. BSMOD_VERSION)
	version:SetColor(VERSION_COLOR)
	version:SetFont("DermaDefaultBold")
	Panel:AddItem(version)
end

local function AddSectionHeader(Panel, text)
	local header = vgui.Create("DLabel")
	header:SetText(text)
	header:SetColor(HEADER_COLOR)
	header:SetFont("DermaDefaultBold")
	Panel:AddItem(header)
end

local function AddHelpText(Panel, text)
	local help = vgui.Create("DLabel")
	help:SetText(text)
	help:SetColor(HELP_COLOR)
	help:SetWrap(true)
	help:SetAutoStretchVertical(true)
	Panel:AddItem(help)
end

local function AddSpacing(Panel)
	local spacer = vgui.Create("DPanel")
	spacer:SetTall(8)
	Panel:AddItem(spacer)
end

local function BSModUserOptions(Panel)
	Panel:ClearControls()
	
	AddVersionInfo(Panel)
	AddSpacing(Panel)
	
	Panel:AddControl("ComboBox", {
		MenuButton = 1,
		Folder = "bsmod_user",
		Options = {
			["Default"] = {
				bsmod_killmove_indicator = "1",
				bsmod_killmove_key = "",
				bsmod_killmove_use_key = "0",
				bsmod_killmove_fovfx = "1",
				bsmod_killmove_fov_value = "70",
				bsmod_killmove_hide_hud = "1",
				bsmod_killmove_hide_head = "0",
				bsmod_killmove_mute_death_sounds = "0",
				bsmod_killmove_lerp_enable = "1",
				bsmod_killmove_lerp_speed = "250",
				bsmod_killmove_thirdperson = "0",
				bsmod_killmove_thirdperson_distance = "100",
				bsmod_killmove_thirdperson_pitch = "25",
				bsmod_killmove_thirdperson_yaw = "-35",
				bsmod_killmove_thirdperson_offsetup = "-15",
				bsmod_killmove_thirdperson_offsetright = "0",
				bsmod_killmove_thirdperson_randomyaw = "0",
				bsmod_killmove_thirdperson_smoothing = "1",
				bsmod_killmove_thirdperson_smoothspeed = "8",
				bsmod_killmove_thirdperson_orbit = "0",
				bsmod_killmove_thirdperson_orbitspeed = "15",
				bsmod_killmove_thirdperson_fov = "0",
				bsmod_killmove_use_chands = "0",
				bsmod_debug_calcview = "0"
			}
		},
		CVars = {
			"bsmod_killmove_indicator",
			"bsmod_killmove_key",
			"bsmod_killmove_use_key",
			"bsmod_killmove_fovfx",
			"bsmod_killmove_fov_value",
			"bsmod_killmove_hide_hud",
			"bsmod_killmove_hide_head",
			"bsmod_killmove_mute_death_sounds",
			"bsmod_killmove_lerp_enable",
			"bsmod_killmove_lerp_speed",
			"bsmod_killmove_thirdperson",
			"bsmod_killmove_thirdperson_distance",
			"bsmod_killmove_thirdperson_pitch",
			"bsmod_killmove_thirdperson_yaw",
			"bsmod_killmove_thirdperson_offsetup",
			"bsmod_killmove_thirdperson_offsetright",
			"bsmod_killmove_thirdperson_randomyaw",
			"bsmod_killmove_thirdperson_smoothing",
			"bsmod_killmove_thirdperson_smoothspeed",
			"bsmod_killmove_thirdperson_orbit",
			"bsmod_killmove_thirdperson_orbitspeed",
			"bsmod_killmove_thirdperson_fov",
			"bsmod_killmove_use_chands",
			"bsmod_debug_calcview"
		}
	})
	AddSpacing(Panel)
	
	-- Controls Section
	AddSectionHeader(Panel, "Controls")
	AddSpacing(Panel)
	
	Panel:CheckBox("Use Key (E) Triggers KillMoves", "bsmod_killmove_use_key")
	AddHelpText(Panel, "Press E on killmovable targets instead of a custom bind.")
	
	local instructionLabel = vgui.Create("DLabel")
	instructionLabel:SetText("Custom Binds:\n  bind <key> bsmod_killmove\n  bind <key> bsmod_kick")
	instructionLabel:SetColor(HELP_COLOR)
	instructionLabel:SetWrap(true)
	instructionLabel:SetAutoStretchVertical(true)
	Panel:AddItem(instructionLabel)
	AddSpacing(Panel)
	
	-- Target Indicator Section
	AddSectionHeader(Panel, "Target Indicator")
	AddSpacing(Panel)
	
	Panel:NumSlider("Indicator Mode", "bsmod_killmove_indicator", 0, 2, 0)
	AddHelpText(Panel, "0 = Off, 1 = Takedown Prompt, 2 = Icon Above Head")
	
	Panel:TextEntry("Key Display Override", "bsmod_killmove_key")
	AddHelpText(Panel, "Custom text for prompt (leave empty to auto-detect)")
	AddSpacing(Panel)
	
	-- Visual Effects Section
	AddSectionHeader(Panel, "Visual Effects")
	AddSpacing(Panel)
	
	Panel:CheckBox("FOV Effect", "bsmod_killmove_fovfx")
	Panel:NumSlider("FOV Value", "bsmod_killmove_fov_value", 50, 120, 0)
	Panel:CheckBox("Hide HUD During KillMoves", "bsmod_killmove_hide_hud")
	Panel:CheckBox("Hide Head During KillMoves", "bsmod_killmove_hide_head")
	AddHelpText(Panel, "Prevents head clipping through camera")
	AddSpacing(Panel)
	
	-- Audio Section
	AddSectionHeader(Panel, "Audio")
	AddSpacing(Panel)
	
	Panel:CheckBox("Mute NPC Death Sounds", "bsmod_killmove_mute_death_sounds")
	AddSpacing(Panel)
	
	-- Camera Section
	AddSectionHeader(Panel, "Camera")
	AddSpacing(Panel)
	
	Panel:CheckBox("Smooth Camera Movement", "bsmod_killmove_lerp_enable")
	Panel:NumSlider("Movement Speed", "bsmod_killmove_lerp_speed", 100, 500, 0)
	AddSpacing(Panel)
	
	-- Third-Person Section
	AddSectionHeader(Panel, "Third-Person Mode")
	AddSpacing(Panel)
	
	Panel:CheckBox("Enable Third-Person View", "bsmod_killmove_thirdperson")
	Panel:NumSlider("Distance", "bsmod_killmove_thirdperson_distance", 50, 300, 0)
	Panel:NumSlider("Pitch (Up/Down)", "bsmod_killmove_thirdperson_pitch", -89, 89, 0)
	Panel:NumSlider("Yaw (Left/Right)", "bsmod_killmove_thirdperson_yaw", -180, 180, 0)
	Panel:NumSlider("Vertical Offset", "bsmod_killmove_thirdperson_offsetup", -100, 100, 0)
	Panel:NumSlider("Horizontal Offset", "bsmod_killmove_thirdperson_offsetright", -100, 100, 0)
	Panel:NumSlider("Custom FOV (0 = default)", "bsmod_killmove_thirdperson_fov", 0, 120, 0)
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Third-Person Behavior")
	AddSpacing(Panel)
	
	Panel:CheckBox("Randomize Yaw Each KillMove", "bsmod_killmove_thirdperson_randomyaw")
	Panel:CheckBox("Smooth Camera Transitions", "bsmod_killmove_thirdperson_smoothing")
	AddHelpText(Panel, "Smoothly zooms out to third person and transitions FOV")
	Panel:NumSlider("Smoothing Speed", "bsmod_killmove_thirdperson_smoothspeed", 1, 20, 0)
	AddHelpText(Panel, "Higher = faster camera response")
	Panel:CheckBox("Orbit Camera", "bsmod_killmove_thirdperson_orbit")
	Panel:NumSlider("Orbit Speed (deg/sec)", "bsmod_killmove_thirdperson_orbitspeed", 5, 60, 0)
	AddSpacing(Panel)
	
	-- Experimental Section
	AddSectionHeader(Panel, "Experimental")
	AddSpacing(Panel)
	
	Panel:CheckBox("Use Viewmodel Hands (C_Arms)", "bsmod_killmove_use_chands")
	AddHelpText(Panel, "Replaces playermodel arms with viewmodel hands during killmoves.")
	AddSpacing(Panel)
	
	-- Debug Section
	AddSectionHeader(Panel, "Debug")
	AddSpacing(Panel)
	
	Panel:CheckBox("Log CalcView Hooks", "bsmod_debug_calcview")
end

local function BSModAdminOptions(Panel)
	Panel:ClearControls()
	
	Panel:AddControl("ComboBox", {
		MenuButton = 1,
		Folder = "bsmod_admin",
		Options = {
			["Default"] = {
				bsmod_kick_enabled = "1",
				bsmod_kick_delay = "0.7",
				bsmod_kick_damage_min = "10",
				bsmod_kick_damage_max = "15",
				bsmod_kick_viewpunch_amount = "2.5",
				bsmod_kick_blowdoor = "0",
				bsmod_kick_chancetoblowdoor = "3",
				bsmod_killmove_by_kicking = "0",
				bsmod_punch_delay = "0.35",
				bsmod_punch_effect = "1",
				bsmod_punch_damage_min = "10",
				bsmod_punch_damage_max = "15",
				bsmod_punch_viewpunch_amount = "0.5",
				bsmod_punch_blocking_resistance = "50",
				bsmod_killmove_enable_players = "1",
				bsmod_killmove_enable_npcs = "1",
				bsmod_killmove_enable_teammates = "0",
				bsmod_killmove_stun_npcs = "1",
				bsmod_killmove_anytime = "0",
				bsmod_killmove_anytime_behind = "0",
				bsmod_killmove_minhealth = "25",
				bsmod_killmove_time = "5",
				bsmod_killmove_chance = "1",
				bsmod_killmove_player_damage_only = "1",
				bsmod_killmove_drop_target_weapons = "1",
				bsmod_killmove_spawn_healthvial = "0",
				bsmod_killmove_spawn_healthkit = "0",
				bsmod_killmove_disable_defaults = "0",
				bsmod_killmove_hull_fix = "0"
			}
		},
		CVars = {
			"bsmod_kick_enabled",
			"bsmod_kick_delay",
			"bsmod_kick_damage_min",
			"bsmod_kick_damage_max",
			"bsmod_kick_viewpunch_amount",
			"bsmod_kick_blowdoor",
			"bsmod_kick_chancetoblowdoor",
			"bsmod_killmove_by_kicking",
			"bsmod_punch_delay",
			"bsmod_punch_effect",
			"bsmod_punch_damage_min",
			"bsmod_punch_damage_max",
			"bsmod_punch_viewpunch_amount",
			"bsmod_punch_blocking_resistance",
			"bsmod_killmove_enable_players",
			"bsmod_killmove_enable_npcs",
			"bsmod_killmove_enable_teammates",
			"bsmod_killmove_stun_npcs",
			"bsmod_killmove_anytime",
			"bsmod_killmove_anytime_behind",
			"bsmod_killmove_minhealth",
			"bsmod_killmove_time",
			"bsmod_killmove_chance",
			"bsmod_killmove_player_damage_only",
			"bsmod_killmove_drop_target_weapons",
			"bsmod_killmove_spawn_healthvial",
			"bsmod_killmove_spawn_healthkit",
			"bsmod_killmove_disable_defaults",
			"bsmod_killmove_hull_fix"
		}
	})
	AddSpacing(Panel)
	
	-- Kick Section
	AddSectionHeader(Panel, "Kick")
	AddSpacing(Panel)
	
	Panel:CheckBox("Enable Kick", "bsmod_kick_enabled")
	Panel:NumSlider("Cooldown (seconds)", "bsmod_kick_delay", 0.1, 2, 2)
	Panel:NumSlider("Damage (Min)", "bsmod_kick_damage_min", 1, 100, 0)
	Panel:NumSlider("Damage (Max)", "bsmod_kick_damage_max", 1, 100, 0)
	Panel:NumSlider("Camera Shake", "bsmod_kick_viewpunch_amount", 0, 10, 1)
	Panel:CheckBox("Can Kick Doors Off Hinges", "bsmod_kick_blowdoor")
	Panel:NumSlider("Door Break Chance (1 in X)", "bsmod_kick_chancetoblowdoor", 1, 10, 0)
	Panel:CheckBox("Kick Can Trigger KillMoves", "bsmod_killmove_by_kicking")
	AddSpacing(Panel)
	
	-- Punch Section
	AddSectionHeader(Panel, "Punch SWEP")
	AddSpacing(Panel)
	
	Panel:NumSlider("Attack Cooldown", "bsmod_punch_delay", 0.1, 1, 2)
	Panel:NumSlider("Damage (Min)", "bsmod_punch_damage_min", 1, 100, 0)
	Panel:NumSlider("Damage (Max)", "bsmod_punch_damage_max", 1, 100, 0)
	Panel:NumSlider("Camera Shake", "bsmod_punch_viewpunch_amount", 0, 5, 1)
	Panel:CheckBox("Show Hit Effect", "bsmod_punch_effect")
	Panel:NumSlider("Block Damage Reduction %", "bsmod_punch_blocking_resistance", 0, 100, 0)
	AddHelpText(Panel, "Hold R to block while using the Punch SWEP.")
	AddSpacing(Panel)
	
	-- KillMove Targets Section
	AddSectionHeader(Panel, "KillMove Targets")
	AddSpacing(Panel)
	
	Panel:CheckBox("Enable on Players", "bsmod_killmove_enable_players")
	Panel:CheckBox("Enable on NPCs", "bsmod_killmove_enable_npcs")
	Panel:CheckBox("Enable on Teammates", "bsmod_killmove_enable_teammates")
	Panel:CheckBox("Stun Killmovable NPCs", "bsmod_killmove_stun_npcs")
	AddHelpText(Panel, "Stunned NPCs stop moving and attacking.")
	AddSpacing(Panel)
	
	-- KillMove Conditions Section
	AddSectionHeader(Panel, "KillMove Conditions")
	AddSpacing(Panel)
	
	Panel:CheckBox("Allow Anytime (No Health Requirement)", "bsmod_killmove_anytime")
	Panel:CheckBox("Allow Anytime From Behind", "bsmod_killmove_anytime_behind")
	Panel:NumSlider("Health Threshold", "bsmod_killmove_minhealth", 1, 100, 0)
	AddHelpText(Panel, "Target must be at or below this health.")
	Panel:NumSlider("Vulnerable Duration (seconds)", "bsmod_killmove_time", 0, 30, 1)
	AddHelpText(Panel, "How long targets stay killmovable. 0 = forever.")
	Panel:NumSlider("Trigger Chance (1 in X)", "bsmod_killmove_chance", 1, 100, 0)
	AddHelpText(Panel, "1 = always, 2 = 50%, 4 = 25%, etc.")
	Panel:CheckBox("Only Player Damage Triggers", "bsmod_killmove_player_damage_only")
	AddSpacing(Panel)
	
	-- Rewards Section
	AddSectionHeader(Panel, "Rewards")
	AddSpacing(Panel)
	
	Panel:CheckBox("Drop Health Vial", "bsmod_killmove_spawn_healthvial")
	Panel:CheckBox("Drop Health Kit", "bsmod_killmove_spawn_healthkit")
	Panel:CheckBox("Drop Target's Weapons", "bsmod_killmove_drop_target_weapons")
	AddSpacing(Panel)
	
	-- Advanced Section
	AddSectionHeader(Panel, "Advanced")
	AddSpacing(Panel)
	
	Panel:CheckBox("Disable Default KillMoves", "bsmod_killmove_disable_defaults")
	AddHelpText(Panel, "Only use custom killmoves from other addons.")
	Panel:CheckBox("Hull Fix (Anti-Stuck)", "bsmod_killmove_hull_fix")
	AddHelpText(Panel, "Prevents getting stuck in geometry after killmoves.")
end

hook.Add("PopulateToolMenu", "BSModPopulateToolMenu", function()
	spawnmenu.AddToolMenuOption("Options", "BSMod", "BSModUserOptions", "User Options", "", "", BSModUserOptions)
	spawnmenu.AddToolMenuOption("Options", "BSMod", "BSModAdminOptions", "Server Options", "", "", BSModAdminOptions)
end)
