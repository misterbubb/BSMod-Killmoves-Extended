local SECTION_COLOR = Color(200, 200, 200)
local HEADER_COLOR = Color(100, 180, 255)
local HELP_COLOR = Color(140, 140, 140)

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
	local spacer = vgui.Create("DLabel")
	spacer:SetText("")
	spacer:SetTall(8)
	Panel:AddItem(spacer)
end

local function BSModUserOptions(Panel)
	Panel:ClearControls()
	
	Panel:AddControl("ComboBox", {
		MenuButton = 1,
		Folder = "bsmod_user",
		Options = {
			["Default"] = {
				bsmod_killmove_indicator = "1",
				bsmod_killmove_key = "",
				bsmod_killmove_fovfx = "1",
				bsmod_killmove_fov_value = "70",
				bsmod_killmove_hide_hud = "1",
				bsmod_killmove_hide_head = "0",
				bsmod_killmove_hide_target_weapons = "1",
				bsmod_killmove_lerp_enable = "1",
				bsmod_killmove_lerp_speed = "250",
				bsmod_killmove_thirdperson = "0",
				bsmod_killmove_thirdperson_distance = "100",
				bsmod_killmove_thirdperson_pitch = "25",
				bsmod_killmove_thirdperson_yaw = "-35",
				bsmod_killmove_thirdperson_offsetup = "-15",
				bsmod_killmove_thirdperson_offsetright = "0",
				bsmod_killmove_thirdperson_randomyaw = "0",
				bsmod_debug_calcview = "0"
			}
		},
		CVars = {
			"bsmod_killmove_indicator",
			"bsmod_killmove_key",
			"bsmod_killmove_fovfx",
			"bsmod_killmove_fov_value",
			"bsmod_killmove_hide_hud",
			"bsmod_killmove_hide_head",
			"bsmod_killmove_hide_target_weapons",
			"bsmod_killmove_lerp_enable",
			"bsmod_killmove_lerp_speed",
			"bsmod_killmove_thirdperson",
			"bsmod_killmove_thirdperson_distance",
			"bsmod_killmove_thirdperson_pitch",
			"bsmod_killmove_thirdperson_yaw",
			"bsmod_killmove_thirdperson_offsetup",
			"bsmod_killmove_thirdperson_offsetright",
			"bsmod_killmove_thirdperson_randomyaw",
			"bsmod_debug_calcview"
		}
	})
	AddSpacing(Panel)
	
	local instructionLabel = vgui.Create("DLabel")
	instructionLabel:SetText("Keybind: Type 'bind <key> bsmod_killmove' in console")
	instructionLabel:SetColor(HELP_COLOR)
	instructionLabel:SetWrap(true)
	instructionLabel:SetAutoStretchVertical(true)
	Panel:AddItem(instructionLabel)
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Target Indicator")
	AddSpacing(Panel)
	
	Panel:NumSlider("Indicator Mode", "bsmod_killmove_indicator", 0, 2, 0)
	AddHelpText(Panel, "0 = Off, 1 = Takedown Prompt, 2 = Icon Above Head")
	
	Panel:TextEntry("Key Override (for Prompt)", "bsmod_killmove_key")
	AddHelpText(Panel, "Leave empty to auto-detect, or type a key name (e.g. F, E, MOUSE4)")
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Visual Effects")
	AddSpacing(Panel)
	
	Panel:CheckBox("Enable FOV Effect", "bsmod_killmove_fovfx")
	AddHelpText(Panel, "Zooms camera during killmoves for a cinematic feel")
	
	Panel:NumSlider("FOV Value", "bsmod_killmove_fov_value", 50, 120, 0)
	AddHelpText(Panel, "Field of view during killmoves (70 = default game FOV)")
	AddSpacing(Panel)
	
	Panel:CheckBox("Hide HUD During KillMoves", "bsmod_killmove_hide_hud")
	AddHelpText(Panel, "Hides all HUD elements for a cleaner cinematic view")
	
	Panel:CheckBox("Hide Head During KillMoves", "bsmod_killmove_hide_head")
	AddHelpText(Panel, "Hides your head in first-person (helps if accessories block view)")
	
	Panel:CheckBox("Hide Target Weapons", "bsmod_killmove_hide_target_weapons")
	AddHelpText(Panel, "Hides enemy weapons during killmoves")
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Movement")
	AddSpacing(Panel)
	
	Panel:CheckBox("Enable Smooth Movement", "bsmod_killmove_lerp_enable")
	AddHelpText(Panel, "Smoothly slides you into position when starting a killmove")
	
	Panel:NumSlider("Movement Speed", "bsmod_killmove_lerp_speed", 100, 500, 0)
	AddHelpText(Panel, "How fast you move into position (higher = faster)")
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Third-Person Camera")
	AddSpacing(Panel)
	
	Panel:CheckBox("View in Third Person", "bsmod_killmove_thirdperson")
	AddHelpText(Panel, "Watch killmoves from an external camera angle")
	AddSpacing(Panel)
	
	Panel:NumSlider("Camera Distance", "bsmod_killmove_thirdperson_distance", 0, 250, 0)
	Panel:NumSlider("Camera Pitch (Up/Down)", "bsmod_killmove_thirdperson_pitch", -89, 89, 0)
	Panel:NumSlider("Camera Yaw (Left/Right)", "bsmod_killmove_thirdperson_yaw", -180, 180, 0)
	Panel:CheckBox("Random Yaw Each Time", "bsmod_killmove_thirdperson_randomyaw")
	Panel:NumSlider("Offset Up/Down", "bsmod_killmove_thirdperson_offsetup", -100, 100, 0)
	Panel:NumSlider("Offset Left/Right", "bsmod_killmove_thirdperson_offsetright", -100, 100, 0)
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Debug")
	AddSpacing(Panel)
	
	Panel:CheckBox("Log CalcView Hooks", "bsmod_debug_calcview")
	AddHelpText(Panel, "Prints active camera hooks to console (for troubleshooting)")
end

local function BSModAdminOptions(Panel)
	Panel:ClearControls()
	
	Panel:AddControl("ComboBox", {
		MenuButton = 1,
		Folder = "bsmod_admin",
		Options = {
			["Default"] = {
				bsmod_killmove_enable_players = "1",
				bsmod_killmove_enable_npcs = "1",
				bsmod_killmove_enable_teammates = "0",
				bsmod_killmove_stun_npcs = "1",
				bsmod_killmove_anytime = "0",
				bsmod_killmove_anytime_behind = "0",
				bsmod_killmove_minhealth = "25",
				bsmod_killmove_chance = "4",
				bsmod_killmove_player_damage_only = "1",
				bsmod_killmove_disable_defaults = "0",
				bsmod_killmove_spawn_healthvial = "0",
				bsmod_killmove_spawn_healthkit = "0"
			}
		},
		CVars = {
			"bsmod_killmove_enable_players",
			"bsmod_killmove_enable_npcs",
			"bsmod_killmove_enable_teammates",
			"bsmod_killmove_stun_npcs",
			"bsmod_killmove_anytime",
			"bsmod_killmove_anytime_behind",
			"bsmod_killmove_minhealth",
			"bsmod_killmove_chance",
			"bsmod_killmove_player_damage_only",
			"bsmod_killmove_disable_defaults",
			"bsmod_killmove_spawn_healthvial",
			"bsmod_killmove_spawn_healthkit"
		}
	})
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Valid Targets")
	AddSpacing(Panel)
	
	Panel:CheckBox("Allow KillMoves on Players", "bsmod_killmove_enable_players")
	Panel:CheckBox("Allow KillMoves on NPCs", "bsmod_killmove_enable_npcs")
	Panel:CheckBox("Allow KillMoves on Teammates", "bsmod_killmove_enable_teammates")
	AddSpacing(Panel)
	
	Panel:CheckBox("Stun KillMovable NPCs", "bsmod_killmove_stun_npcs")
	AddHelpText(Panel, "Makes NPCs stop moving when they become killmovable")
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Timing & Conditions")
	AddSpacing(Panel)
	
	Panel:CheckBox("Allow KillMoves Anytime", "bsmod_killmove_anytime")
	AddHelpText(Panel, "Killmoves work regardless of target health")
	
	Panel:CheckBox("Allow Anytime from Behind", "bsmod_killmove_anytime_behind")
	AddHelpText(Panel, "Killmoves from behind always work")
	AddSpacing(Panel)
	
	Panel:NumSlider("Health Threshold", "bsmod_killmove_minhealth", 1, 75, 0)
	AddHelpText(Panel, "Targets must have this HP or less to be killmovable")
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Chance & Damage")
	AddSpacing(Panel)
	
	Panel:NumSlider("Chance Denominator", "bsmod_killmove_chance", 1, 100, 0)
	AddHelpText(Panel, "1 = 100% chance, 4 = 25% chance, 10 = 10% chance")
	
	Panel:CheckBox("Player Damage Only", "bsmod_killmove_player_damage_only")
	AddHelpText(Panel, "Only player-dealt damage makes targets killmovable")
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Advanced")
	AddSpacing(Panel)
	
	Panel:CheckBox("Disable Built-in KillMoves", "bsmod_killmove_disable_defaults")
	AddHelpText(Panel, "Only use custom killmoves from addons")
	AddSpacing(Panel)
	
	AddSectionHeader(Panel, "Rewards")
	AddSpacing(Panel)
	
	Panel:CheckBox("Spawn Health Vial", "bsmod_killmove_spawn_healthvial")
	Panel:CheckBox("Spawn Health Kit", "bsmod_killmove_spawn_healthkit")
	AddHelpText(Panel, "Spawns healing items after performing a killmove")
end

local function BSModPopulateToolMenu()
	spawnmenu.AddToolMenuOption("Options", "BSMod", "BSModUserOptions", "User Options", "", "", BSModUserOptions)
	spawnmenu.AddToolMenuOption("Options", "BSMod", "BSModAdminOptions", "Admin Options", "", "", BSModAdminOptions)
end
hook.Add("PopulateToolMenu", "BSModPopulateToolMenu", BSModPopulateToolMenu)
