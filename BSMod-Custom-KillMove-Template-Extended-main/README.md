# BSMod Custom KillMove Template (Extended)

This is a template addon for creating custom KillMoves for **BSMod Killmoves Extended**.

## What's New in Extended

The extended version of BSMod provides a comprehensive framework for custom killmoves:

### Position Detection (18 types automatically detected)
- **Ground:** front, back, left, right
- **Air (DFA):** front, back, left, right  
- **Water:** front, back, left, right
- **Cover:** front, back (obstacle between player and target)
- **DFB:** front, back (Death From Below - target above player)

### Target Detection
- Automatically detects target type: player, hunter, zombie, combine, antlion, headcrab, vj_npc, or human
- Detects if target is crouching

### Weapon Detection
- Detects player's weapon type: unarmed, melee, pistol, or rifle

### Available Player Variables (in CustomKillMoves hook)
```lua
ply.bsmod_km_position_type    -- "ground_front", "air_back", "water_left", etc.
ply.bsmod_km_direction        -- "front", "back", "left", "right"
ply.bsmod_km_in_water         -- true/false
ply.bsmod_km_in_air           -- true/false
ply.bsmod_km_cover_state      -- "none", "cover", or "dfb"
ply.bsmod_km_cover_entity     -- The cover entity or nil
ply.bsmod_km_target_type      -- "zombie", "combine", "player", etc.
ply.bsmod_km_target_crouching -- true/false
ply.bsmod_km_player_weapon_type -- "unarmed", "melee", "pistol", "rifle"
```

### Available Hooks
```lua
-- Main hook for providing custom killmove animations
hook.Add("CustomKillMoves", "YourModName", function(ply, target, angleAround)
    -- Return kmData table or nil
end)

-- Hook for adding sounds and effects to your animations
hook.Add("CustomKMEffects", "YourModName", function(ply, animName, targetModel)
    -- Play sounds, spawn effects, etc.
end)

-- Hook for modifying ragdoll physics after killmove
hook.Add("KMRagdoll", "YourModName", function(entity, ragdoll, animName)
    -- Apply velocity/rotation to ragdoll
end)

-- NEW: React to killmove starting
hook.Add("BSMod_KillMoveStarted", "YourModName", function(ply, target, animName, positionType)
    -- Killmove just started
end)

-- NEW: React to killmove ending
hook.Add("BSMod_KillMoveEnded", "YourModName", function(ply, target, positionType)
    -- Killmove just ended
end)
```

---

## Tools Required

### Blender (for animations)
I recommend **Blender 2.79b** for editing the models and animations:  
https://www.blender.org/download/releases/2-79/

Make sure to also download **Blender Source Tools**:  
http://steamreview.org/BlenderSourceTools/download.php?v=2.10.2

### Crowbar (for compiling models)
For compiling the models I recommend using **Crowbar**:  
https://steamcommunity.com/groups/CrowbarTool

### Workshop Upload
For compiling your addon and uploading to workshop:  
- https://wiki.facepunch.com/gmod/Workshop_Addon_Creation#creatingagmaforupload  
- https://wiki.facepunch.com/gmod/Workshop_Addon_Creation#uploadingyouraddon

---

## Folder Structure

```
Your Addon/
├── lua/
│   └── autorun/
│       └── bsmod_customkillmove.lua  -- Your killmove logic
├── models/
│   └── (your compiled .mdl files)
├── sound/
│   └── (your custom sounds)
└── addon.json
```

---

## Quick Start

1. Copy the `Addon/BSMod Custom KillMove Template` folder
2. Rename it to your addon name
3. Edit `addon.json` with your addon info
4. Edit `lua/autorun/bsmod_customkillmove.lua` (see the example code)
5. Create your animations in Blender using the decompiled models as reference
6. Compile your models with Crowbar
7. Test in-game and upload to Workshop!

---

## Tips

- Use `ply.bsmod_km_position_type` to easily check the full situation (e.g., "water_front")
- Use `ply.bsmod_km_target_type` for enemy-specific animations (zombie vs combine)
- Use `ply.bsmod_km_player_weapon_type` for weapon-specific takedowns
- Always add a `math.random` chance so other killmove packs can also trigger
- Change "UniqueName" in all hooks to something unique to your addon!
