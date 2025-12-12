--[[
	BSMod Custom KillMove Template (Extended)
	
	IMPORTANT: Change "UniqueName" in all hooks to something unique to your addon!
	Having duplicate hook names will cause conflicts with other killmove addons.
	
	This template shows how to use all the new features in BSMod Extended:
	- Position types (ground, air, water, cover, DFB)
	- Target type detection (zombie, combine, player, etc.)
	- Weapon-based killmoves
	- Crouch detection
	- New hooks (KillMoveStarted, KillMoveEnded)
]]

if SERVER then
	
	-- Optional: Add custom entities to the killmovable list
	-- ValveBipeds are already included by default
	timer.Simple(0, function()
		if killMovableEnts then
			-- Uncomment to add non-ValveBiped entities:
			-- table.insert(killMovableEnts, "npc_headcrab")
			-- table.insert(killMovableEnts, "npc_antlion")
		end
	end)
	
	--[[
		MAIN KILLMOVE HOOK
		
		Available player variables (set by base mod before this hook runs):
		- ply.bsmod_km_position_type: "ground_front", "air_back", "water_left", "cover_front", "dfb_back", etc.
		- ply.bsmod_km_direction: "front", "back", "left", "right"
		- ply.bsmod_km_in_water: true if player is in water
		- ply.bsmod_km_in_air: true if player is in air (DFA)
		- ply.bsmod_km_cover_state: "none", "cover", or "dfb"
		- ply.bsmod_km_cover_entity: The cover entity (door, prop) or nil
		- ply.bsmod_km_target_type: "player", "hunter", "zombie", "combine", "antlion", "headcrab", "vj_npc", "human"
		- ply.bsmod_km_target_crouching: true if target is crouching
		- ply.bsmod_km_player_weapon_type: "unarmed", "melee", "pistol", "rifle"
	]]
	
	hook.Add("CustomKillMoves", "UniqueName", function(ply, target, angleAround)
		-- Setup killmove data
		local plyKMModel = nil
		local targetKMModel = nil
		local animName = nil
		local plyKMPosition = nil
		local plyKMAngle = nil
		
		local kmData = {nil, nil, nil, nil, nil}
		
		-- Set your custom player animation model
		plyKMModel = "models/weapons/c_limbs_template.mdl"
		
		-- Get the pre-calculated position info from base mod
		local posType = ply.bsmod_km_position_type or "ground_front"
		local direction = ply.bsmod_km_direction or "front"
		local targetType = ply.bsmod_km_target_type or "human"
		local weaponType = ply.bsmod_km_player_weapon_type or "unarmed"
		local inWater = ply.bsmod_km_in_water
		local inAir = ply.bsmod_km_in_air
		local coverState = ply.bsmod_km_cover_state or "none"
		local targetCrouching = ply.bsmod_km_target_crouching
		
		-- Only trigger for ValveBiped targets (most humanoids)
		if not target:LookupBone("ValveBiped.Bip01_Spine") then return end
		
		-- Add a random chance so other killmove packs can also trigger
		if math.random(1, 4) > 3 then return end
		
		-- Set target model
		targetKMModel = "models/bsmodimations_zombie_template.mdl"
		
		--[[
			EXAMPLE 1: Position-based killmoves
			Use posType for the full situation
		]]
		
		if posType == "ground_front" then
			-- Standard front ground killmove
			animName = math.random(1, 2) == 1 and "killmove_zombie_punch1" or "killmove_zombie_kick1"
			
		elseif posType == "ground_back" then
			-- Stealth takedown from behind
			animName = "killmove_zombie_back1"
			
		elseif posType == "air_front" then
			-- Death from above (jumping on target)
			animName = "killmove_zombie_dfa1"
			
		elseif posType == "water_front" then
			-- Underwater takedown
			animName = "killmove_zombie_water1"
			
		elseif posType == "cover_front" then
			-- Pull target over cover
			animName = "killmove_zombie_cover1"
			
		elseif posType == "dfb_front" then
			-- Death from below (target on ledge above)
			animName = "killmove_zombie_dfb1"
		end
		
		--[[
			EXAMPLE 2: Target type specific killmoves
			Different animations for different enemy types
		]]
		
		if targetType == "zombie" and direction == "front" then
			-- Zombie-specific front killmove
			-- animName = "killmove_zombie_special1"
		elseif targetType == "combine" and direction == "back" then
			-- Combine soldier stealth takedown
			-- animName = "killmove_combine_stealth1"
		elseif targetType == "player" then
			-- PvP killmove
			-- animName = "killmove_pvp1"
		end
		
		--[[
			EXAMPLE 3: Weapon-based killmoves
			Different animations based on player's weapon
		]]
		
		if weaponType == "melee" and direction == "front" then
			-- Knife/crowbar takedown
			-- animName = "killmove_knife_front1"
		elseif weaponType == "pistol" and direction == "back" then
			-- Pistol execution
			-- animName = "killmove_pistol_execute1"
		end
		
		--[[
			EXAMPLE 4: Crouch-specific killmoves
		]]
		
		if targetCrouching and direction == "back" then
			-- Target is crouching, use low takedown
			-- animName = "killmove_crouch_back1"
		end
		
		-- If no animation was selected, don't override
		if not animName then return end
		
		-- Position the player relative to target
		local targetPos = target:GetPos()
		local targetForward = target:GetForward()
		local targetRight = target:GetRight()
		
		if animName == "killmove_zombie_punch1" then
			plyKMPosition = targetPos + (targetForward * 70)
		elseif animName == "killmove_zombie_kick1" then
			plyKMPosition = targetPos + (targetForward * 75)
		elseif direction == "back" then
			plyKMPosition = targetPos - (targetForward * 30)
			plyKMAngle = targetForward:Angle() -- Face same direction as target
		elseif direction == "left" then
			plyKMPosition = targetPos - (targetRight * 32)
			plyKMAngle = targetRight:Angle()
		elseif direction == "right" then
			plyKMPosition = targetPos + (targetRight * 32)
			plyKMAngle = (-targetRight):Angle()
		else
			-- Default front position
			plyKMPosition = targetPos + (targetForward * 32)
		end
		
		-- Build and return killmove data
		kmData[1] = plyKMModel
		kmData[2] = targetKMModel
		kmData[3] = animName
		kmData[4] = plyKMPosition
		kmData[5] = plyKMAngle
		-- kmData[6] = plyKMTime (optional: override animation time)
		-- kmData[7] = targetKMTime (optional: override target animation time)
		-- kmData[8] = moveTarget (optional: true to move target instead of player)
		
		return kmData
	end)
	
	--[[
		EFFECTS AND SOUNDS HOOK
		Add sounds and visual effects to your animations
	]]
	
	hook.Add("CustomKMEffects", "UniqueName", function(ply, animName, targetModel)
		if not IsValid(targetModel) then return end
		
		local targetHeadBone = targetModel:GetHeadBone()
		
		if animName == "killmove_zombie_punch1" then
			timer.Simple(0.8, function()
				if not IsValid(targetModel) then return end
				
				-- Play random hit sound
				PlayRandomSound(ply, 1, 5, "player/killmove/km_hit")
				
				-- Blood effect at head
				if targetHeadBone then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(targetHeadBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
			
		elseif animName == "killmove_zombie_kick1" then
			timer.Simple(0.7, function()
				if not IsValid(targetModel) then return end
				
				PlayRandomSound(ply, 1, 5, "player/killmove/km_hit")
				
				if targetHeadBone then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(targetHeadBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
		end
		
		-- Add more animation effects here...
	end)
	
	--[[
		NEW HOOKS: React to killmove state changes
	]]
	
	hook.Add("BSMod_KillMoveStarted", "UniqueName", function(ply, target, animName, positionType)
		-- Called when a killmove begins
		-- Useful for: playing ambient sounds, triggering events, logging stats
		
		-- Example: Print debug info
		-- print(ply:Nick() .. " started " .. positionType .. " killmove on " .. tostring(target))
	end)
	
	hook.Add("BSMod_KillMoveEnded", "UniqueName", function(ply, target, positionType)
		-- Called when a killmove ends
		-- Useful for: cleanup, awarding points, triggering post-killmove effects
		
		-- Example: Award points in a gamemode
		-- ply:AddFrags(1)
	end)
end

--[[
	RAGDOLL PHYSICS HOOK
	Modify how the ragdoll behaves after the killmove
	This runs on both server and client (for clientside ragdolls)
]]

hook.Add("KMRagdoll", "UniqueName", function(entity, ragdoll, animName)
	local spinePos, spineAng = nil
	
	if ragdoll:LookupBone("ValveBiped.Bip01_Spine") then
		spinePos, spineAng = ragdoll:GetBonePosition(ragdoll:LookupBone("ValveBiped.Bip01_Spine"))
	end
	
	-- Apply velocity to all physics bones
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local bone = ragdoll:GetPhysicsObjectNum(i)
		
		if bone and bone:IsValid() and spineAng then
			if animName == "killmove_zombie_kick1" then
				-- Kick sends ragdoll flying backward
				bone:SetVelocity(-spineAng:Up() * 75)
				
			elseif animName == "killmove_zombie_punch1" then
				-- Punch sends ragdoll stumbling back
				bone:SetVelocity(-spineAng:Up() * 50)
				
			-- Add more ragdoll physics for your animations...
			end
		end
	end
	
	-- Example: Make ragdoll spin (torpedo effect)
	-- bone:SetAngleVelocity(bone:WorldToLocalVector(-spineAng:Forward() * 2500))
end)
