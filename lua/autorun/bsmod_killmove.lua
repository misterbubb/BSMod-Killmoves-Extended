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
	local cv_spawn_healthvial, cv_spawn_healthkit, cv_hide_target_weapons
	
	-- Initialize ConVar cache after they're created
	hook.Add("Initialize", "BSModCacheConVars", function()
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
		cv_hide_target_weapons = GetConVar("bsmod_killmove_hide_target_weapons")
	end)
	
	-- Fallback for late loading
	timer.Simple(0, function()
		if not cv_stun_npcs then
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
			cv_hide_target_weapons = GetConVar("bsmod_killmove_hide_target_weapons")
		end
	end)
	
	-- Helper to safely get ConVar int (handles nil during load)
	local function GetCVarInt(cv)
		return cv and cv:GetInt() or 0
	end
	local function GetCVarFloat(cv)
		return cv and cv:GetFloat() or 0
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
		
		net.Start("setkillmovable")
		net.WriteEntity(self)
		net.WriteBool(value)
		net.Broadcast()
	end
	
	--[[function plymeta:ShowHint(text, type, length, player)
		net.Start("showhint")
		net.WriteString(text)
		net.WriteInt(type, 4)
		net.WriteFloat(length)
		net.Send(player)
	end]]
	
	--Might use this later if I can figure out how to implement it properly
	--[[timer.Create( "killmoveglowcheck", 0.5, 0, function () 
		if setterCount == 0 then return end
		PrintTable(setters)
		net.Start("setkillmovable")
			for ent, value in pairs(setters) do
				if !IsValid(ent) then continue end
				
				local bytesLeft, _ = net.BytesWritten()

				bytesLeft = 65533 - bytesLeft

				if bytesLeft < 2 then
					net.Broadcast()
					net.Start("setkillmovable")
				end

				net.WriteEntity(ent)
				net.WriteBool(value)
			end
		
		net.Broadcast()

		setters = {}
		setterCount = 0
	end)]]
	
	hook.Add( "CreateEntityRagdoll", "BSModCreateEntityRagdoll", function(entity, ragdoll)
		if !IsValid(entity.kmModel) or !IsValid(entity) or !IsValid(ragdoll) then return end
		
		-- Disable collision on killmoved NPC ragdolls so player doesn't get stuck inside
		ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local bone = ragdoll:GetPhysicsObjectNum(i)
			
			if bone and bone:IsValid() then
				local bonepos, boneang = entity.kmModel:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))
				
				bone:SetPos(bonepos, true)
				bone:SetAngles(boneang)
				bone:SetVelocity(vector_origin)
			end
		end
		
		hook.Run("KMRagdoll", entity, ragdoll, entity.kmAnim:GetSequenceName(entity.kmAnim:GetSequence()))
	end)
	
	-- Performance: Only iterate tracked killMovable entities, not ALL entities
	hook.Add("Think", "BSModThink", function()
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
	end )
	
	-- Block weapon input during killmoves (prevents firing without switching weapons)
	hook.Add("StartCommand", "BSModBlockWeaponInput", function(ply, cmd)
		if ply.inKillMove then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
		end
	end)
	
	hook.Add("PlayerInitialSpawn", "BSModPlayerInitialSpawn", function(ply)
		--Unused hints function, disabled right now because it could be annoying
		
		
		--Reset the killmove state to fix players not spawning properly if killmoving before a level transition
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
			
			ply.inKillMove = false
			
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
				
				if headBone != nil then
					local effectdata = EffectData()
					effectdata:SetOrigin(targetModel:GetBonePosition(headBone))
					util.Effect("BloodImpact", effectdata)
				end
			end)
			
			timer.Simple(0.8, function()
				if !IsValid(targetModel) then return end
				
				PlayRandomSound(self, 1, 1, "player/killmove/km_punch")
				
				if headBone != nil then
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
				
				if headBone != nil then
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
				
				if headBone != nil then
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
				
				if headBone != nil then
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
				
				if headBone != nil then
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
				
				if headBone != nil then
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
				
				if headBone != nil then
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
	
	-- Check if player can killmove
	function KMCheck(ply)
		if ply.inKillMove then return false end
		
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
		
		-- Custom killmove hook
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
		
		-- Default killmoves
		if animName == "" and disableDefaults == 0 then
			plyKMModel = "models/weapons/c_limbs.mdl"
			
			if target:LookupBone("ValveBiped.Bip01_Spine") then
				targetKMModel = "models/bsmodimations_human.mdl"
				
				if angleAround <= 45 or angleAround > 315 then
					if ply:OnGround() then
						animName = "killmove_front_" .. math_random(1, 2)
						if animName == "killmove_front_1" then targetKMTime = 1.15 end
					else
						animName = "killmove_front_air_1"
					end
				elseif angleAround > 45 and angleAround <= 135 then
					animName = "killmove_left_1"
				elseif angleAround > 135 and angleAround <= 225 then
					animName = "killmove_back_1"
				elseif angleAround > 225 and angleAround <= 315 then
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
			
			if animName == "killmove_left_1" then
				plyKMPosition = targetPos + (-targetRight * 31.5)
			elseif animName == "killmove_right_1" then
				plyKMPosition = targetPos + (targetRight * 95) + (targetForward * 10)
				plyKMAngle = (-targetRight):Angle()
			elseif animName == "killmove_back_1" then
				plyKMPosition = targetPos + (-targetForward * 30)
			elseif animName == "killmove_front_1" then
				plyKMPosition = targetPos + (targetForward * 31.5)
			elseif animName == "killmove_front_2" then
				plyKMPosition = targetPos + (targetForward * 29)
			elseif animName == "killmove_front_air_1" then
				plyKMPosition = targetPos + (targetForward * 39)
			elseif animName == "killmove_hunter_front_1" then
				plyKMPosition = targetPos + (targetForward * 31.5)
			end
		end
		
		ply:KillMove(target, animName, plyKMModel, targetKMModel, plyKMPosition, plyKMAngle, plyKMTime, targetKMTime, moveTarget)
		
		return true
	end
	
	concommand.Add("bsmod_killmove", KMCheck)
	
	-- Now this function has a lot of arguments but that's cuz custom killmoves will use them, nothing else I can do :P
	function plymeta:KillMove(target, animName, plyKMModel, targetKMModel, plyKMPosition, plyKMAngle, plyKMTime, targetKMTime, moveTarget)
		if plyKMModel == "" or targetKMModel == "" or animName == "" then return end
		
		if self.inKillMove or self:Health() <= 0 or not IsValid(target) or target.inKillMove or target == self then return end
		
		-- End of return checks
		
		net.Start("debugbsmodcalcview")
		net.Broadcast()
		
		self.inKillMove = true
		
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
		self.kmAnim:SetPos(self:GetPos())
		self.kmAnim:SetAngles(self:GetAngles())
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
		self.kmModel:SetPos(self:GetPos())
		self.kmModel:SetAngles(self:GetAngles())
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
		target.inKillMove = true
		
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
		
		-- Store weapon reference
		local hideTargetWeapons = GetCVarInt(cv_hide_target_weapons) ~= 0
		if not target:IsNextBot() then 
			if IsValid(target:GetActiveWeapon()) then 
				target.kmModel.Weapon = target:GetActiveWeapon()
				-- Hide or parent the weapon during killmove
				if target:IsNPC() or target:IsNextBot() then
					if hideTargetWeapons then
						target:GetActiveWeapon():SetNoDraw(true)
					else
						-- Parent weapon to killmove model so it follows the animation
						target:GetActiveWeapon():SetParent(target.kmModel)
					end
				end
			end 
		end
		
		for i, bodygroup in ipairs(target:GetBodyGroups()) do
			target.kmModel:SetBodygroup(bodygroup.id, target:GetBodygroup(bodygroup.id))
		end
		
		for i, ent in ipairs(target:GetChildren()) do 
			if IsValid(ent) and ent:IsWeapon() then
				if hideTargetWeapons then
					-- Hide weapon
					ent:SetNoDraw(true)
				else
					-- Parent weapon to killmove model so it follows the animation
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
			local lerpDuration = math.Clamp(initialDistance / lerpSpeed, 0.05, 0.4)
			
			-- Store fixed start values for consistent lerping
			local lerpStartPos = startPosition
			local lerpStartAng = startAngle
			local lerpStartTime = CurTime()
			
			-- If in the air, skip lerp - set position instantly
			if !tempSelf:IsOnGround() then
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
				-- If addon provided custom angle, snap to it immediately (don't lerp angle)
				-- This prevents jarring 180° spins when the animation expects a specific orientation
				if hasCustomAngle then
					tempSelf:SetAngles(targetAngle)
					if tempSelf:IsPlayer() then tempSelf:SetEyeAngles(targetAngle) end
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
					
					-- Lerp position, but only lerp angle if no custom angle was provided
					local newPos = LerpVector(easedProgress, lerpStartPos, targetPosition)
					local newAng = hasCustomAngle and targetAngle or LerpAngle(easedProgress, lerpStartAng, targetAngle)
					
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
							if IsValid(target.kmModel) then target.kmModel:SetNoDraw(true) end
							
							if IsValid(target.kmModel) then
								local bonePos, boneAng = nil
								
								bonePos, boneAng = target.kmModel:GetBonePosition(0)
								
								target:SetPos(Vector(bonePos.x, bonePos.y, target:GetPos().z))
								--target:SetAngles(Angle(0, boneAng.y, 0))
							end
							
							target:SetHealth(1)
							
							target:DrawShadow( true )
							
							if target:IsPlayer() then
								target:SetMaterial(prevTMaterial)
							else
								target:SetNoDraw(false)
								-- Restore weapons for NPCs
								local hideTargetWeapons = GetCVarInt(cv_hide_target_weapons) ~= 0
								if IsValid(target:GetActiveWeapon()) then
									if hideTargetWeapons then
										target:GetActiveWeapon():SetNoDraw(false)
									else
										-- Unparent weapon back to target
										target:GetActiveWeapon():SetParent(target)
									end
								end
								-- Restore any child weapons
								for _, childEnt in ipairs(target.kmModel and target.kmModel:GetChildren() or {}) do
									if IsValid(childEnt) and childEnt:IsWeapon() then
										if hideTargetWeapons then
											childEnt:SetNoDraw(false)
										else
											childEnt:SetParent(target, childEnt:GetParentAttachment())
											childEnt:SetLocalPos(vector_origin)
											childEnt:SetLocalAngles(angle_zero)
										end
									end
								end
							end
							
							target.inKillMove = false
							
							if target:IsPlayer() then
								--target:DrawWorldModel(true)
								target:UnLock()
								
								if target:Health() > 0 then
									local dmginfo = DamageInfo()
									
									dmginfo:SetAttacker( self )
									dmginfo:SetDamageType( DMG_DIRECT )
									dmginfo:SetDamage( 999999999999 )
									
									target:TakeDamageInfo( dmginfo )
									
									timer.Simple(0, function() if target:Health() > 0 then target:Kill() end end)
								end
							elseif target:IsNPC() or target:IsNextBot() then
								--VJBase SNPC fix
								if target.IsVJBaseSNPC then
									target:TakeDamage(target:Health(), self, self)
								end
								
								--Set target's health to 0 to make sure certain npcs actually die
								target:SetHealth(0)
								
								local dmginfo = DamageInfo()
								
								dmginfo:SetAttacker( self )
								dmginfo:SetDamageType( DMG_SLASH )
								dmginfo:SetDamage( 1 )
								
								target:TakeDamageInfo( dmginfo )
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
							if IsValid(self.kmAnim) then
								local headBone = self.kmAnim:GetAttachment(self.kmAnim:LookupAttachment( "eyes" ))
								self:SetPos(Vector(headBone.Pos.x, headBone.Pos.y, headBone.Pos.z + (self:GetPos().z - self:EyePos().z)))
								self:SetEyeAngles(Angle(headBone.Ang.x, headBone.Ang.y, 0))
							end
							
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
							
							-- Reset FOV after killmove ends
							if GetCVarInt(cv_fovfx) == 1 and self:IsPlayer() then
								local fovValue = GetCVarInt(cv_fov_value)
								if fovValue > 0 then
									self:SetFOV(0, 0.3)
								end
							end
							
							if IsValid(self.kmModel) then 
								for i, ent in ipairs(self.kmModel:GetChildren()) do 
									ent:SetParent(self, ent:GetParentAttachment()) 
									ent:SetLocalPos(vector_origin)
									ent:SetLocalAngles(angle_zero)
								end 
								
								self.kmModel:Remove() 
							end
							if IsValid(self.kmAnim) then self.kmAnim:Remove() end
							
							if self.prevGodModeBSMod then
								self:GodEnable(true)
							end
							
							self.prevTargetBSMod = nil
							self.prevWeaponBSMod = nil
							self.prevGodModeBSMod = nil
							self.prevMaterialBSMod = nil
							
							self.inKillMove = false
							
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
						end
					end )
				end
			end	)
	end
end

if CLIENT then
	if !killMovableBones then killMovableBones = {"ValveBiped.Bip01_Spine", "MiniStrider.body_joint"} end
	if !killMovableEnts then killMovableEnts = {} end
	
	--[[concommand.Add("bsmod_reset_camerasettings", ResetBSModCamSettings, nil, "Reset Thirdperson KillMove Camera Settings.")
	
	function ResetBSModCamSettings()
		GetConVar( "bsmod_killmove_thirdperson_distance" ):Revert()
		GetConVar( "bsmod_killmove_thirdperson_pitch" ):Revert()
		GetConVar( "bsmod_killmove_thirdperson_yaw" ):Revert()
		GetConVar( "bsmod_killmove_thirdperson_offsetup" ):Revert()
		GetConVar( "bsmod_killmove_thirdperson_offsetright" ):Revert()
	end]]
	
	net.Receive("setkillmovable", function()
		
		local ent = net.ReadEntity()
		
		if IsValid(ent) then
			ent.killMovable = net.ReadBool()
			ent = net.ReadEntity()
		end
		
		--net.ReadEntity().killMovable = net.ReadBool()
	end)
	
	net.Receive("removedecals", function()
		
		local ent = net.ReadEntity()
		
		if IsValid(ent) then
			ent:RemoveAllDecals()
			ent = net.ReadEntity()
		end
		
		--net.ReadEntity():RemoveAllDecals()
	end)
	
	net.Receive("debugbsmodcalcview", function()
		if GetConVar( "bsmod_debug_calcview" ):GetInt() != 0 then
			PrintTable(hook.GetTable()["CalcView"])
		end
	end)
	
	--[[net.Receive("showhint", function()
		if GetConVar( "bsmod_enable_hints" ):GetInt() == 0 then return end
		
		notification.AddLegacy( net.ReadString(), net.ReadInt(4), net.ReadFloat() )
		
		surface.PlaySound( "ambient/water/drip" .. math.random( 1, 4 ) .. ".wav" )
	end)]]
	
	--Hide HUD elements when killmoving
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
			if engine.ActiveGamemode() != "sandbox" and cv_enable_teammates:GetInt() == 0 then
				if target:Team() == ply:Team() then return nil end
			end
		elseif target:IsNPC() or target:IsNextBot() then
			if cv_enable_npcs:GetInt() == 0 then return nil end
		else
			return nil
		end
		
		-- Check if entity has required bones/class (cached on entity)
		local canBeKillMoved = false
		if target.bsmod_canBeKillMoved != nil then
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
		local anytimeEnabled = cv_anytime:GetInt() != 0
		local anytimeBehindEnabled = cv_anytime_behind:GetInt() != 0
		
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
	
	-- Get the key bound to killmove command
	local function GetKillMoveKey()
		-- Check for user override first
		local override = cv_indicator_key:GetString()
		if override and override != "" then
			return string.upper(override)
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
	
	-- Combined indicator HUD (handles both prompt and icon modes)
	hook.Add("HUDPaint", "BSModKillMoveIndicator", function()
		local indicatorMode = cv_indicator:GetInt()
		if indicatorMode == 0 then return end
		
		local ply = LocalPlayer()
		if !IsValid(ply) or !ply:Alive() or ply.inKillMove or ply:Health() <= 0 then return end
		
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
		
		ragdoll:SetMaterial("null")
		ragdoll:RemoveAllDecals()
		
		timer.Simple(0.001, function()
			if entity:LookupBone("MiniStrider.body_joint") or !IsValid(entity.kmviewentity) or !IsValid(entity) or !IsValid(ragdoll) then return end
			
			local ent = ragdoll
			ragdoll:SetMaterial(entity:GetMaterial())
			for i = 1, ent:GetPhysicsObjectCount() do
				local bone = ent:GetPhysicsObjectNum(i)
				
				local targetEnt = entity.kmviewentity
				
				if !IsValid(targetEnt) then return end
				
				if bone and bone:IsValid() then
					local bonename = ent:GetBoneName(i)
					
					if !IsValid(targetEnt) then return end
					
					local plybone = targetEnt:LookupBone(bonename)
					
					if plybone then
						local bonepos, boneang = targetEnt:GetBonePosition(ent:TranslatePhysBoneToBone(plybone))
						
						bone:SetPos(bonepos, true)
						bone:SetAngles(boneang)
						bone:SetVelocity(vector_origin)
						
						bone:EnableMotion( false )
						
						timer.Simple(0.05, function()
							if !IsValid(bone) then return end
							
							bone:EnableMotion( true )
							
							bone:SetPos(bonepos, true)
							bone:SetAngles(boneang)
							bone:SetVelocity(vector_origin)
						end)
					end
				end
			end
			timer.Simple(0.075, function()
				if !IsValid(entity.kmviewanim) then return end
				
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
	
	hook.Add("CalcView", "BSModCalcView", function(ply, pos, angles, fov)
		local kmviewentity = ply.kmviewentity
		if IsValid(kmviewentity) and not kmviewentity:GetNoDraw() and ply:GetViewEntity() == ply then
			local KMOrigin = pos
			local KMAngles = angles
			
			local thirdperson = cv_thirdperson:GetInt() ~= 0
			
			if thirdperson then
				if ply.randTPYaw == nil and cv_thirdperson_randomyaw:GetInt() ~= 0 then 
					ply.randTPYaw = math.Rand(-180, 180) 
				end
				
				local yaw = cv_thirdperson_randomyaw:GetInt() == 0 and cv_thirdperson_yaw:GetFloat() or ply.randTPYaw
				local TPAng = angles + Angle(cv_thirdperson_pitch:GetFloat(), yaw, 0)
				
				local eyeAttachment = kmviewentity:GetAttachment(kmviewentity:LookupAttachment("eyes"))
				KMOrigin = eyeAttachment.Pos - (TPAng:Forward() * cv_thirdperson_distance:GetFloat()) + (TPAng:Up() * cv_thirdperson_offsetup:GetInt()) + (TPAng:Right() * cv_thirdperson_offsetright:GetFloat())
				KMAngles = TPAng
			else
				local eyeAttachment = kmviewentity:GetAttachment(kmviewentity:LookupAttachment("eyes"))
				KMOrigin = eyeAttachment.Pos
				KMAngles = eyeAttachment.Ang
			end
			
			return {
				origin = KMOrigin,
				angles = KMAngles,
				drawviewer = true
			}
		end
		
		if cv_thirdperson:GetInt() ~= 0 and (not IsValid(kmviewentity) or kmviewentity:GetNoDraw() or ply:GetViewEntity() ~= ply) then
			ply.randTPYaw = nil
		end
	end)
	
	-- Cache ConVars for OnEntityCreated
	local cv_hide_head = GetConVar("bsmod_killmove_hide_head")
	
	hook.Add("OnEntityCreated", "BSModOnEntityCreated", function(ent)
		if ent:GetClass() ~= "ent_km_model" then return end
		
		-- This was originally in the killmove entity's Initialize function but it was setting the viewtarget too late causing some visual issues for a few frames
		-- Putting it here fixes this problem
		local owner = ent:GetOwner()
		if not IsValid(owner) then return end
		
		if owner:GetModel() == ent:GetModel() then
			owner.kmviewentity = ent
			
			-- Hide the player's head if enabled and NOT in third person (helps with playermodel accessories blocking view)
			if owner == LocalPlayer() and cv_hide_head:GetInt() == 1 then
				timer.Simple(0, function()
					if not IsValid(ent) then return end
					
					local headBone = ent:LookupBone("ValveBiped.Bip01_Head1")
					if headBone then
						-- Only hide head in first person, restore it in third person
						if cv_thirdperson:GetInt() == 0 then
							ent:ManipulateBoneScale(headBone, Vector(0, 0, 0))
						else
							ent:ManipulateBoneScale(headBone, Vector(1, 1, 1))
						end
					end
				end)
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
end

hook.Add( "KMRagdoll", "BSModKMRagdoll", function(entity, ragdoll, animName)
	
	local spinePos, spineAng = nil
	
	if ragdoll:LookupBone("ValveBiped.Bip01_Spine") then 
		spinePos, spineAng = ragdoll:GetBonePosition(ragdoll:LookupBone("ValveBiped.Bip01_Spine"))
	end
	
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local bone = ragdoll:GetPhysicsObjectNum(i)
		
		if bone and bone:IsValid() then
			--local bonepos, boneang = ragdoll:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))
			
			if animName == "killmove_front_1" then
				if spineAng != nil then
					bone:SetVelocity(spineAng:Forward() * 150)
					bone:SetAngleVelocity(bone:WorldToLocalVector(-spineAng:Forward() * 2500))
				end
			elseif animName == "killmove_right_1" then
				bone:SetVelocity(Vector(0, 0, -1) * 50)
				bone:SetAngleVelocity(bone:WorldToLocalVector(-spineAng:Forward() * 1000))
			elseif animName == "killmove_back_1" then
				bone:SetVelocity((-spineAng:Right() * 125) + (-spineAng:Up() * 40))
			end
			
		end
	end
end)