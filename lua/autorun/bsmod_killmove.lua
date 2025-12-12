-- Detect conflict with original BSMod
local ORIGINAL_BSMOD_WORKSHOP_ID = "2106330193"

for _, addon in ipairs(engine.GetAddons()) do
	if addon.wsid == ORIGINAL_BSMOD_WORKSHOP_ID and addon.mounted then
		-- Show warning on client
		if CLIENT then
			local warningStartTime = RealTime()
			local warningDuration = 15 -- Show for 15 seconds
			
			hook.Add("HUDPaint", "BSModConflictWarning", function()
				local elapsed = RealTime() - warningStartTime
				if elapsed > warningDuration then
					hook.Remove("HUDPaint", "BSModConflictWarning")
					return
				end
				
				-- Fade out in last 2 seconds
				local alpha = 1
				if elapsed > warningDuration - 2 then
					alpha = (warningDuration - elapsed) / 2
				end
				
				local text1 = "WARNING: Original BSMod detected!"
				local text2 = "Disable it to avoid conflicts."
				
				surface.SetFont("DermaLarge")
				local w1, h1 = surface.GetTextSize(text1)
				surface.SetFont("DermaDefaultBold")
				local w2, h2 = surface.GetTextSize(text2)
				
				local boxW = math.max(w1, w2) + 40
				local boxH = h1 + h2 + 20
				local x = ScrW() / 2 - boxW / 2
				local y = 80
				
				draw.RoundedBox(8, x, y, boxW, boxH, Color(150, 0, 0, 200 * alpha))
				draw.SimpleText(text1, "DermaLarge", ScrW() / 2, y + 10, Color(255, 255, 255, 255 * alpha), TEXT_ALIGN_CENTER)
				draw.SimpleText(text2, "DermaDefaultBold", ScrW() / 2, y + 10 + h1 + 5, Color(255, 255, 255, 230 * alpha), TEXT_ALIGN_CENTER)
			end)
		end
		
		-- Log to console on both realms
		MsgC(Color(255, 100, 100), "[BSMod Fork] WARNING: Original BSMod (Workshop ID: " .. ORIGINAL_BSMOD_WORKSHOP_ID .. ") is installed!\n")
		MsgC(Color(255, 100, 100), "[BSMod Fork] Please unsubscribe from the original to avoid conflicts.\n")
		
		return -- Stop loading this file to prevent further conflicts
	end
end

local plymeta = FindMetaTable("Player")
if not plymeta then return end

local entmeta = FindMetaTable("Entity")
if not entmeta then return end

-- Performance: Cache frequently used globals
local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local Angle = Angle
local math_random = math.random
local math_Clamp = math.Clamp
local ipairs = ipairs
local pairs = pairs

if SERVER then	
	util.AddNetworkString("setkillmovable")
	util.AddNetworkString("removedecals")
	util.AddNetworkString("debugbsmodcalcview")
	util.AddNetworkString("bsmod_inkillmove")
	
	-- A list that a player/npc must have to be killmovable (highlighted blue)
	if not killMovableBones then killMovableBones = {"ValveBiped.Bip01_Spine", "MiniStrider.body_joint"} end
	if not killMovableEnts then killMovableEnts = {} end
	
	-- Performance: Track killMovable entities instead of iterating all entities
	local killMovableEntities = {}
	
	-- Performance: Cache ConVars (accessed frequently in hooks)
	local cv_stun_npcs, cv_minhealth, cv_anytime, cv_anytime_behind
	local cv_enable_players, cv_enable_npcs, cv_enable_teammates
	local cv_chance, cv_player_damage_only, cv_time, cv_disable_defaults
	local cv_fovfx, cv_fov_value, cv_lerp_enable, cv_lerp_speed
	local cv_spawn_healthvial, cv_spawn_healthkit, cv_drop_target_weapons, cv_hull_fix, cv_mute_death_sounds, cv_use_key
	
	-- Initialize ConVar cache
	local function CacheConVars()
		cv_stun_npcs = GetConVar("bsmod_killmove_stun_npcs")
		cv_minhealth = GetConVar("bsmod_killmove_minhealth")
		cv_anytime = GetConVar("bsmod_killmove_anytime")
		cv_anytime_behind = GetConVar("bsmod_killmove_anytime_behind")
		cv_enable_players = GetConVar("bsmod_killmove_enable_players")
		cv_enable_npcs = GetConVar("bsmod_killmove_enable_npcs")
		cv_enable_teammates = GetConVar("bsmod_killmove_enable_teammates")
		cv_chance = GetConVar("bsmod_killmove_chance")
		cv_player_damage_only = GetConVar("bsmod_killmove_player_damage_only")
		cv_time = GetConVar("bsmod_killmove_time")
		cv_disable_defaults = GetConVar("bsmod_killmove_disable_defaults")
		cv_fovfx = GetConVar("bsmod_killmove_fovfx")
		cv_fov_value = GetConVar("bsmod_killmove_fov_value")
		cv_lerp_enable = GetConVar("bsmod_killmove_lerp_enable")
		cv_lerp_speed = GetConVar("bsmod_killmove_lerp_speed")
		cv_spawn_healthvial = GetConVar("bsmod_killmove_spawn_healthvial")
		cv_spawn_healthkit = GetConVar("bsmod_killmove_spawn_healthkit")
		cv_drop_target_weapons = GetConVar("bsmod_killmove_drop_target_weapons")
		cv_hull_fix = GetConVar("bsmod_killmove_hull_fix")
		cv_mute_death_sounds = GetConVar("bsmod_killmove_mute_death_sounds")
		cv_use_key = GetConVar("bsmod_killmove_use_key")
	end
	
	hook.Add("Initialize", "BSModCacheConVars", CacheConVars)
	timer.Simple(0, function() if not cv_stun_npcs then CacheConVars() end end)
	
	-- Helper to safely get ConVar int (handles nil during load)
	local function GetCVarInt(cv)
		return cv and cv:GetInt() or 0
	end
	local function GetCVarFloat(cv)
		return cv and cv:GetFloat() or 0
	end
	
	-- Helper to set inKillMove and network it to clients (multiplayer compatibility)
	function entmeta:SetInKillMove(value)
		self.inKillMove = value
		
		-- Network to all clients so they know this entity is in a killmove
		net.Start("bsmod_inkillmove")
		net.WriteEntity(self)
		net.WriteBool(value)
		net.Broadcast()
	end
	
	function entmeta:SetKillMovable(value)
		if value then
			if self.killMovable then return end
			
			-- Hunters are called MiniStriders internally for some reason
			if GetCVarInt(cv_stun_npcs) ~= 0 and not self:LookupBone("MiniStrider.body_joint") then
				if self.IsVJBaseSNPC then
					timer.Simple(0, function() 
						if not IsValid(self) then return end
						self:StopAttacks(true)
						self:StopMoving()
						self:SetState(VJ_STATE_FREEZE)
					end)
				elseif self:IsNPC() then
					timer.Simple(0, function() 
						if not IsValid(self) then return end
						self:SetCondition(67)
						self:SetNPCState(NPC_STATE_NONE)
					end)
				end
			end
			
			-- Track this entity for the Think hook (performance optimization)
			killMovableEntities[self] = true
		else
			if not self.killMovable then return end
			
			if self.IsVJBaseSNPC then
				self:SetState(VJ_STATE_NONE)
			elseif self:IsNPC() then
				self:SetCondition(68)
				self:SetNPCState(NPC_STATE_IDLE)
			end
			
			-- Remove from tracking table
			killMovableEntities[self] = nil
		end
		
		self.killMovable = value
		
		-- Only send to nearby players (within 2000 units) to reduce network traffic
		local entPos = self:GetPos()
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetPos():DistToSqr(entPos) < 4000000 then -- 2000^2
				net.Start("setkillmovable")
				net.WriteEntity(self)
				net.WriteBool(value)
				net.Send(ply)
			end
		end
	end
	
	hook.Add("CreateEntityRagdoll", "BSModCreateEntityRagdoll", function(entity, ragdoll)
		if !IsValid(entity.kmModel) or !IsValid(entity) or !IsValid(ragdoll) then return end
		
		-- Disable collision so player doesn't get stuck inside ragdoll
		ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		
		-- Position all bones from the killmove model
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local bone = ragdoll:GetPhysicsObjectNum(i)
			if bone and bone:IsValid() then
				local bonepos, boneang = entity.kmModel:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))
				bone:SetPos(bonepos, true)
				bone:SetAngles(boneang)
				bone:SetVelocity(vector_origin)
				bone:SetAngleVelocity(vector_origin)
			end
		end
		
		-- Apply physics impulse based on animation
		local animName = entity.kmAnim:GetSequenceName(entity.kmAnim:GetSequence())
		hook.Run("KMRagdoll", entity, ragdoll, animName)
	end)
	
	-- Performance: Only iterate tracked killMovable entities, throttled to reduce CPU usage
	local lastThinkTime = 0
	local thinkInterval = 0.1 -- Only check every 100ms instead of every frame
	
	hook.Add("Think", "BSModThink", function()
		local curTime = CurTime()
		if curTime - lastThinkTime < thinkInterval then return end
		lastThinkTime = curTime
		
		local minHealth = GetCVarInt(cv_minhealth)
		local anytime = GetCVarInt(cv_anytime) ~= 0
		
		for ent in pairs(killMovableEntities) do
			if not IsValid(ent) then
				killMovableEntities[ent] = nil
			elseif ent:Health() > minHealth or ent:Health() <= 0 or anytime then
				ent:SetKillMovable(false)
			end
		end
	end)
	
	hook.Add( "PlayerDeath", "BSModPlayerDeath", function( victim, inflictor, attacker )
		victim.blocking = false
		
		-- Clean up Use key pending state
		victim.bsmod_pending_killmove = nil
		victim.bsmod_last_use_attempt = nil
		
		-- Clean up killmove state on death
		if victim.inKillMove then
			if IsValid(victim.kmModel) then victim.kmModel:Remove() end
			if IsValid(victim.kmAnim) then victim.kmAnim:Remove() end
			victim:SetInKillMove(false)
		end
	end )
	
	-- Clean up on player disconnect to prevent memory leaks
	hook.Add("PlayerDisconnected", "BSModPlayerDisconnected", function(ply)
		-- Clean up Use key pending state
		ply.bsmod_pending_killmove = nil
		ply.bsmod_last_use_attempt = nil
		
		-- Clean up player's killmove models
		if IsValid(ply.kmModel) then ply.kmModel:Remove() end
		if IsValid(ply.kmAnim) then ply.kmAnim:Remove() end
		
		-- Clean up target's state if player was mid-killmove
		if IsValid(ply.prevTargetBSMod) then
			local target = ply.prevTargetBSMod
			if IsValid(target.kmModel) then target.kmModel:Remove() end
			if IsValid(target.kmAnim) then target.kmAnim:Remove() end
			
			-- Restore target visibility and state
			if target.inKillMove then
				target:DrawShadow(true)
				if target:IsPlayer() then
					target:SetMaterial("")
					target:UnLock()
				else
					target:SetNoDraw(false)
				end
				target:SetInKillMove(false)
			end
		end
		
		-- Reset player's killmove state
		ply.inKillMove = false
		ply.prevTargetBSMod = nil
	end)
	
	-- Clean up if an entity is removed while in a killmove (e.g., target disconnects or is removed)
	hook.Add("EntityRemoved", "BSModEntityRemovedCleanup", function(ent)
		if not ent.inKillMove then return end
		
		-- Find any player who was killmoving this entity and clean up their state
		for _, ply in ipairs(player.GetAll()) do
			if ply.prevTargetBSMod == ent then
				-- Clean up player's killmove state
				if IsValid(ply.kmModel) then ply.kmModel:Remove() end
				if IsValid(ply.kmAnim) then ply.kmAnim:Remove() end
				
				ply:DrawShadow(true)
				ply:SetMaterial(ply.prevMaterialBSMod or "")
				ply:SetMoveType(MOVETYPE_WALK)
				ply:UnLock()
				
				if IsValid(ply.prevWeaponBSMod) then
					ply.prevWeaponBSMod:SetNoDraw(false)
				end
				local vm = ply:GetViewModel()
				if IsValid(vm) then
					vm:SetNoDraw(false)
				end
				
				ply:SetInKillMove(false)
				ply.prevTargetBSMod = nil
				ply.prevWeaponBSMod = nil
				ply.prevGodModeBSMod = nil
				ply.prevMaterialBSMod = nil
			end
		end
	end)
	
	-- Block weapon and use input during killmoves (prevents firing and interaction interference)
	hook.Add("StartCommand", "BSModBlockWeaponInput", function(ply, cmd)
		if ply.inKillMove then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
			cmd:RemoveKey(IN_USE)
		end
	end)
	
	-- Prevent picking up weapons during killmoves
	hook.Add("PlayerCanPickupWeapon", "BSModBlockWeaponPickup", function(ply, wep)
		if ply.inKillMove then
			return false
		end
	end)
	
	-- Mute NPC death sounds after killmoves
	hook.Add("EntityEmitSound", "BSModMuteDeathSounds", function(data)
		if GetCVarInt(cv_mute_death_sounds) == 0 then return end
		
		local ent = data.Entity
		if not IsValid(ent) then return end
		
		-- Check if this entity was killed by a killmove (block ALL sounds from them briefly)
		if ent.bsmod_killed_by_killmove then
			return false
		end
	end)
	
	-- Use key killmove: Use KeyPress hook instead of PlayerUse for more reliable detection
	-- PlayerUse only fires for "usable" entities, but NPCs/players aren't usable by default
	hook.Add("KeyPress", "BSModUseKeyKillmove", function(ply, key)
		if key ~= IN_USE then return end
		if GetCVarInt(cv_use_key) == 0 then return end
		if ply.inKillMove then return end
		if ply.bsmod_pending_killmove then return end
		if ply:Health() <= 0 then return end
		
		-- Small cooldown to prevent spam
		if ply.bsmod_last_use_attempt and CurTime() - ply.bsmod_last_use_attempt < 0.3 then 
			return 
		end
		
		-- Do the same trace as KMCheck to find target
		local eyePos = ply:EyePos()
		local forward = ply:EyeAngles():Forward() * 100
		
		local tr = util.TraceLine({
			start = eyePos,
			endpos = eyePos + forward,
			filter = ply
		})
		
		if not IsValid(tr.Entity) then
			tr = util.TraceHull({
				start = eyePos,
				endpos = eyePos + forward,
				filter = ply,
				mins = Vector(-1, -1, -1),
				maxs = Vector(1, 1, 1)
			})
		end
		
		if not IsValid(tr.Entity) then return end
		
		local ent = tr.Entity
		
		-- Check if target is a valid killmove candidate
		if not (ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer()) then return end
		if ent.inKillMove or ent == ply then return end
		
		-- Check player/NPC enable settings
		if ent:IsPlayer() then
			if GetCVarInt(cv_enable_players) == 0 then return end
			if ent:HasGodMode() then return end
			if engine.ActiveGamemode() ~= "sandbox" and GetCVarInt(cv_enable_teammates) == 0 then
				if ent:Team() == ply:Team() then return end
			end
		elseif (ent:IsNPC() or ent:IsNextBot()) and GetCVarInt(cv_enable_npcs) == 0 then
			return
		end
		
		-- Check killmove conditions
		local canKillmove = ent.killMovable or GetCVarInt(cv_anytime) ~= 0
		
		-- Also check anytime_behind
		if not canKillmove and GetCVarInt(cv_anytime_behind) ~= 0 then
			local vec = (ply:GetPos() - ent:GetPos()):GetNormal():Angle().y
			local targetAngle = ent:EyeAngles().y % 360
			if targetAngle < 0 then targetAngle = targetAngle + 360 end
			local angleAround = (vec - targetAngle) % 360
			if angleAround < 0 then angleAround = angleAround + 360 end
			canKillmove = angleAround > 135 and angleAround <= 225
		end
		
		if canKillmove then
			ply.bsmod_last_use_attempt = CurTime()
			
			-- Defer killmove to next frame to avoid input processing issues
			ply.bsmod_pending_killmove = true
			timer.Simple(0, function()
				if IsValid(ply) and not ply.inKillMove then
					ply.bsmod_pending_killmove = nil
					KMCheck(ply)
				else
					ply.bsmod_pending_killmove = nil
				end
			end)
		end
	end)
	
	-- Block normal Use action on killmovable targets when Use key killmoves are enabled
	hook.Add("PlayerUse", "BSModBlockUseOnKillmove", function(ply, ent)
		if GetCVarInt(cv_use_key) == 0 then return end
		if ply.inKillMove then return false end
		if ply.bsmod_pending_killmove then return false end
		
		-- Block Use on NPCs/players that could be killmoved to prevent interference
		if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer()) then
			local canKillmove = ent.killMovable or GetCVarInt(cv_anytime) ~= 0
			
			if not canKillmove and GetCVarInt(cv_anytime_behind) ~= 0 then
				local vec = (ply:GetPos() - ent:GetPos()):GetNormal():Angle().y
				local targetAngle = ent:EyeAngles().y % 360
				if targetAngle < 0 then targetAngle = targetAngle + 360 end
				local angleAround = (vec - targetAngle) % 360
				if angleAround < 0 then angleAround = angleAround + 360 end
				canKillmove = angleAround > 135 and angleAround <= 225
			end
			
			if canKillmove then
				return false
			end
		end
	end)
	
	-- Reset killmove state on spawn (fixes issues after level transitions)
	hook.Add("PlayerInitialSpawn", "BSModPlayerInitialSpawn", function(ply)
		if ply.inKillMove then
			ply:DrawShadow( true )
			
			if ply:IsPlayer() then
				ply:SetMaterial(ply.prevMaterialBSMod)
			else
				ply:SetNoDraw(false)
			end
			
			ply:DrawWorldModel(true)
			
			-- Restore weapon and viewmodel visibility
			if IsValid(ply.prevWeaponBSMod) then
				ply.prevWeaponBSMod:SetNoDraw(false)
			end
			local vm = ply:GetViewModel()
			if IsValid(vm) then
				vm:SetNoDraw(false)
			end
			
			ply:SetMoveType(MOVETYPE_WALK)
			ply:UnLock()
			
			if IsValid(ply.kmModel) then 
				for i, ent in ipairs(ply.kmModel:GetChildren()) do 
					ent:SetParent(ply, ent:GetParentAttachment()) 
					ent:SetLocalPos(vector_origin)
					ent:SetLocalAngles(angle_zero)
				end 
				
				ply.kmModel:Remove() 
			end
			if IsValid(ply.kmAnim) then ply.kmAnim:Remove() end
			
			if IsValid(ply.prevTargetBSMod) then
				if IsValid(ply.prevTargetBSMod.kmModel) then 
					for i, ent in ipairs(ply.prevTargetBSMod.kmModel:GetChildren()) do 
						ent:SetParent(ply.prevTargetBSMod, ent:GetParentAttachment()) 
						ent:SetLocalPos(vector_origin)
						ent:SetLocalAngles(angle_zero)
					end 
					
					ply.prevTargetBSMod.kmModel:Remove()
				end
				if IsValid(ply.prevTargetBSMod.kmAnim) then ply.prevTargetBSMod.kmAnim:Remove() end
				
				ply.prevTargetBSMod:Remove()
			end
			
			if ply.prevGodModeBSMod then
				ply:GodEnable(true)
			end
			
			ply.prevTargetBSMod = nil
			ply.prevWeaponBSMod = nil
			ply.prevGodModeBSMod = nil
			ply.prevMaterialBSMod = nil
			
			ply:SetInKillMove(false)
			
			-- Spawn health pickup if enabled
			if ply:Health() < ply:GetMaxHealth() then
				local spawnVial = GetCVarInt(cv_spawn_healthvial) ~= 0
				local spawnKit = GetCVarInt(cv_spawn_healthkit) ~= 0
				local healthToSpawn = 0
				
				if spawnVial and spawnKit then
					healthToSpawn = math_random(1, 2)
				elseif spawnVial then
					healthToSpawn = 1
				elseif spawnKit then
					healthToSpawn = 2
				end
				
				if healthToSpawn == 1 then
					local vial = ents.Create("item_healthvial")
					vial:SetPos(ply:GetPos())
					vial:Spawn()
				elseif healthToSpawn == 2 then
					local kit = ents.Create("item_healthkit")
					kit:SetPos(ply:GetPos())
					kit:Spawn()
				end
			end
		end
	end)
	
	hook.Add("EntityTakeDamage", "BSModTakeDamage", function(ent, dmginfo)
		if ent.inKillMove then dmginfo:SetDamage(0) end
		
		if ent.blocking then return end
		
		-- This happens before the damage is taken
		if not ent:IsPlayer() and not ent:IsNPC() and not ent:IsNextBot() then return end
		
		local dmg = dmginfo:GetDamage()
		local attacker = dmginfo:GetAttacker()
		
		if dmg >= ent:Health() and ent.killMovable then
			ent:SetKillMovable(false)
		end
		
		-- Cache ConVar values before the timer (they won't change during this tick)
		local enableNpcs = GetCVarInt(cv_enable_npcs)
		local enablePlayers = GetCVarInt(cv_enable_players)
		local playerDmgOnly = GetCVarInt(cv_player_damage_only)
		local chance = GetCVarInt(cv_chance)
		local minHealth = GetCVarInt(cv_minhealth)
		local anytime = GetCVarInt(cv_anytime)
		local kmTime = GetCVarFloat(cv_time)
		
		timer.Simple(0, function()
			-- This happens after the damage is taken
			if not IsValid(ent) then return end
			
			if (ent:IsNPC() or ent:IsNextBot()) and enableNpcs == 0 then return end
			if ent:IsPlayer() and (enablePlayers == 0 or ent:HasGodMode()) then return end
			
			-- Check bones with early break
			local canSetKillMovable = false
			for _, bone in ipairs(killMovableBones) do
				if ent:LookupBone(bone) then 
					canSetKillMovable = true
					break  -- Performance: stop checking once found
				end
			end
			
			-- Only check entity names if bones didn't match
			if not canSetKillMovable then
				local entClass = ent:GetClass()
				for _, entName in ipairs(killMovableEnts) do
					if entClass == entName then 
						canSetKillMovable = true
						break  -- Performance: stop checking once found
					end
				end
			end
			
			if playerDmgOnly == 1 and IsValid(attacker) and not attacker:IsPlayer() then 
				canSetKillMovable = false 
			end
			
			if not canSetKillMovable then return end
			
			-- All conditions check
			if math_random(1, chance) == 1 and IsValid(ent) and not ent.inKillMove and not ent.killMovable and not ent.blocking and ent:Health() <= minHealth and ent:Health() > 0 and anytime == 0 then
				ent:SetKillMovable(true)
				
				if kmTime > 0 then
					timer.Simple(kmTime, function()
						if not IsValid(ent) then return end
						ent:SetKillMovable(false)
					end)
				end
			end
		end)
	end)
	
	function PlayRandomSound(ent, min, max, snd)
		local rand = math.random(min, max)
		
		ent:EmitSound("" .. snd .. rand .. ".wav", 100, 100, 0.5, CHAN_AUTO )
	end
	
	function entmeta:GetHeadBone()
		return self:LookupBone("ValveBiped.Bip01_Head1") or self:LookupBone("ValveBiped.HC_Body_Bone") or self:LookupBone("ValveBiped.HC_BodyCube") or self:LookupBone("ValveBiped.Headcrab_Cube1")
	end
	
	function plymeta:DoKMEffects(animName, plyModel, targetModel)
		
		local headBone = nil
		
		if IsValid (targetModel) then headBone = targetModel:GetHeadBone() end
		
		if animName == "killmove_front_1" then
			timer.Simple(0.3, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 5, "player/killmove/km_hit")
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
			
			timer.Simple(0.8, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 1, "player/killmove/km_punch")
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
		elseif animName == "killmove_front_2" then
			timer.Simple(0.25, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 5, "player/killmove/km_hit")
			end)
			
			timer.Simple(0.45, function()
				if !IsValid(targetModel) then return end
				
				if plyModel:LookupBone("ValveBiped.Bip01_R_Foot") then
					local effectdata = EffectData()
					effectdata:SetOrigin(plyModel:GetBonePosition(plyModel:LookupBone("ValveBiped.Bip01_R_Foot")))
					util.Effect("BloodImpact", effectdata)
				end
			end)
			
			timer.Simple(1, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 2, "player/killmove/km_gorehit")
			end)
			
			timer.Simple(1.1, function()
				if !IsValid(targetModel) then return end
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
		elseif animName == "killmove_hunter_front_1" then
			
			timer.Simple(0.5, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 1, "player/killmove/km_grapple")
			end)
			
			timer.Simple(1.3, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 3, "player/killmove/km_stabin")
				PlayRandomSound(self, 1, 2, "player/killmove/km_gorehit")
				PlayRandomSound(self, 1, 2, "npc/ministrider/hunter_foundenemy")
			end)
			
			timer.Simple(2, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 2, "player/killmove/km_stabout")
			end)
		elseif animName == "killmove_front_air_1" then
			timer.Simple(0.25, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 5, "player/killmove/km_hit")
			end)
			
			timer.Simple(1, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 2, "player/killmove/km_gorehit")
			end)
			
			timer.Simple(1.25, function()
				if !IsValid(targetModel) then return end
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
		elseif animName == "killmove_left_1" then
			timer.Simple(0.3, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 1, "player/killmove/km_punch")
			end)
			
			timer.Simple(0.325, function()
				if !IsValid(targetModel) then return end
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(plyModel:GetBonePosition(plyModel:LookupBone("ValveBiped.Bip01_R_Foot")))
					util.Effect("BloodImpact", effectdata)
				end
			end)
			
			timer.Simple(1, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 2, "player/killmove/km_gorehit")
			end)
			
			timer.Simple(1.15, function()
				if !IsValid(targetModel) then return end
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
		elseif animName == "killmove_right_1" then
			timer.Simple(0.2, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 5, "player/killmove/km_hit")
			end)
			
			timer.Simple(0.35, function()
				if !IsValid(targetModel) then return end
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
			
			timer.Simple(0.8, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 1, "player/killmove/km_punch")
			end)
			
			timer.Simple(1.0, function()
				if !IsValid(targetModel) then return end
				
				if headBone ~= nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
			
		elseif animName == "killmove_back_1" then
			timer.Simple(0.5, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 3, "player/killmove/km_bonebreak")
			end)
		end
		
		-- FOV effect for killmoves
		if GetCVarInt(cv_fovfx) == 1 then
			local fovValue = GetCVarInt(cv_fov_value)
			if fovValue > 0 then
				timer.Simple(0.2, function()
					if IsValid(self) and self:IsPlayer() then
						self:SetFOV(fovValue, 0.2)
					end
				end)
			end
		end
		
		hook.Run("CustomKMEffects", self, animName, targetModel)
	end
	
	-- Reusable trace structures (avoids table allocation each call)
	local kmTraceLineData = { start = Vector(), endpos = Vector(), filter = nil }
	local kmTraceHullData = { start = Vector(), endpos = Vector(), filter = nil, mins = Vector(-1, -1, -1), maxs = Vector(1, 1, 1) }
	
	-- Check if player model is valid for killmoves (has required bones)
	local function IsValidKillMoveModel(ply)
		if not IsValid(ply) then return false end
		
		-- Check for essential bones that killmove animations need
		local hasSpine = ply:LookupBone("ValveBiped.Bip01_Spine") ~= nil
		local hasHead = ply:LookupBone("ValveBiped.Bip01_Head1") ~= nil
		local hasRightHand = ply:LookupBone("ValveBiped.Bip01_R_Hand") ~= nil
		
		-- Must have at least spine and one other essential bone
		return hasSpine and (hasHead or hasRightHand)
	end
	
	--[[
		BSMod Framework for Extension Mods
		
		=== POSITION DETECTION ===
		The base mod detects these position types and stores them on the player:
		- ply.bsmod_km_position_type: Full position string (e.g. "ground_front", "air_back", "water_left")
		- ply.bsmod_km_direction: Direction only ("front", "back", "left", "right")
		- ply.bsmod_km_in_water: Boolean, true if player is in water (WaterLevel >= 2)
		- ply.bsmod_km_in_air: Boolean, true if player is in air (not on ground, not in water)
		- ply.bsmod_km_cover_state: "none", "cover", or "dfb"
		- ply.bsmod_km_cover_entity: The entity providing cover (door, prop, etc.) or nil
		
		Supported position types (18 total):
		Ground: ground_front, ground_back, ground_left, ground_right
		Air (DFA): air_front, air_back, air_left, air_right
		Water: water_front, water_back, water_left, water_right
		Cover: cover_front, cover_back (obstacle between player and target)
		DFB: dfb_front, dfb_back (Death From Below - target above player)
		
		=== TARGET DETECTION ===
		- ply.bsmod_km_target_type: "player", "hunter", "zombie", "combine", "antlion", "headcrab", "vj_npc", or "human"
		- ply.bsmod_km_target_crouching: Boolean, true if target is crouching
		
		=== WEAPON DETECTION ===
		- ply.bsmod_km_player_weapon_type: "unarmed", "melee", "pistol", or "rifle"
		
		=== HOOKS ===
		- hook.Add("BSMod_KillMoveStarted", "YourMod", function(ply, target, animName, positionType) end)
		- hook.Add("BSMod_KillMoveEnded", "YourMod", function(ply, target, positionType) end)
		- hook.Add("CustomKillMoves", "YourMod", function(ply, target, angleAround) return kmData end)
		- hook.Add("CustomKMEffects", "YourMod", function(ply, animName, targetModel) end)
		- hook.Add("KMRagdoll", "YourMod", function(entity, ragdoll, animName) end)
		
		=== HELPER FUNCTION ===
		BSMod_GetKillMovePosition(ply, target, angleAround) - Returns: positionType, direction, inWater, inAir, coverState, coverEntity
	]]
	
	-- Helper function for extension mods to get killmove position info
	-- Returns: positionType, direction, inWater, inAir, coverState
	-- Valid cover object classes for cover/DFB detection
	local validCoverClasses = {
		["prop_door_rotating"] = true,
		["func_door_rotating"] = true,
		["func_door"] = true,
		["func_brush"] = true,
		["func_breakable"] = true,
		["prop_dynamic"] = true,
		["func_wall_toggle"] = true,
		["prop_physics"] = true,
		["func_physbox"] = true,
	}
	
	-- Helper function for extension mods to get killmove position info
	-- Returns: positionType, direction, inWater, inAir, coverState, coverEntity
	function BSMod_GetKillMovePosition(ply, target, angleAround)
		local inWater = ply:WaterLevel() >= 2
		local onGround = ply:OnGround()
		local inAir = not onGround and not inWater
		
		-- Cover/DFB detection (improved)
		local coverState = "none"
		local coverEntity = nil
		
		if onGround then
			local eyePos = ply:EyePos()
			local playerPos = ply:GetPos()
			local targetPos = target:GetPos()
			local startPos = eyePos + Vector(0, 0, -20)
			
			local coverTrace = util.TraceLine({
				start = startPos,
				endpos = targetPos,
				filter = {ply, target}
			})
			
			if coverTrace.Hit and coverTrace.Entity then
				local hitZ = coverTrace.HitPos.z
				local hitEnt = coverTrace.Entity
				local isValidCover = hitEnt:IsWorld() or validCoverClasses[hitEnt:GetClass()]
				
				if isValidCover then
					if hitZ > eyePos.z then
						coverState = "dfb"
					elseif hitZ > playerPos.z + 20 then
						coverState = "cover"
					end
					coverEntity = hitEnt
				end
			end
			
			-- Additional DFB check for elevated targets
			if coverState == "none" then
				local heightDiff = targetPos.z - playerPos.z
				if heightDiff > 48 then
					local ledgeTrace = util.TraceLine({
						start = targetPos + Vector(0, 0, 10),
						endpos = targetPos - Vector(0, 0, 100),
						filter = target
					})
					if ledgeTrace.Hit and ledgeTrace.HitPos.z > playerPos.z + 32 then
						coverState = "dfb"
					end
				end
			end
		end
		
		-- Direction
		local direction = "front"
		if angleAround <= 45 or angleAround > 315 then
			direction = "front"
		elseif angleAround > 45 and angleAround <= 135 then
			direction = "left"
		elseif angleAround > 135 and angleAround <= 225 then
			direction = "back"
		elseif angleAround > 225 and angleAround <= 315 then
			direction = "right"
		end
		
		-- Build position type
		local positionType = "ground_" .. direction
		if inWater then
			positionType = "water_" .. direction
		elseif inAir then
			positionType = "air_" .. direction
		elseif coverState == "cover" and (direction == "front" or direction == "back") then
			positionType = "cover_" .. direction
		elseif coverState == "dfb" and (direction == "front" or direction == "back") then
			positionType = "dfb_" .. direction
		end
		
		return positionType, direction, inWater, inAir, coverState, coverEntity
	end
	
	-- Check if player can killmove
	function KMCheck(ply)
		if ply.inKillMove then return false end
		
		-- Check if player's model is valid for killmoves
		if not IsValidKillMoveModel(ply) then return false end
		
		-- Reuse trace structures instead of creating new tables
		local eyePos = ply:EyePos()
		local forward = ply:EyeAngles():Forward() * 100
		
		kmTraceLineData.start = eyePos
		kmTraceLineData.endpos = eyePos + forward
		kmTraceLineData.filter = ply
		
		local tr = util.TraceLine(kmTraceLineData)
		
		if not IsValid(tr.Entity) then
			kmTraceHullData.start = eyePos
			kmTraceHullData.endpos = eyePos + forward
			kmTraceHullData.filter = ply
			tr = util.TraceHull(kmTraceHullData)
		end
		
		if not IsValid(tr.Entity) then return false end
		
		local target = tr.Entity
		
		if not target:IsPlayer() and not target:IsNPC() and not target:IsNextBot() then return false end
		
		if ply.inKillMove or ply:Health() <= 0 or target.inKillMove or target == ply then return false end
		
		-- Cache ConVar values for this check
		local enablePlayers = GetCVarInt(cv_enable_players)
		local enableNpcs = GetCVarInt(cv_enable_npcs)
		local enableTeammates = GetCVarInt(cv_enable_teammates)
		local anytime = GetCVarInt(cv_anytime)
		local anytimeBehind = GetCVarInt(cv_anytime_behind)
		local disableDefaults = GetCVarInt(cv_disable_defaults)
		
		if target:IsPlayer() then
			if enablePlayers == 0 or target:HasGodMode() then return false end 
			if engine.ActiveGamemode() ~= "sandbox" and enableTeammates == 0 then 
				if target:Team() == ply:Team() then return false end 
			end
		end
		
		if (target:IsNPC() or target:IsNextBot()) and enableNpcs == 0 then return false end
		
		-- Direction check for killmoves (using modulo for cleaner angle normalization)
		local vec = (ply:GetPos() - target:GetPos()):GetNormal():Angle().y
		local targetAngle = target:EyeAngles().y % 360
		if targetAngle < 0 then targetAngle = targetAngle + 360 end
		
		local angleAround = (vec - targetAngle) % 360
		if angleAround < 0 then angleAround = angleAround + 360 end
		
		if anytime == 0 then
			if anytimeBehind == 0 then 
				if not target.killMovable then
					return false 
				end
			elseif not target.killMovable and not (angleAround > 135 and angleAround <= 225) then
				return false
			end
		end
		
		-- Setup killmove values
		local plyKMModel = ""
		local targetKMModel = ""
		local animName = ""
		local plyKMPosition = nil
		local plyKMAngle = nil
		local plyKMTime = nil
		local targetKMTime = nil
		local moveTarget = false
		
		-- Pre-calculate position info for extension mods BEFORE calling CustomKillMoves hook
		-- This allows extension mods to use ply.bsmod_km_* values
		local inWater = ply:WaterLevel() >= 2
		local onGround = ply:OnGround()
		local inAir = not onGround and not inWater
		
		-- Cover/DFB detection (improved with proper obstacle checking)
		local coverState = "none"
		local coverEntity = nil -- Store the cover entity for extension mods
		
		if onGround then
			local eyePos = ply:EyePos()
			local playerPos = ply:GetPos()
			local targetPos = target:GetPos()
			
			-- Trace from slightly below eye level to target
			local startPos = eyePos + Vector(0, 0, -20)
			
			local coverTrace = util.TraceLine({
				start = startPos,
				endpos = targetPos,
				filter = {ply, target}
			})
			
			if coverTrace.Hit and coverTrace.Entity then
				local hitZ = coverTrace.HitPos.z
				local hitEnt = coverTrace.Entity
				local hitClass = hitEnt:GetClass()
				
				-- Check if it's a valid cover object (doors, props, brushes, etc.)
				local validCoverClasses = {
					["prop_door_rotating"] = true,
					["func_door_rotating"] = true,
					["func_door"] = true,
					["func_brush"] = true,
					["func_breakable"] = true,
					["prop_dynamic"] = true,
					["func_wall_toggle"] = true,
					["prop_physics"] = true,
					["func_physbox"] = true,
				}
				
				-- World geometry or valid cover entity
				local isValidCover = hitEnt:IsWorld() or validCoverClasses[hitClass]
				
				if isValidCover then
					if hitZ > eyePos.z then
						-- Target is significantly above player (DFB - Death From Below)
						coverState = "dfb"
					elseif hitZ > playerPos.z + 20 then
						-- Obstacle at mid-height between player and target (Cover)
						coverState = "cover"
					end
					coverEntity = hitEnt
				end
			end
			
			-- Additional height check for DFB (target on ledge above player)
			if coverState == "none" then
				local heightDiff = targetPos.z - playerPos.z
				if heightDiff > 48 then -- Target is more than ~crouching height above
					-- Check if there's ground under the target (they're on a ledge)
					local ledgeTrace = util.TraceLine({
						start = targetPos + Vector(0, 0, 10),
						endpos = targetPos - Vector(0, 0, 100),
						filter = target
					})
					if ledgeTrace.Hit and ledgeTrace.HitPos.z > playerPos.z + 32 then
						coverState = "dfb"
					end
				end
			end
		end
		
		-- Store cover entity for extension mods that might want it
		ply.bsmod_km_cover_entity = coverEntity
		
		-- Target type detection for specialized animations
		local targetType = "human" -- Default
		local targetClass = target:GetClass()
		
		if target:IsPlayer() then
			targetType = "player"
		elseif target:LookupBone("MiniStrider.body_joint") then
			targetType = "hunter"
		elseif targetClass:find("zombie") or targetClass:find("fastzombie") or targetClass:find("poisonzombie") then
			targetType = "zombie"
		elseif targetClass:find("combine") or targetClass:find("metropolice") or targetClass:find("soldier") then
			targetType = "combine"
		elseif targetClass:find("antlion") then
			targetType = "antlion"
		elseif targetClass:find("headcrab") then
			targetType = "headcrab"
		elseif target.IsVJBaseSNPC then
			targetType = "vj_npc"
		end
		
		-- Target stance detection
		local targetCrouching = false
		if target:IsPlayer() then
			targetCrouching = target:Crouching()
		elseif target:IsNPC() then
			-- NPCs don't have a direct crouch check, estimate from height
			local mins, maxs = target:GetCollisionBounds()
			targetCrouching = (maxs.z - mins.z) < 50
		end
		
		-- Player weapon detection for weapon-specific killmoves
		local playerWeaponType = "unarmed"
		local activeWeapon = ply:GetActiveWeapon()
		if IsValid(activeWeapon) then
			local wepClass = activeWeapon:GetClass()
			if wepClass:find("knife") or wepClass:find("crowbar") or wepClass:find("stunstick") then
				playerWeaponType = "melee"
			elseif wepClass:find("pistol") or wepClass:find("357") or wepClass:find("deagle") then
				playerWeaponType = "pistol"
			elseif wepClass:find("smg") or wepClass:find("ar2") or wepClass:find("shotgun") or wepClass:find("rifle") then
				playerWeaponType = "rifle"
			elseif activeWeapon.Primary and activeWeapon.Primary.ClipSize then
				-- Generic weapon detection
				if activeWeapon.Primary.ClipSize <= 20 then
					playerWeaponType = "pistol"
				else
					playerWeaponType = "rifle"
				end
			end
		end
		
		-- Store all detection info for extension mods
		ply.bsmod_km_target_type = targetType
		ply.bsmod_km_target_crouching = targetCrouching
		ply.bsmod_km_player_weapon_type = playerWeaponType
		
		-- Direction
		local direction = "front"
		if angleAround <= 45 or angleAround > 315 then
			direction = "front"
		elseif angleAround > 45 and angleAround <= 135 then
			direction = "left"
		elseif angleAround > 135 and angleAround <= 225 then
			direction = "back"
		elseif angleAround > 225 and angleAround <= 315 then
			direction = "right"
		end
		
		-- Build position type
		local positionType = "ground_" .. direction
		if inWater then
			positionType = "water_" .. direction
		elseif inAir then
			positionType = "air_" .. direction
		elseif coverState == "cover" and (direction == "front" or direction == "back") then
			positionType = "cover_" .. direction
		elseif coverState == "dfb" and (direction == "front" or direction == "back") then
			positionType = "dfb_" .. direction
		end
		
		-- Store on player for extension mods to use
		ply.bsmod_km_position_type = positionType
		ply.bsmod_km_direction = direction
		ply.bsmod_km_in_water = inWater
		ply.bsmod_km_in_air = inAir
		ply.bsmod_km_cover_state = coverState
		
		-- Custom killmove hook (extension mods can now use ply.bsmod_km_* values)
		local customKMData = hook.Run("CustomKillMoves", ply, target, angleAround)
		
		if customKMData then
			if customKMData[1] ~= nil then plyKMModel = customKMData[1] end
			if customKMData[2] ~= nil then targetKMModel = customKMData[2] end
			if customKMData[3] ~= nil then animName = customKMData[3] end
			if customKMData[4] ~= nil then plyKMPosition = customKMData[4] end
			if customKMData[5] ~= nil then plyKMAngle = customKMData[5] end
			if customKMData[6] ~= nil then plyKMTime = customKMData[6] end
			if customKMData[7] ~= nil then targetKMTime = customKMData[7] end
			if customKMData[8] ~= nil then moveTarget = customKMData[8] end
		end
		
		-- Default killmoves with expanded position detection
		-- Supports: Ground, Air (DFA), Water, Cover, DFB for all directions
		-- Position info already calculated above and stored in ply.bsmod_km_* values
		if animName == "" and disableDefaults == 0 then
			plyKMModel = "models/weapons/c_limbs.mdl"
			
			if target:LookupBone("ValveBiped.Bip01_Spine") then
				targetKMModel = "models/bsmodimations_human.mdl"
				
				-- Select animation based on position type
				-- Default animations exist for basic ground types and air_front
				-- Extended types fall back to closest matching default animation
				if positionType == "ground_front" then
					animName = "killmove_front_" .. math_random(1, 2)
					if animName == "killmove_front_1" then targetKMTime = 1.15 end
				elseif positionType == "ground_left" then
					animName = "killmove_left_1"
				elseif positionType == "ground_back" then
					animName = "killmove_back_1"
				elseif positionType == "ground_right" then
					animName = "killmove_right_1"
				elseif positionType == "air_front" then
					animName = "killmove_front_air_1"
				-- Extended position types: fall back to direction-based defaults
				-- Extension mods can override via CustomKillMoves hook
				elseif direction == "front" then
					-- air_front already handled above, this catches water/cover/dfb front
					animName = "killmove_front_" .. math_random(1, 2)
					if animName == "killmove_front_1" then targetKMTime = 1.15 end
				elseif direction == "back" then
					-- air_back, water_back, cover_back, dfb_back all fall back to ground back
					animName = "killmove_back_1"
				elseif direction == "left" then
					-- air_left, water_left fall back to ground left
					animName = "killmove_left_1"
				elseif direction == "right" then
					-- air_right, water_right fall back to ground right
					animName = "killmove_right_1"
				end
			elseif target:LookupBone("MiniStrider.body_joint") then
				targetKMModel = "models/bsmodimations_hunter.mdl"
				animName = "killmove_hunter_front_1"
			end
			
			-- Cache target vectors for position calculation
			local targetPos = target:GetPos()
			local targetForward = target:GetForward()
			local targetRight = target:GetRight()
			
			-- Position player based on animation
			if animName == "killmove_left_1" then
				plyKMPosition = targetPos + (-targetRight * 31.5)
				plyKMAngle = targetRight:Angle()
			elseif animName == "killmove_right_1" then
				plyKMPosition = targetPos + (targetRight * 95) + (targetForward * 10)
				plyKMAngle = (-targetRight):Angle()
			elseif animName == "killmove_back_1" then
				plyKMPosition = targetPos + (-targetForward * 30)
				plyKMAngle = targetForward:Angle()
			elseif animName == "killmove_front_1" then
				plyKMPosition = targetPos + (targetForward * 31.5)
			elseif animName == "killmove_front_2" then
				plyKMPosition = targetPos + (targetForward * 29)
			elseif animName == "killmove_front_air_1" then
				plyKMPosition = targetPos + (targetForward * 39)
			elseif animName == "killmove_hunter_front_1" then
				plyKMPosition = targetPos + (targetForward * 31.5)
			-- Default positions for extended types (extension mods can override via CustomKillMoves)
			elseif direction == "front" then
				plyKMPosition = targetPos + (targetForward * 32)
			elseif direction == "back" then
				plyKMPosition = targetPos + (-targetForward * 32)
				plyKMAngle = targetForward:Angle()
			elseif direction == "left" then
				plyKMPosition = targetPos + (-targetRight * 32)
				plyKMAngle = targetRight:Angle()
			elseif direction == "right" then
				plyKMPosition = targetPos + (targetRight * 32)
				plyKMAngle = (-targetRight):Angle()
			end
		end
		
		ply:KillMove(target, animName, plyKMModel, targetKMModel, plyKMPosition, plyKMAngle, plyKMTime, targetKMTime, moveTarget)
		
		return true
	end
	
	concommand.Add("bsmod_killmove", KMCheck)

	local function ApplyKillmoveDamage(self, target)
		if not IsValid(target) then return end

		-- Mark target for death sound muting (blocks all sounds from this entity)
		target.bsmod_killed_by_killmove = true
		
		-- Clear the flag after 2 seconds (in case entity somehow survives or for cleanup)
		timer.Simple(2, function()
			if IsValid(target) then
				target.bsmod_killed_by_killmove = nil
			end
		end)

		local inflictor = ents.Create("weapon_bsmod_killmove")
		if IsValid(inflictor) then
			inflictor:SetPos(target:GetPos())
			inflictor:SetNoDraw(true)
			inflictor:SetNotSolid(true)
			inflictor:Spawn()
			inflictor:Activate()
		end

		local dmginfo = DamageInfo()
		dmginfo:SetAttacker(self)
		dmginfo:SetInflictor(inflictor or self)
		dmginfo:SetDamage(999999)
		dmginfo:SetDamageType(DMG_DIRECT)
		dmginfo:SetDamageCustom(74819263)
		dmginfo:SetDamageForce(Vector(0,0,0))
		dmginfo:SetDamagePosition(target:GetPos())

		target:TakeDamageInfo(dmginfo)

		if IsValid(inflictor) then
			inflictor:Remove()
		end
	end

	-- Now this function has a lot of arguments but that's cuz custom killmoves will use them, nothing else I can do :P
	function plymeta:KillMove(target, animName, plyKMModel, targetKMModel, plyKMPosition, plyKMAngle, plyKMTime, targetKMTime, moveTarget)
		if plyKMModel == "" or targetKMModel == "" or animName == "" then return end
		
		if self.inKillMove or self:Health() <= 0 or not IsValid(target) or target.inKillMove or target == self then return end
		
		-- Validate player model has required bones (safety check)
		if not IsValidKillMoveModel(self) then return end
		
		-- End of return checks
		
		net.Start("debugbsmodcalcview")
		net.Broadcast()
		
		self:SetInKillMove(true)
		
		-- Fire hook for extension mods to react to killmove starting
		-- Passes: player, target, animName, positionType
		hook.Run("BSMod_KillMoveStarted", self, target, animName, self.bsmod_km_position_type)
		
		local tempSelf, tempTarget
		
		-- Reverse player and target identifiers if target is set to move instead
		if moveTarget then 
			tempSelf = target
			tempTarget = self
		else
			tempSelf = self
			tempTarget = target
		end

		if tempSelf:OnGround() then
			tempSelf:SetVelocity(Vector(0, 0, 0)) -- Reset velocity
		end

		local startPosition = tempSelf:GetPos()
		local startAngle = tempSelf:EyeAngles()
		local wasOnGround = tempSelf:IsOnGround() -- Store ground state BEFORE any modifications

		local tarstartPositon = target:GetPos()
		local tarstartAngle = target:GetAngles()
		
		-- IMPORTANT: These must be LOCAL to prevent cross-contamination between killmoves
		local targetPosition
		local targetAngle

		if plyKMPosition ~= nil then
			targetPosition = plyKMPosition
		else
			targetPosition = tempTarget:GetPos() + (tempTarget:GetForward() * 40)
		end
		
		-- Dynamic hull fix - only adjust position if player would be stuck
		if GetCVarInt(cv_hull_fix) ~= 0 then
			local stuckCheck = util.TraceHull({
				start = targetPosition + Vector(0, 0, 1),
				endpos = targetPosition + Vector(0, 0, 1),
				filter = {self, target},
				mins = self:OBBMins(),
				maxs = self:OBBMaxs(),
				mask = MASK_PLAYERSOLID
			})
			
			if stuckCheck.StartSolid then
				local groundTrace = util.TraceLine({
					start = targetPosition + Vector(0, 0, 72),
					endpos = targetPosition - Vector(0, 0, 10),
					filter = {self, target},
					mask = MASK_PLAYERSOLID
				})
				
				if groundTrace.Hit and not groundTrace.StartSolid then
					targetPosition.z = groundTrace.HitPos.z + 1
				end
			end
		end
		
		-- Player Angle - calculate AFTER targetPosition is set
		local hasCustomAngle = plyKMAngle ~= nil
		if hasCustomAngle then
			-- Use custom angle from addon (will snap immediately, not lerp)
			targetAngle = plyKMAngle
		else
			-- Default: face the target from the DESTINATION position (not starting position)
			targetAngle = (Vector(tarstartPositon.x, tarstartPositon.y, 0) - Vector(targetPosition.x, targetPosition.y, 0)):Angle()
		end

		local lerpEnabled = GetCVarInt(cv_lerp_enable) ~= 0

		self:ConCommand( "-duck" )
		self:SetMoveType(MOVETYPE_NONE)

		-- If lerp is disabled, set position/angle immediately
		if !lerpEnabled then
			tempSelf:SetPos(targetPosition)
			tempSelf:SetAngles(targetAngle)
			if tempSelf:IsPlayer() then tempSelf:SetEyeAngles(targetAngle) end
		end
		
		self.prevTargetBSMod = target
		self.prevWeaponBSMod = nil
		self.prevGodModeBSMod = self:HasGodMode()
		self.prevMaterialBSMod = self:GetMaterial()
		
		if IsValid(self:GetActiveWeapon()) then
			self.prevWeaponBSMod = self:GetActiveWeapon()
		end
		
		if self.killMovable then self:SetKillMovable(false) end
		
		if !lerpEnabled then
			self:Lock()
		end
		self:SetVelocity(-self:GetVelocity())
		self:SetMaterial("null")
		self:DrawShadow( false )
		
		net.Start("removedecals")
		net.WriteEntity(self)
		net.Broadcast()
		
		--Spawn the players animation model
		
		if IsValid(self.kmAnim) then self.kmAnim:Remove() end
		
		self.kmAnim = ents.Create("ent_km_model")
		self.kmAnim:SetPos(startPosition)
		self.kmAnim:SetAngles(startAngle)
		self.kmAnim:SetModel(plyKMModel)
		self.kmAnim:SetOwner(self)
		
		for i = 0, self:GetBoneCount() - 1 do 
			 local bone = self.kmAnim:LookupBone(self:GetBoneName(i))
			if bone then
				self.kmAnim:ManipulateBonePosition(bone, self:GetManipulateBonePosition(i))
				self.kmAnim:ManipulateBoneAngles(bone, self:GetManipulateBoneAngles(i))
				self.kmAnim:ManipulateBoneScale(bone, self:GetManipulateBoneScale(i))
			end
		end
		
		self.kmAnim:SetModelScale(self:GetModelScale())
		
		self.kmAnim:Spawn()
		
		--Spawn the players model and bonemerge it to the animation model
		
		if IsValid(self.kmModel) then self.kmModel:Remove() end
		
		self.kmModel = ents.Create("ent_km_model")
		self.kmModel:SetPos(startPosition)
		self.kmModel:SetAngles(startAngle)
		self.kmModel:SetModel(self:GetModel())
		self.kmModel:SetSkin(self:GetSkin())
		self.kmModel:SetColor(self:GetColor())
		self.kmModel:SetMaterial(self.prevMaterialBSMod)
		self.kmModel:SetRenderMode(self:GetRenderMode())
		self.kmModel:SetOwner(self)
		
		if IsValid(self:GetActiveWeapon()) then self.kmModel.Weapon = self:GetActiveWeapon() end
		
		for _, bodygroup in ipairs(self:GetBodyGroups()) do
			self.kmModel:SetBodygroup(bodygroup.id, self:GetBodygroup(bodygroup.id))
		end
		
		for i, ent in ipairs(self:GetChildren()) do 
			ent:SetParent(self, ent:GetParentAttachment()) 
			ent:SetLocalPos(vector_origin)
			ent:SetLocalAngles(angle_zero)
		end 
		
		self.kmModel.maxKMTime = plyKMTime
		self.kmModel:Spawn()
		
		self.kmModel:AddEffects(EF_BONEMERGE)
		self.kmModel:SetParent(self.kmAnim)
		
		-- Hide the player's previous weapon during killmove (fixes MW BASE and similar)
		-- NOTE: We don't switch weapons anymore to prevent weapon bases from resetting FOV
		if IsValid(self.prevWeaponBSMod) then
			self.prevWeaponBSMod:SetNoDraw(true)
		end
		
		-- Hide viewmodel during killmove
		local vm = self:GetViewModel()
		if IsValid(vm) then
			vm:SetNoDraw(true)
		end
		
		------------------------------------------------------------------------------------------
		
		local prevTMaterial = target:GetMaterial()
		
		target:SetKillMovable(false)
		target:SetInKillMove(true)
		
		if target:IsPlayer() then
			target:SetMaterial("null")
		else
			target:SetNoDraw(true)
		end
		
		target:DrawShadow( false )
		
		net.Start("removedecals")
		net.WriteEntity(target)
		net.Broadcast()
		
		if target.IsVJBaseSNPC then
			target:StopAttacks(true)
			target:SetState(VJ_STATE_FREEZE)
		elseif target:IsNPC() then
			target:SetCondition(67)
			target:SetNPCState(NPC_STATE_NONE)
		elseif target:IsPlayer() then
			--target:DrawWorldModel(false)
			--target:StripWeapons()
			target:Lock()
			self:SetVelocity(-self:GetVelocity())
		end
		
		--Now for the targets animation model
		
		if IsValid(target.kmAnim) then target.kmAnim:Remove() end
		
		target.kmAnim = ents.Create("ent_km_model")
		target.kmAnim:SetPos(target:GetPos())
		target.kmAnim:SetAngles(target:GetAngles())
		target.kmAnim:SetModel(targetKMModel)
		target.kmAnim:SetOwner(target)
		
		for i = 0, target:GetBoneCount() - 1 do 
			 local bone = target.kmAnim:LookupBone(target:GetBoneName(i))
			if bone then
				target.kmAnim:ManipulateBonePosition(bone, target:GetManipulateBonePosition(i))
				target.kmAnim:ManipulateBoneAngles(bone, target:GetManipulateBoneAngles(i))
				target.kmAnim:ManipulateBoneScale(bone, target:GetManipulateBoneScale(i))
			end
		end
		
		target.kmAnim:SetModelScale(target:GetModelScale())
		
		target.kmAnim:Spawn()
		
		--And the targets model
		
		if IsValid(target.kmModel) then target.kmModel:Remove() end
		
		target.kmModel = ents.Create("ent_km_model")
		target.kmModel:SetPos(target:GetPos())
		target.kmModel:SetAngles(target:GetAngles())
		target.kmModel:SetModel(target:GetModel())
		target.kmModel:SetSkin(target:GetSkin())
		target.kmModel:SetColor(target:GetColor())
		target.kmModel:SetMaterial(prevTMaterial)
		target.kmModel:SetRenderMode(target:GetRenderMode())
		target.kmModel:SetOwner(target)
		
		-- Store weapon reference and handle based on setting
		local dropTargetWeapons = GetCVarInt(cv_drop_target_weapons) ~= 0
		if not target:IsNextBot() then 
			if IsValid(target:GetActiveWeapon()) then 
				target.kmModel.Weapon = target:GetActiveWeapon()
				
				if target:IsNPC() and dropTargetWeapons then
					-- Store weapon class to drop later, remove weapon now to prevent engine drop
					local wep = target:GetActiveWeapon()
					target.bsmod_weapon_to_drop = wep:GetClass()
					target.bsmod_weapon_drop_pos = target:GetPos()
					wep:Remove()
					target.kmModel.Weapon = nil
				elseif target:IsNPC() or target:IsNextBot() then
					-- Keep weapon in hand - parent to killmove model so it follows the animation
					target:GetActiveWeapon():SetParent(target.kmModel)
				else
					-- Player target - just hide the weapon
					target:GetActiveWeapon():SetNoDraw(true)
				end
			end 
		end
		
		for i, bodygroup in ipairs(target:GetBodyGroups()) do
			target.kmModel:SetBodygroup(bodygroup.id, target:GetBodygroup(bodygroup.id))
		end
		
		for i, ent in ipairs(target:GetChildren()) do 
			if IsValid(ent) and ent:IsWeapon() then
				if target:IsNPC() and dropTargetWeapons then
					-- Store child weapon class to drop later, remove now
					if not target.bsmod_weapon_to_drop then
						target.bsmod_weapon_to_drop = ent:GetClass()
						target.bsmod_weapon_drop_pos = target:GetPos()
					end
					ent:Remove()
				else
					-- Keep weapon in hand - parent to killmove model so it follows the animation
					ent:SetParent(target.kmModel, ent:GetParentAttachment())
					ent:SetLocalPos(vector_origin)
					ent:SetLocalAngles(angle_zero)
				end
			else
				ent:SetParent(target.kmModel, ent:GetParentAttachment()) 
				ent:SetLocalPos(vector_origin)
				ent:SetLocalAngles(angle_zero)
			end
		end 
		
		target.kmModel:Spawn()
		
		target.kmModel:AddEffects(EF_BONEMERGE)
		target.kmModel:SetParent(target.kmAnim)
		
		-- Lerp functionality - animation starts immediately while player slides into position
		if lerpEnabled then
			-- Calculate fixed lerp duration based on initial distance (consistent speed)
			local initialDistance = (startPosition - targetPosition):Length()
			local lerpSpeed = GetCVarFloat(cv_lerp_speed)
			-- Minimum 0.15s lerp for noticeable smooth movement, max 0.5s
			local lerpDuration = math.Clamp(initialDistance / lerpSpeed, 0.15, 0.5)
			
			-- Store fixed start values for consistent lerping
			local lerpStartPos = startPosition
			local lerpStartAng = startAngle
			local lerpStartTime = CurTime()
			
			-- If in the air, skip lerp - set position instantly
			-- Use stored ground state from before killmove setup (prevents Use key interference)
			if !wasOnGround then
				-- Snap player to target position immediately
				tempSelf:SetPos(targetPosition)
				tempSelf:SetAngles(targetAngle)
				if tempSelf:IsPlayer() then tempSelf:SetEyeAngles(targetAngle) end
				
				-- Sync kmAnim to player's final position (use custom targetAngle, don't recalculate)
				self.kmAnim:SetPos(targetPosition)
				self.kmAnim:SetAngles(targetAngle)
				self.kmModel:SetPos(targetPosition)
				self.kmModel:SetAngles(targetAngle)
				
				-- Target stays in place
				target.kmAnim:SetPos(tarstartPositon)
				target.kmAnim:SetAngles(tarstartAngle)
				target.kmModel:SetPos(tarstartPositon)
				target.kmModel:SetAngles(tarstartAngle)
			else
				-- Ensure player starts at the captured start position (prevents Use key interference)
				tempSelf:SetPos(startPosition)
				tempSelf:SetAngles(startAngle)
				if tempSelf:IsPlayer() then tempSelf:SetEyeAngles(startAngle) end
				
				-- Helper function to lerp angles using shortest path
				local function LerpAngleShortestPath(t, from, to)
					local p = math.NormalizeAngle(from.p + t * math.AngleDifference(to.p, from.p))
					local y = math.NormalizeAngle(from.y + t * math.AngleDifference(to.y, from.y))
					local r = math.NormalizeAngle(from.r + t * math.AngleDifference(to.r, from.r))
					return Angle(p, y, r)
				end
				
				-- Start the lerp hook for smooth sliding
				hook.Add("Think", "KillMoveLerp" .. self:EntIndex(), function()
					if !IsValid(self) or !IsValid(target) then
						hook.Remove("Think", "KillMoveLerp" .. self:EntIndex())
						return
					end
					
					local progress = math.Clamp((CurTime() - lerpStartTime) / lerpDuration, 0, 1)
					
					-- Smooth easing (ease out quad)
					local easedProgress = 1 - (1 - progress) * (1 - progress)
					
					-- Lerp both position and angle smoothly (using shortest path for angles)
					local newPos = LerpVector(easedProgress, lerpStartPos, targetPosition)
					local newAng = LerpAngleShortestPath(easedProgress, lerpStartAng, targetAngle)
					
					tempSelf:SetPos(newPos)
					tempSelf:SetAngles(newAng)
					if tempSelf:IsPlayer() then
						tempSelf:SetEyeAngles(newAng)
					end
					
					-- Update kmAnim positions to follow player while sliding
					if IsValid(self.kmAnim) then
						self.kmAnim:SetPos(self:GetPos())
						self.kmAnim:SetAngles(newAng)
					end
					
					-- Target kmAnim stays at target position
					if IsValid(target.kmAnim) then
						target.kmAnim:SetPos(tarstartPositon)
						target.kmAnim:SetAngles(tarstartAngle)
					end
					
					-- Lerp complete - just remove the hook, animation is already playing
					if progress >= 1 then
						hook.Remove("Think", "KillMoveLerp" .. self:EntIndex())
						
						-- Final snap to exact position (use custom targetAngle, don't recalculate)
						tempSelf:SetPos(targetPosition)
						tempSelf:SetAngles(targetAngle)
						if tempSelf:IsPlayer() then tempSelf:SetEyeAngles(targetAngle) end
						
						self.kmAnim:SetPos(targetPosition)
						self.kmAnim:SetAngles(targetAngle)
					end
				end)
			end
			
			-- Lock player and start animation IMMEDIATELY (don't wait for lerp)
			self:Lock()
			self:PlayKillMoveAnimations(target, animName, plyKMTime, targetKMTime, prevTMaterial)
		else
			-- No lerp - sync kmAnim positions to where player ended up (use custom targetAngle)
			self.kmAnim:SetPos(self:GetPos())
			self.kmAnim:SetAngles(targetAngle)
			target.kmAnim:SetPos(tarstartPositon)
			target.kmAnim:SetAngles(tarstartAngle)
			
			timer.Simple(0, function()
				self:PlayKillMoveAnimations(target, animName, plyKMTime, targetKMTime, prevTMaterial)
			end)
		end
	end
	
	function plymeta:PlayKillMoveAnimations(target, animName, plyKMTime, targetKMTime, prevTMaterial)
		if !IsValid(self) or !IsValid(target) then return end
		if !IsValid(self.kmAnim) or !IsValid(target.kmAnim) then return end
		
		self.kmAnim:ResetSequence(animName)
		self.kmAnim:ResetSequenceInfo()
		self.kmAnim:SetCycle(0)
		
		target.kmAnim:ResetSequence(animName)
		target.kmAnim:ResetSequenceInfo()
		target.kmAnim:SetCycle(0)
		
		if plyKMTime == nil then plyKMTime = self.kmAnim:SequenceDuration() end
		if targetKMTime == nil then targetKMTime = target.kmAnim:SequenceDuration() end
		
		self:DoKMEffects(animName, self.kmModel, target.kmModel)
			
			--Now for the timers
			
			timer.Simple(targetKMTime, function()
				if IsValid(target) then
					
					target.kmAnim.AutomaticFrameAdvance = false
					
					timer.Simple(0.075, function()
						if IsValid(target) then
							-- Hide killmove models BEFORE making target visible (prevents visual glitch)
							if IsValid(target.kmModel) then target.kmModel:SetNoDraw(true) end
							if IsValid(target.kmAnim) then target.kmAnim:SetNoDraw(true) end
							
							if IsValid(target.kmModel) then
								local bonePos, boneAng = nil
								
								bonePos, boneAng = target.kmModel:GetBonePosition(0)
								
								target:SetPos(Vector(bonePos.x, bonePos.y, target:GetPos().z))
								--target:SetAngles(Angle(0, boneAng.y, 0))
							end
							
							target:SetHealth(1)
							
							-- Now make target visible
							target:DrawShadow( true )
							
							if target:IsPlayer() then
								target:SetMaterial(prevTMaterial)
								-- Restore weapons for players (show hidden weapon)
								if IsValid(target:GetActiveWeapon()) then
									target:GetActiveWeapon():SetNoDraw(false)
								end
								for _, childEnt in ipairs(target.kmModel and target.kmModel:GetChildren() or {}) do
									if IsValid(childEnt) and childEnt:IsWeapon() then
										childEnt:SetNoDraw(false)
									end
								end
							else
								target:SetNoDraw(false)
								-- Restore NPC weapons if they weren't dropped (setting was off)
								local dropTargetWeapons = GetCVarInt(cv_drop_target_weapons) ~= 0
								if not dropTargetWeapons then
									if IsValid(target:GetActiveWeapon()) then
										target:GetActiveWeapon():SetParent(target)
									end
									for _, childEnt in ipairs(target.kmModel and target.kmModel:GetChildren() or {}) do
										if IsValid(childEnt) and childEnt:IsWeapon() then
											childEnt:SetParent(target, childEnt:GetParentAttachment())
											childEnt:SetLocalPos(vector_origin)
											childEnt:SetLocalAngles(angle_zero)
										end
									end
								end
							end
							
							target:SetInKillMove(false)
							
							-- Drop stored weapon on the ground before killing NPC
							if target.bsmod_weapon_to_drop then
								local droppedWep = ents.Create(target.bsmod_weapon_to_drop)
								if IsValid(droppedWep) then
									droppedWep:SetPos(target.bsmod_weapon_drop_pos or target:GetPos())
									droppedWep:SetAngles(Angle(0, math.random(0, 360), 0))
									droppedWep:Spawn()
									droppedWep:Activate()
								end
								target.bsmod_weapon_to_drop = nil
								target.bsmod_weapon_drop_pos = nil
							end
							
							if target:IsPlayer() then
								target:UnLock()

								if target:Health() > 0 then
									ApplyKillmoveDamage(self, target)
									timer.Simple(0, function()
										if IsValid(target) and target:Health() > 0 then
											target:Kill()
										end
									end)
								end

							elseif target:IsNPC() or target:IsNextBot() then
								ApplyKillmoveDamage(self, target)
							end
							
							if IsValid(target.kmModel) then 
								for i, ent in ipairs(target.kmModel:GetChildren()) do 
									ent:SetParent(target, ent:GetParentAttachment()) 
									ent:SetLocalPos(vector_origin)
									ent:SetLocalAngles(angle_zero)
								end 
								
								target.kmModel:RemoveDelay(2)
							end
							if IsValid(target.kmAnim) then target.kmAnim:RemoveDelay(2) end
						end
					end )
				end
			end )
			
			timer.Simple(plyKMTime, function()
				if IsValid(self) then
					
					self.kmAnim.AutomaticFrameAdvance = false
					
					timer.Simple(0.075, function()
						if IsValid(self) then
							-- Hide killmove models first
							if IsValid(self.kmModel) then 
								self.kmModel:SetNoDraw(true)
								for i, ent in ipairs(self.kmModel:GetChildren()) do 
									ent:SetParent(self, ent:GetParentAttachment()) 
									ent:SetLocalPos(vector_origin)
									ent:SetLocalAngles(angle_zero)
								end 
							end
							if IsValid(self.kmAnim) then self.kmAnim:SetNoDraw(true) end
							
							-- Calculate and set new position
							local newPos = self:GetPos()
							if IsValid(self.kmAnim) then
								local eyesAttachment = self.kmAnim:LookupAttachment("eyes")
								if eyesAttachment and eyesAttachment > 0 then
									local headBone = self.kmAnim:GetAttachment(eyesAttachment)
									if headBone and headBone.Pos then
										newPos = Vector(headBone.Pos.x, headBone.Pos.y, headBone.Pos.z + (self:GetPos().z - self:EyePos().z))
										
										-- Dynamic hull fix - only adjust position if player would be stuck
										if GetCVarInt(cv_hull_fix) ~= 0 then
											local hullTrace = util.TraceHull({
												start = newPos + Vector(0, 0, 1),
												endpos = newPos + Vector(0, 0, 1),
												filter = self,
												mins = self:OBBMins(),
												maxs = self:OBBMaxs(),
												mask = MASK_PLAYERSOLID
											})
											
											if hullTrace.StartSolid then
												local groundTrace = util.TraceLine({
													start = newPos + Vector(0, 0, 72),
													endpos = newPos - Vector(0, 0, 10),
													filter = self,
													mask = MASK_PLAYERSOLID
												})
												if groundTrace.Hit and not groundTrace.StartSolid then
													newPos.z = groundTrace.HitPos.z + 1
												end
											end
										end
										
										self:SetPos(newPos)
										self:SetEyeAngles(Angle(headBone.Ang.x, headBone.Ang.y, 0))
									end
								end
							end
							
							-- Delay making player visible by one frame to let position sync
							timer.Simple(0, function()
								if not IsValid(self) then return end
								
								self:DrawShadow( true )
								
								if self:IsPlayer() then
									self:SetMaterial(self.prevMaterialBSMod)
								else
									self:SetNoDraw(false)
								end
								
								self:DrawWorldModel(true)
								
								-- Restore weapon and viewmodel visibility
								if IsValid(self.prevWeaponBSMod) then
									self.prevWeaponBSMod:SetNoDraw(false)
								end
								local vm = self:GetViewModel()
								if IsValid(vm) then
									vm:SetNoDraw(false)
								end
								
								self:SetMoveType(MOVETYPE_WALK)
								self:UnLock()
								
								-- Dynamic hull fix - final safety check
								if GetCVarInt(cv_hull_fix) ~= 0 then
									timer.Simple(0.1, function()
										if not IsValid(self) then return end
										
										local stuckTrace = util.TraceHull({
											start = self:GetPos() + Vector(0, 0, 5),
											endpos = self:GetPos() + Vector(0, 0, 5),
											filter = self,
											mins = self:OBBMins(),
											maxs = self:OBBMaxs(),
											mask = MASK_PLAYERSOLID
										})
										
										if stuckTrace.StartSolid then
											local unstickTrace = util.TraceLine({
												start = self:GetPos() + Vector(0, 0, 72),
												endpos = self:GetPos() - Vector(0, 0, 10),
												filter = self,
												mask = MASK_PLAYERSOLID
											})
											
											if unstickTrace.Hit and not unstickTrace.StartSolid then
												self:SetPos(unstickTrace.HitPos + Vector(0, 0, 1))
											end
										end
									end)
								end
								
								-- Reset FOV after killmove ends
								if GetCVarInt(cv_fovfx) == 1 and self:IsPlayer() then
									local fovValue = GetCVarInt(cv_fov_value)
									if fovValue > 0 then
										self:SetFOV(0, 0.3)
									end
								end
								
								-- Remove killmove models
								if IsValid(self.kmModel) then self.kmModel:Remove() end
								if IsValid(self.kmAnim) then self.kmAnim:Remove() end
								
								if self.prevGodModeBSMod then
									self:GodEnable(true)
								end
								
								-- Store target before clearing for hook
								local killedTarget = self.prevTargetBSMod
								local posType = self.bsmod_km_position_type
								
								self.prevTargetBSMod = nil
								self.prevWeaponBSMod = nil
								self.prevGodModeBSMod = nil
								self.prevMaterialBSMod = nil
								
								self:SetInKillMove(false)
								
								-- Fire hook for extension mods to react to killmove ending
								hook.Run("BSMod_KillMoveEnded", self, killedTarget, posType)
								
								-- Spawn health pickup if enabled
								if self:Health() < self:GetMaxHealth() then
									local spawnVial = GetCVarInt(cv_spawn_healthvial) ~= 0
									local spawnKit = GetCVarInt(cv_spawn_healthkit) ~= 0
									local healthToSpawn = 0
									
									if spawnVial and spawnKit then
										healthToSpawn = math_random(1, 2)
									elseif spawnVial then
										healthToSpawn = 1
									elseif spawnKit then
										healthToSpawn = 2
									end
									
									if healthToSpawn == 1 then
										local vial = ents.Create("item_healthvial")
										vial:SetPos(self:GetPos())
										vial:Spawn()
									elseif healthToSpawn == 2 then
										local kit = ents.Create("item_healthkit")
										kit:SetPos(self:GetPos())
										kit:Spawn()
									end
								end
							end)
						end
					end)
				end
			end)
	end
end

if CLIENT then
	if !killMovableBones then killMovableBones = {"ValveBiped.Bip01_Spine", "MiniStrider.body_joint"} end
	if !killMovableEnts then killMovableEnts = {} end
	killicon.Add("weapon_bsmod_killmove", "vgui/bsmod/killmove.png", Color(255,255,255))
	
	net.Receive("setkillmovable", function()
		local ent = net.ReadEntity()
		local value = net.ReadBool()
		
		if IsValid(ent) then
			ent.killMovable = value
		end
	end)
	
	net.Receive("removedecals", function()
		local ent = net.ReadEntity()
		
		if IsValid(ent) then
			ent:RemoveAllDecals()
		end
	end)
	
	net.Receive("debugbsmodcalcview", function()
		if GetConVar("bsmod_debug_calcview"):GetInt() ~= 0 then
			PrintTable(hook.GetTable()["CalcView"])
		end
	end)
	
	-- Receive inKillMove state from server (multiplayer compatibility)
	net.Receive("bsmod_inkillmove", function()
		local ent = net.ReadEntity()
		local value = net.ReadBool()
		
		if IsValid(ent) then
			ent.inKillMove = value
		end
	end)
	
	-- Hide HUD elements during killmoves
	hook.Add("HUDShouldDraw", "BSModHUDShouldDraw", function(name)
		if IsValid(LocalPlayer().kmviewentity) and !LocalPlayer().kmviewentity:GetNoDraw() then
			-- Always hide weapon selection during killmoves
			if name == "CHudWeaponSelection" then return false end
			
			-- Hide entire HUD if setting is enabled
			if GetConVar("bsmod_killmove_hide_hud"):GetInt() == 1 then
				return false
			end
		end
	end)
	
	--Hide weapon pickup hud for the killmove weapon
	hook.Add("HUDWeaponPickedUp", "HideKMWeaponNotify", function(weapon)
		if weapon:GetClass() == "weapon_bsmod_killmove" then return false end
	end)
	
	-- Cache ConVars for indicator performance
	local cv_indicator = GetConVar("bsmod_killmove_indicator")
	local cv_indicator_key = GetConVar("bsmod_killmove_key")
	local cv_enable_players = GetConVar("bsmod_killmove_enable_players")
	local cv_enable_teammates = GetConVar("bsmod_killmove_enable_teammates")
	local cv_enable_npcs = GetConVar("bsmod_killmove_enable_npcs")
	local cv_anytime = GetConVar("bsmod_killmove_anytime")
	local cv_anytime_behind = GetConVar("bsmod_killmove_anytime_behind")
	
	-- Cache for target checking
	local cachedTarget = nil
	local lastTargetCheck = 0
	local targetCheckInterval = 0.1 -- Only run expensive checks every 100ms
	
	-- Reusable trace structures to avoid table allocations
	local traceLineData = { start = Vector(), endpos = Vector(), filter = nil }
	local traceHullData = { start = Vector(), endpos = Vector(), filter = nil, mins = Vector(-1, -1, -1), maxs = Vector(1, 1, 1) }
	
	-- Shared function to find and validate killmove target
	local function FindKillMoveTarget(ply)
		local curTime = RealTime()
		
		-- Use cached result if recent enough
		if curTime - lastTargetCheck < targetCheckInterval then
			return cachedTarget
		end
		
		lastTargetCheck = curTime
		cachedTarget = nil
		
		-- Reuse trace structures instead of creating new tables
		local eyePos = ply:EyePos()
		local forward = ply:EyeAngles():Forward() * 100
		
		traceLineData.start = eyePos
		traceLineData.endpos = eyePos + forward
		traceLineData.filter = ply
		
		local tr = util.TraceLine(traceLineData)
		
		if !IsValid(tr.Entity) then
			traceHullData.start = eyePos
			traceHullData.endpos = eyePos + forward
			traceHullData.filter = ply
			tr = util.TraceHull(traceHullData)
		end
		
		if !IsValid(tr.Entity) then return nil end
		
		local target = tr.Entity
		
		-- Check if this entity can be killmoved
		if !target:IsPlayer() and !target:IsNPC() and !target:IsNextBot() then return nil end
		if target.inKillMove or target == ply then return nil end
		
		if target:IsPlayer() then
			if cv_enable_players:GetInt() == 0 or target:HasGodMode() then return nil end
			if engine.ActiveGamemode() ~= "sandbox" and cv_enable_teammates:GetInt() == 0 then
				if target:Team() == ply:Team() then return nil end
			end
		elseif target:IsNPC() or target:IsNextBot() then
			if cv_enable_npcs:GetInt() == 0 then return nil end
		else
			return nil
		end
		
		-- Check if entity has required bones/class (cached on entity)
		local canBeKillMoved = false
		if target.bsmod_canBeKillMoved ~= nil then
			canBeKillMoved = target.bsmod_canBeKillMoved
		else
			for _, bone in ipairs(killMovableBones or {"ValveBiped.Bip01_Spine", "MiniStrider.body_joint"}) do
				if target:LookupBone(bone) then 
					canBeKillMoved = true
					break
				end
			end
			if !canBeKillMoved then
				for _, entName in ipairs(killMovableEnts or {}) do
					if target:GetClass() == entName then 
						canBeKillMoved = true
						break
					end
				end
			end
			target.bsmod_canBeKillMoved = canBeKillMoved
		end
		
		if !canBeKillMoved then return nil end
		
		-- Check killmove conditions
		local canKillMove = false
		local anytimeEnabled = cv_anytime:GetInt() ~= 0
		local anytimeBehindEnabled = cv_anytime_behind:GetInt() ~= 0
		
		if anytimeEnabled then
			canKillMove = true
		elseif anytimeBehindEnabled then
			local vec = ( ply:GetPos() - target:GetPos() ):GetNormal():Angle().y
			local targetAngle = target:EyeAngles().y
			
			if targetAngle > 360 then targetAngle = targetAngle - 360 end
			if targetAngle < 0 then targetAngle = targetAngle + 360 end
			
			local angleAround = vec - targetAngle
			if angleAround > 360 then angleAround = angleAround - 360 end
			if angleAround < 0 then angleAround = angleAround + 360 end
			
			canKillMove = target.killMovable or (angleAround > 135 and angleAround <= 225)
		else
			canKillMove = target.killMovable
		end
		
		if canKillMove then
			cachedTarget = target
			return target
		end
		
		return nil
	end
	
	-- Cache the use_key ConVar for client
	local cv_use_key_client = GetConVar("bsmod_killmove_use_key")
	
	-- Get the key bound to killmove command
	local function GetKillMoveKey()
		-- Check for user override first
		local override = cv_indicator_key:GetString()
		if override and override ~= "" then
			return string.upper(override)
		end
		
		-- If use key mode is enabled, show the Use key
		if cv_use_key_client and cv_use_key_client:GetInt() ~= 0 then
			local useKey = input.LookupBinding("+use")
			if useKey then
				return string.upper(useKey)
			end
			return "E"
		end
		
		-- Try to find the bound key using LookupBinding
		local boundKey = input.LookupBinding("bsmod_killmove")
		if boundKey then
			return string.upper(boundKey)
		end
		
		return "?"
	end
	
	-- Cached key (refreshed periodically)
	local cachedKey = nil
	local lastKeyCheck = 0
	
	-- Icon colors
	local iconColor = Color(100, 150, 255, 230)
	local iconColorPulse = Color(150, 200, 255, 255)
	local warningColor = Color(255, 100, 100, 230)
	
	-- Check if player model is valid for killmoves (client-side)
	local function IsValidKillMoveModelClient(ply)
		if not IsValid(ply) then return false end
		
		local hasSpine = ply:LookupBone("ValveBiped.Bip01_Spine") ~= nil
		local hasHead = ply:LookupBone("ValveBiped.Bip01_Head1") ~= nil
		local hasRightHand = ply:LookupBone("ValveBiped.Bip01_R_Hand") ~= nil
		
		return hasSpine and (hasHead or hasRightHand)
	end
	
	-- Cache for model validity check
	local lastModelCheck = 0
	local cachedModelValid = true
	local warningShown = false
	local lastValidModel = nil
	
	-- Combined indicator HUD (handles both prompt and icon modes)
	hook.Add("HUDPaint", "BSModKillMoveIndicator", function()
		local indicatorMode = cv_indicator:GetInt()
		if indicatorMode == 0 then return end
		
		local ply = LocalPlayer()
		if !IsValid(ply) or !ply:Alive() or ply:Health() <= 0 then return end
		
		-- Hide indicator during killmoves (check both server flag and client view entity)
		if ply.inKillMove then return end
		if IsValid(ply.kmviewentity) and !ply.kmviewentity:GetNoDraw() then return end
		
		-- Check model validity (cache for 1 second)
		local curTime = RealTime()
		if curTime - lastModelCheck > 1 then
			local currentModel = ply:GetModel()
			cachedModelValid = IsValidKillMoveModelClient(ply)
			lastModelCheck = curTime
			
			-- Reset warning flag if model changed to a valid one
			if currentModel ~= lastValidModel and cachedModelValid then
				warningShown = false
				lastValidModel = currentModel
			end
			
			-- Show warning popup for invalid model
			if not cachedModelValid and not warningShown then
				warningShown = true
				lastValidModel = currentModel
				
				-- Create styled warning popup (same style as BSMod conflict warning)
				local modelWarningStart = RealTime()
				local modelWarningDuration = 10
				
				hook.Add("HUDPaint", "BSModInvalidModelWarning", function()
					local elapsed = RealTime() - modelWarningStart
					if elapsed > modelWarningDuration then
						hook.Remove("HUDPaint", "BSModInvalidModelWarning")
						return
					end
					
					-- Fade out in last 2 seconds
					local alpha = 1
					if elapsed > modelWarningDuration - 2 then
						alpha = (modelWarningDuration - elapsed) / 2
					end
					
					local text1 = "KillMoves Disabled"
					local text2 = "Your playermodel is missing required bones."
					
					surface.SetFont("DermaLarge")
					local w1, h1 = surface.GetTextSize(text1)
					surface.SetFont("DermaDefaultBold")
					local w2, h2 = surface.GetTextSize(text2)
					
					local boxW = math.max(w1, w2) + 40
					local boxH = h1 + h2 + 20
					local x = ScrW() / 2 - boxW / 2
					local y = 80
					
					draw.RoundedBox(8, x, y, boxW, boxH, Color(150, 100, 0, 200 * alpha))
					draw.SimpleText(text1, "DermaLarge", ScrW() / 2, y + 10, Color(255, 255, 255, 255 * alpha), TEXT_ALIGN_CENTER)
					draw.SimpleText(text2, "DermaDefaultBold", ScrW() / 2, y + 10 + h1 + 5, Color(255, 255, 255, 230 * alpha), TEXT_ALIGN_CENTER)
				end)
			end
		end
		
		-- Don't show indicator if model is invalid
		if not cachedModelValid then return end
		
		local target = FindKillMoveTarget(ply)
		if !IsValid(target) then return end
		
		local curTime = RealTime()
		
		-- MODE 1: Takedown Prompt (center screen)
		if indicatorMode == 1 then
			-- Refresh key cache every 2 seconds
			if curTime - lastKeyCheck > 2 then
				cachedKey = GetKillMoveKey()
				lastKeyCheck = curTime
			end
			
			local keyText = cachedKey or "?"
			local actionText = "Takedown"
			
			-- Screen positioning (center, slightly below middle)
			local scrW, scrH = ScrW(), ScrH()
			local x = scrW / 2
			local y = scrH / 2 + 80
			
			-- Fonts
			surface.SetFont("DermaLarge")
			local keyW, keyH = surface.GetTextSize(keyText)
			
			surface.SetFont("DermaDefaultBold")
			local actionW, actionH = surface.GetTextSize(actionText)
			
			-- Key box dimensions
			local keyPadding = 12
			local keyBoxW = math.max(keyW + keyPadding * 2, keyH + keyPadding)
			local keyBoxH = keyH + keyPadding
			
			-- Total width for centering
			local spacing = 12
			local totalW = keyBoxW + spacing + actionW
			local startX = x - totalW / 2
			
			-- Subtle pulse animation
			local pulse = math.sin(curTime * 4) * 0.15 + 0.85
			local bgAlpha = 180 * pulse
			local borderAlpha = 255 * pulse
			
			-- Draw key box background
			local keyBoxX = startX
			local keyBoxY = y - keyBoxH / 2
			
			draw.RoundedBox(6, keyBoxX, keyBoxY, keyBoxW, keyBoxH, Color(20, 20, 20, bgAlpha))
			
			-- Draw key box border
			surface.SetDrawColor(200, 200, 200, borderAlpha)
			surface.DrawOutlinedRect(keyBoxX, keyBoxY, keyBoxW, keyBoxH, 2)
			
			-- Draw key text (centered in box)
			draw.SimpleText(keyText, "DermaLarge", keyBoxX + keyBoxW / 2, y, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			-- Draw action text
			local actionX = keyBoxX + keyBoxW + spacing
			draw.SimpleText(actionText, "DermaDefaultBold", actionX, y, Color(255, 255, 255, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		-- MODE 2: Icon Above Head
		elseif indicatorMode == 2 then
			-- Get position above target's head
			local headBone = target:LookupBone("ValveBiped.Bip01_Head1")
			local pos
			if headBone then
				local bonePos = target:GetBonePosition(headBone)
				pos = bonePos + Vector(0, 0, 15)
			else
				pos = target:GetPos() + Vector(0, 0, target:OBBMaxs().z + 15)
			end
			
			local screenPos = pos:ToScreen()
			if !screenPos.visible then return end
			
			-- Draw pulsing crosshair icon
			local pulse = math.sin(curTime * 6) * 0.5 + 0.5
			local size = 16 + pulse * 4
			local col = pulse > 0.5 and iconColorPulse or iconColor
			
			surface.SetDrawColor(col)
			
			-- Draw crosshair shape
			local x, y = screenPos.x, screenPos.y
			local half = size / 2
			local thick = 2
			
			-- Horizontal line
			surface.DrawRect(x - half, y - thick/2, size, thick)
			-- Vertical line
			surface.DrawRect(x - thick/2, y - half, thick, size)
			
			-- Corner brackets for style
			local bracket = 6
			surface.DrawRect(x - half - 4, y - half - 4, bracket, 2)
			surface.DrawRect(x - half - 4, y - half - 4, 2, bracket)
			
			surface.DrawRect(x + half - bracket + 4, y - half - 4, bracket, 2)
			surface.DrawRect(x + half + 2, y - half - 4, 2, bracket)
			
			surface.DrawRect(x - half - 4, y + half + 2, bracket, 2)
			surface.DrawRect(x - half - 4, y + half - bracket + 4, 2, bracket)
			
			surface.DrawRect(x + half - bracket + 4, y + half + 2, bracket, 2)
			surface.DrawRect(x + half + 2, y + half - bracket + 4, 2, bracket)
		end
	end)
	
	hook.Add( "CreateClientsideRagdoll", "BSModCreateClientsideRagdoll", function(entity, ragdoll)
		if entity:LookupBone("MiniStrider.body_joint") or !IsValid(entity.kmviewentity) or !IsValid(entity) or !IsValid(ragdoll) then return end
		
		-- Hide ragdoll initially
		ragdoll:SetMaterial("null")
		ragdoll:RemoveAllDecals()
		
		timer.Simple(0, function()
			if entity:LookupBone("MiniStrider.body_joint") or !IsValid(entity.kmviewentity) or !IsValid(entity) or !IsValid(ragdoll) then return end
			
			local ent = ragdoll
			local targetEnt = entity.kmviewentity
			
			if !IsValid(targetEnt) then return end
			
			ragdoll:SetMaterial(entity:GetMaterial())
			
			local boneCount = ent:GetPhysicsObjectCount()
			
			-- Position all bones from the killmove model - no freezing
			for i = 0, boneCount - 1 do
				local bone = ent:GetPhysicsObjectNum(i)
				
				if bone and bone:IsValid() then
					local bonename = ent:GetBoneName(i)
					local plybone = targetEnt:LookupBone(bonename)
					
					if plybone then
						local bonepos, boneang = targetEnt:GetBonePosition(ent:TranslatePhysBoneToBone(plybone))
						
						bone:SetPos(bonepos, true)
						bone:SetAngles(boneang)
						bone:SetVelocity(vector_origin)
						bone:SetAngleVelocity(vector_origin)
					end
				end
			end
			
			-- Apply physics impulse based on animation
			timer.Simple(0.01, function()
				if !IsValid(entity.kmviewanim) or !IsValid(ragdoll) then return end
				hook.Run("KMRagdoll", entity, ragdoll, entity.kmviewanim:GetSequenceName(entity.kmviewanim:GetSequence()))
			end)
		end)
	end)
	
	-- Cache thirdperson ConVars for CalcView performance (runs every frame)
	local cv_thirdperson = GetConVar("bsmod_killmove_thirdperson")
	local cv_thirdperson_distance = GetConVar("bsmod_killmove_thirdperson_distance")
	local cv_thirdperson_pitch = GetConVar("bsmod_killmove_thirdperson_pitch")
	local cv_thirdperson_yaw = GetConVar("bsmod_killmove_thirdperson_yaw")
	local cv_thirdperson_offsetup = GetConVar("bsmod_killmove_thirdperson_offsetup")
	local cv_thirdperson_offsetright = GetConVar("bsmod_killmove_thirdperson_offsetright")
	local cv_thirdperson_randomyaw = GetConVar("bsmod_killmove_thirdperson_randomyaw")
	local cv_thirdperson_smoothing = GetConVar("bsmod_killmove_thirdperson_smoothing")
	local cv_thirdperson_smoothspeed = GetConVar("bsmod_killmove_thirdperson_smoothspeed")
	local cv_thirdperson_orbit = GetConVar("bsmod_killmove_thirdperson_orbit")
	local cv_thirdperson_orbitspeed = GetConVar("bsmod_killmove_thirdperson_orbitspeed")
	local cv_thirdperson_fov = GetConVar("bsmod_killmove_thirdperson_fov")
	
	-- Reusable table for CalcView return (avoids allocation every frame)
	local calcViewResult = { origin = Vector(), angles = Angle(), drawviewer = true, fov = nil }
	
	-- Camera transition state for smooth exit from killmoves
	local kmTransitionEndTime = 0
	local kmTransitionDuration = 0.15
	local kmLastOrigin = nil
	local kmLastAngles = nil
	local kmLastFov = nil
	
	-- Smooth camera state
	local kmSmoothOrigin = nil
	local kmSmoothAngles = nil
	local kmSmoothFov = nil
	local kmOrbitAngle = 0
	local kmIsFirstFrame = true
	
	-- Helper function to lerp angles using shortest path
	local function LerpAngleShortestPath(t, from, to)
		local p = math.NormalizeAngle(from.p + t * math.AngleDifference(to.p, from.p))
		local y = math.NormalizeAngle(from.y + t * math.AngleDifference(to.y, from.y))
		local r = math.NormalizeAngle(from.r + t * math.AngleDifference(to.r, from.r))
		return Angle(p, y, r)
	end
	
	-- Trace for camera collision
	local cameraTraceData = { start = Vector(), endpos = Vector(), filter = nil, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4) }
	
	hook.Add("CalcView", "BSModCalcView", function(ply, pos, angles, fov)
		local kmviewentity = ply.kmviewentity
		local isKillmoveActive = IsValid(kmviewentity) and not kmviewentity:GetNoDraw() and ply:GetViewEntity() == ply
		
		-- Handle smooth transition out of killmove
		if not isKillmoveActive and kmLastOrigin and CurTime() < kmTransitionEndTime then
			local remaining = kmTransitionEndTime - CurTime()
			local progress = 1 - (remaining / kmTransitionDuration)
			local ease = progress * progress * (3 - 2 * progress)
			
			calcViewResult.origin = LerpVector(ease, kmLastOrigin, pos)
			calcViewResult.angles = LerpAngleShortestPath(ease, kmLastAngles, angles)
			calcViewResult.drawviewer = false
			
			-- Smooth FOV transition out
			if kmLastFov then
				calcViewResult.fov = Lerp(ease, kmLastFov, fov)
			else
				calcViewResult.fov = nil
			end
			
			return calcViewResult
		end
		
		if not isKillmoveActive then
			-- Clear transition state
			kmLastOrigin = nil
			kmLastAngles = nil
			kmLastFov = nil
			kmSmoothOrigin = nil
			kmSmoothAngles = nil
			kmSmoothFov = nil
			kmOrbitAngle = 0
			kmIsFirstFrame = true
			
			if cv_thirdperson:GetInt() ~= 0 then
				ply.randTPYaw = nil
			end
			return
		end
		
		-- Track killmove start for orbit and smooth start
		if kmIsFirstFrame then
			ply.bsmod_km_start_time = CurTime()
			kmOrbitAngle = 0
			-- Initialize smooth camera from current view position for smooth zoom out
			kmSmoothOrigin = pos
			kmSmoothAngles = angles
			kmSmoothFov = fov
			kmIsFirstFrame = false
		end
		
		-- Cache attachment index on entity to avoid lookup every frame
		if not kmviewentity.bsmod_eyesAttachment then
			kmviewentity.bsmod_eyesAttachment = kmviewentity:LookupAttachment("eyes")
		end
		
		local eyeAttachment = kmviewentity:GetAttachment(kmviewentity.bsmod_eyesAttachment)
		if not eyeAttachment then return end
		
		local thirdperson = cv_thirdperson:GetInt() ~= 0
		local targetOrigin, targetAngles, targetFov
		
		if thirdperson then
			-- Initialize random yaw if needed
			if ply.randTPYaw == nil and cv_thirdperson_randomyaw:GetInt() ~= 0 then 
				ply.randTPYaw = math.Rand(-180, 180) 
			end
			
			-- Calculate base yaw (with orbit if enabled)
			local baseYaw = cv_thirdperson_randomyaw:GetInt() == 0 and cv_thirdperson_yaw:GetFloat() or ply.randTPYaw
			
			-- Apply orbit rotation
			if cv_thirdperson_orbit:GetInt() ~= 0 then
				kmOrbitAngle = kmOrbitAngle + cv_thirdperson_orbitspeed:GetFloat() * FrameTime()
				baseYaw = baseYaw + kmOrbitAngle
			end
			
			local TPAng = Angle(cv_thirdperson_pitch:GetFloat(), angles.y + baseYaw, 0)
			
			-- Calculate camera position
			local distance = cv_thirdperson_distance:GetFloat()
			local offsetUp = cv_thirdperson_offsetup:GetFloat()
			local offsetRight = cv_thirdperson_offsetright:GetFloat()
			
			local focusPoint = eyeAttachment.Pos
			
			targetOrigin = focusPoint - (TPAng:Forward() * distance) + (TPAng:Up() * offsetUp) + (TPAng:Right() * offsetRight)
			targetAngles = TPAng
			
			-- Custom FOV for third person
			local customFov = cv_thirdperson_fov:GetFloat()
			targetFov = customFov > 0 and customFov or fov
			
			-- Camera collision detection (always on for third person)
			-- Build comprehensive filter list of all killmove-related entities
			local filterEnts = {ply}
			
			-- Add player's killmove models
			if IsValid(kmviewentity) then table.insert(filterEnts, kmviewentity) end
			if IsValid(ply.kmviewanim) then table.insert(filterEnts, ply.kmviewanim) end
			if IsValid(ply.kmModel) then table.insert(filterEnts, ply.kmModel) end
			if IsValid(ply.kmAnim) then table.insert(filterEnts, ply.kmAnim) end
			if IsValid(ply.kmChands) then table.insert(filterEnts, ply.kmChands) end
			
			-- Add all ent_km_model entities to filter (covers target models too)
			for _, ent in ipairs(ents.FindByClass("ent_km_model")) do
				table.insert(filterEnts, ent)
				local entOwner = ent:GetOwner()
				if IsValid(entOwner) and entOwner ~= ply then
					table.insert(filterEnts, entOwner)
				end
			end
			
			cameraTraceData.start = focusPoint
			cameraTraceData.endpos = targetOrigin
			cameraTraceData.filter = filterEnts
			
			local tr = util.TraceHull(cameraTraceData)
			if tr.Hit and not tr.StartSolid then
				-- Move camera closer to avoid clipping, but not too close
				local newOrigin = tr.HitPos + tr.HitNormal * 10
				-- Only use if it's not too close to focus point
				if newOrigin:DistToSqr(focusPoint) > 1600 then -- at least 40 units away
					targetOrigin = newOrigin
				end
			end
			
			-- Apply smoothing (smooth zoom out from first person position)
			if cv_thirdperson_smoothing:GetInt() ~= 0 and kmSmoothOrigin then
				local smoothSpeed = cv_thirdperson_smoothspeed:GetFloat() * FrameTime()
				
				kmSmoothOrigin = LerpVector(smoothSpeed, kmSmoothOrigin, targetOrigin)
				kmSmoothAngles = LerpAngleShortestPath(smoothSpeed, kmSmoothAngles, targetAngles)
				kmSmoothFov = Lerp(smoothSpeed, kmSmoothFov or fov, targetFov)
				
				targetOrigin = kmSmoothOrigin
				targetAngles = kmSmoothAngles
				targetFov = kmSmoothFov
			end
		else
			targetOrigin = eyeAttachment.Pos
			targetAngles = eyeAttachment.Ang
			targetFov = nil
		end
		
		calcViewResult.origin = targetOrigin
		calcViewResult.angles = targetAngles
		calcViewResult.drawviewer = thirdperson
		calcViewResult.fov = targetFov
		
		-- Store last valid camera state for smooth transition out
		kmLastOrigin = Vector(calcViewResult.origin)
		kmLastAngles = Angle(calcViewResult.angles)
		kmTransitionEndTime = CurTime() + kmTransitionDuration
		
		return calcViewResult
	end)
	
	-- Clean up killmove start time when killmove ends
	hook.Add("Think", "BSModKillmoveTPCleanup", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		
		if not ply.inKillMove and ply.bsmod_km_start_time then
			ply.bsmod_km_start_time = nil
		end
	end)
	
	-- Cache ConVars for OnEntityCreated
	local cv_hide_head = GetConVar("bsmod_killmove_hide_head")
	local cv_use_chands = GetConVar("bsmod_killmove_use_chands")
	
	-- Get the player's c_arms model
	local function GetPlayerCHands(ply)
		if not IsValid(ply) then return nil end
		
		-- Try to get hands from player info
		local dominated = ply:GetInfo("cl_playermodel")
		local info = player_manager.TranslatePlayerHands(dominated)
		if info and info.model then
			return info.model, info.skin or 0, info.body or "0"
		end
		
		-- Fallback to default citizen hands
		return "models/weapons/c_arms_citizen.mdl", 0, "0"
	end
	
	hook.Add("OnEntityCreated", "BSModOnEntityCreated", function(ent)
		if ent:GetClass() ~= "ent_km_model" then return end
		
		-- This was originally in the killmove entity's Initialize function but it was setting the viewtarget too late causing some visual issues for a few frames
		-- Putting it here fixes this problem
		local owner = ent:GetOwner()
		if not IsValid(owner) then return end
		
		if owner:GetModel() == ent:GetModel() then
			owner.kmviewentity = ent
			
			-- Hide the player's head if enabled and NOT in third person (helps with playermodel accessories blocking view)
			if owner == LocalPlayer() and cv_hide_head:GetInt() == 1 and cv_thirdperson:GetInt() == 0 then
				local headBone = ent:LookupBone("ValveBiped.Bip01_Head1")
				if headBone then
					ent:ManipulateBoneScale(headBone, Vector(0, 0, 0))
				end
			end
			
			-- EXPERIMENTAL: Spawn c_hands model if enabled (first person only)
			if owner == LocalPlayer() and cv_use_chands and cv_use_chands:GetInt() == 1 and cv_thirdperson:GetInt() == 0 then
				-- Hide ALL arm and hand bones (same method as head hiding)
				local armBones = {
					-- Left arm
					"ValveBiped.Bip01_L_Shoulder",
					"ValveBiped.Bip01_L_Clavicle",
					"ValveBiped.Bip01_L_UpperArm",
					"ValveBiped.Bip01_L_Bicep",
					"ValveBiped.Bip01_L_Elbow",
					"ValveBiped.Bip01_L_Forearm",
					"ValveBiped.Bip01_L_Ulna",
					"ValveBiped.Bip01_L_Wrist",
					"ValveBiped.Bip01_L_Hand",
					"ValveBiped.Bip01_L_Finger0",
					"ValveBiped.Bip01_L_Finger01",
					"ValveBiped.Bip01_L_Finger02",
					"ValveBiped.Bip01_L_Finger1",
					"ValveBiped.Bip01_L_Finger11",
					"ValveBiped.Bip01_L_Finger12",
					"ValveBiped.Bip01_L_Finger13",
					"ValveBiped.Bip01_L_Finger2",
					"ValveBiped.Bip01_L_Finger21",
					"ValveBiped.Bip01_L_Finger22",
					"ValveBiped.Bip01_L_Finger23",
					"ValveBiped.Bip01_L_Finger3",
					"ValveBiped.Bip01_L_Finger31",
					"ValveBiped.Bip01_L_Finger32",
					"ValveBiped.Bip01_L_Finger33",
					"ValveBiped.Bip01_L_Finger4",
					"ValveBiped.Bip01_L_Finger41",
					"ValveBiped.Bip01_L_Finger42",
					"ValveBiped.Bip01_L_Finger43",
					-- Right arm
					"ValveBiped.Bip01_R_Shoulder",
					"ValveBiped.Bip01_R_Clavicle",
					"ValveBiped.Bip01_R_UpperArm",
					"ValveBiped.Bip01_R_Bicep",
					"ValveBiped.Bip01_R_Elbow",
					"ValveBiped.Bip01_R_Forearm",
					"ValveBiped.Bip01_R_Ulna",
					"ValveBiped.Bip01_R_Wrist",
					"ValveBiped.Bip01_R_Hand",
					"ValveBiped.Bip01_R_Finger0",
					"ValveBiped.Bip01_R_Finger01",
					"ValveBiped.Bip01_R_Finger02",
					"ValveBiped.Bip01_R_Finger1",
					"ValveBiped.Bip01_R_Finger11",
					"ValveBiped.Bip01_R_Finger12",
					"ValveBiped.Bip01_R_Finger13",
					"ValveBiped.Bip01_R_Finger2",
					"ValveBiped.Bip01_R_Finger21",
					"ValveBiped.Bip01_R_Finger22",
					"ValveBiped.Bip01_R_Finger23",
					"ValveBiped.Bip01_R_Finger3",
					"ValveBiped.Bip01_R_Finger31",
					"ValveBiped.Bip01_R_Finger32",
					"ValveBiped.Bip01_R_Finger33",
					"ValveBiped.Bip01_R_Finger4",
					"ValveBiped.Bip01_R_Finger41",
					"ValveBiped.Bip01_R_Finger42",
					"ValveBiped.Bip01_R_Finger43"
				}
				
				for _, boneName in ipairs(armBones) do
					local boneIdx = ent:LookupBone(boneName)
					if boneIdx then
						ent:ManipulateBoneScale(boneIdx, Vector(0, 0, 0))
					end
				end
				
				local animModel = ent:GetParent()
				if not IsValid(animModel) then return end
				
				local handsModel, handsSkin, handsBody = GetPlayerCHands(owner)
				if not handsModel then return end
				
				-- Create clientside hands model
				local hands = ClientsideModel(handsModel)
				if not IsValid(hands) then return end
				
				hands:SetSkin(handsSkin)
				hands:SetBodyGroups(handsBody)
				hands:SetParent(animModel)
				hands:AddEffects(EF_BONEMERGE)
				hands:AddEffects(EF_BONEMERGE_FASTCULL)
				
				owner.kmChands = hands
			end
		else
			owner.kmviewanim = ent
		end
		
		if owner.GetPlayerColor then
			local playerColor = owner:GetPlayerColor()
			if playerColor then
				ent.GetPlayerColor = function() return Vector(playerColor.r, playerColor.g, playerColor.b) end
			end
		end
	end)
	
	-- Clean up c_hands when killmove model is removed
	hook.Add("EntityRemoved", "BSModCHandsCleanup", function(ent)
		if ent:GetClass() ~= "ent_km_model" then return end
		
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		
		if IsValid(ply.kmChands) then
			ply.kmChands:Remove()
			ply.kmChands = nil
		end
	end)
	
	-- Hide c_hands when underwater to prevent rendering issues
	hook.Add("Think", "BSModCHandsUnderwaterFix", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		if not IsValid(ply.kmChands) then return end
		
		-- Check if player's view is underwater
		local isUnderwater = ply:WaterLevel() >= 3
		
		if isUnderwater then
			if not ply.kmChands:GetNoDraw() then
				ply.kmChands:SetNoDraw(true)
			end
		else
			if ply.kmChands:GetNoDraw() then
				ply.kmChands:SetNoDraw(false)
			end
		end
	end)
end

hook.Add( "KMRagdoll", "BSModKMRagdoll", function(entity, ragdoll, animName)
	if not IsValid(ragdoll) then return end
	
	local spinePos, spineAng = nil
	local spineBone = ragdoll:LookupBone("ValveBiped.Bip01_Spine")
	
	if spineBone then 
		spinePos, spineAng = ragdoll:GetBonePosition(spineBone)
	end
	
	-- Define ragdoll impulses per animation for more natural physics
	local impulseData = {
		["killmove_front_1"] = { vel = 150, angVel = 2500, dir = "forward" },
		["killmove_front_2"] = { vel = 100, angVel = 1500, dir = "forward" },
		["killmove_front_air_1"] = { vel = 80, angVel = 1000, dir = "down" },
		["killmove_left_1"] = { vel = 120, angVel = 1800, dir = "right" },
		["killmove_right_1"] = { vel = 50, angVel = 1000, dir = "down" },
		["killmove_back_1"] = { vel = 125, angVel = 800, dir = "back" },
		["killmove_hunter_front_1"] = { vel = 200, angVel = 500, dir = "forward" }
	}
	
	local impulse = impulseData[animName]
	if not impulse or not spineAng then return end
	
	-- Calculate direction vector based on animation
	local dirVec = vector_origin
	if impulse.dir == "forward" then
		dirVec = spineAng:Forward()
	elseif impulse.dir == "back" then
		dirVec = -spineAng:Right() + (-spineAng:Up() * 0.3)
	elseif impulse.dir == "right" then
		dirVec = spineAng:Right()
	elseif impulse.dir == "left" then
		dirVec = -spineAng:Right()
	elseif impulse.dir == "down" then
		dirVec = Vector(0, 0, -1)
	end
	
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local bone = ragdoll:GetPhysicsObjectNum(i)
		
		if bone and bone:IsValid() then
			bone:SetVelocity(dirVec * impulse.vel)
			bone:SetAngleVelocity(bone:WorldToLocalVector(-dirVec * impulse.angVel))
		end
	end
end)
