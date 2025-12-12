--[[
BSMod Kick System
Original by LeErOy NeWmAn and WHORSHIPPER
Optimized for BSMod Extended
]]

-- Performance: Cache frequently used globals
local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random
local Vector = Vector
local Angle = Angle

if SERVER then
	include("kick_animapi/boneanimlib.lua")
end
if CLIENT then	
	include("kick_animapi/cl_boneanimlib.lua") 
end

-- Register kick animation
RegisterLuaAnimation('bsmod_kickanim', {
	FrameData = {
		{
			BoneInfo = {
				['ValveBiped.Bip01_R_Calf'] = { RU = -44.555652469149 },
				['ValveBiped.Bip01_R_Thigh'] = { RU = -50.441395011994 }
			},
			FrameRate = 4
		},
		{
			BoneInfo = {
				['ValveBiped.Bip01_R_Calf'] = {},
				['ValveBiped.Bip01_R_Thigh'] = {}
			},
			FrameRate = 2
		}
	},
	Type = TYPE_GESTURE
})

local function CalcPlayerModelsAngle(ply)
	local defans = Angle(-90, 0, 0)
	if ply:Health() <= 0 then return defans end
	local StartAngle = ply:EyeAngles()
	if not StartAngle then return defans end
	return Angle((StartAngle.p) / 1.1 - 20, StartAngle.y, 0)
end

if CLIENT then
	util.PrecacheSound("player/kick/foot_fire.wav")
	util.PrecacheSound("player/kick/foot_kickbody.wav")
	util.PrecacheSound("player/kick/foot_kickwall.wav")
	
	local kickvmoffset = Vector(-10, 0, -12.5)
	
	net.Receive("Kicking", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end
		
		ply:SetNWBool("Kicking", net.ReadBool())
		ply.KickTime = CurTime()
		ply.StopKick = ply.KickTime + 0.7
		
		if IsValid(ply.CreateLegs) then
			local sequences = {"leg_attack", "leg_attack3", "leg_attack4"}
			ply.CreateLegs:SetSequence(ply.CreateLegs:LookupSequence(sequences[math_random(1, 3)]))
			ply.CreateLegs:SetCycle(0)
		end
	end)

	hook.Add("Think", "BSModKickThink", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		
		-- Don't show kick legs during killmoves
		if ply.inKillMove then
			if IsValid(ply.CreateLegs) then
				SafeRemoveEntity(ply.CreateLegs)
				ply.CreateLegs = nil
			end
			if IsValid(ply.CreatePMLegs) then
				SafeRemoveEntity(ply.CreatePMLegs)
				ply.CreatePMLegs = nil
			end
			return
		end
		
		local Kicking = ply:GetNWBool("Kicking", false)
		local isFirstPerson = GetViewEntity() == ply and (not ply.ShouldDrawLocalPlayer or not ply:ShouldDrawLocalPlayer())
		
		if isFirstPerson and Kicking and ply.StopKick and ply.StopKick > CurTime() then
			local off = Vector(kickvmoffset.x, kickvmoffset.y, kickvmoffset.z)
			off:Rotate(CalcPlayerModelsAngle(ply))
			local shootPos = ply:GetShootPos()
			
			-- Create or update leg animation model
			if not IsValid(ply.CreateLegs) then
				ply.CreateLegs = ClientsideModel("models/weapons/c_limbs.mdl", RENDERGROUP_TRANSLUCENT)
				ply.CreateLegs:Spawn()
				ply.CreateLegs:SetPos(shootPos + off)
				ply.CreateLegs:SetAngles(CalcPlayerModelsAngle(ply))
				ply.CreateLegs:SetParent(ply)
				ply.CreateLegs:SetNoDraw(true)
				ply.CreateLegs:SetCycle(0)
				
				local sequences = {"leg_attack", "leg_attack3", "leg_attack4"}
				ply.CreateLegs:SetSequence(ply.CreateLegs:LookupSequence(sequences[math_random(1, 3)]))
				ply.CreateLegs:SetPlaybackRate(1)
				ply.CreateLegs.LastTick = CurTime()
			else
				ply.CreateLegs:SetPos(shootPos + off)
				ply.CreateLegs:SetAngles(CalcPlayerModelsAngle(ply))
				ply.CreateLegs:FrameAdvance(CurTime() - ply.CreateLegs.LastTick)
				ply.CreateLegs.LastTick = CurTime()
			end
			
			-- Create or update playermodel legs
			if not IsValid(ply.CreatePMLegs) then
				ply.CreatePMLegs = ClientsideModel(ply:GetModel(), RENDERGROUP_TRANSLUCENT)
				ply.CreatePMLegs:Spawn()
				ply.CreatePMLegs:SetParent(ply.CreateLegs)
				ply.CreatePMLegs:SetPos(shootPos + off)
				ply.CreatePMLegs:SetAngles(CalcPlayerModelsAngle(ply))
				ply.CreatePMLegs:SetSkin(ply:GetSkin())
				ply.CreatePMLegs:SetColor(ply:GetColor())
				ply.CreatePMLegs:SetMaterial(ply:GetMaterial())
				ply.CreatePMLegs:SetRenderMode(ply:GetRenderMode())
				
				for _, bodygroup in pairs(ply:GetBodyGroups()) do
					ply.CreatePMLegs:SetBodygroup(bodygroup.id, ply:GetBodygroup(bodygroup.id))
				end
				
				ply.CreatePMLegs:DrawShadow(false)
				local playerColor = ply:GetPlayerColor()
				ply.CreatePMLegs.GetPlayerColor = function() 
					return Vector(playerColor.r, playerColor.g, playerColor.b) 
				end
				ply.CreatePMLegs:SetNoDraw(false)
				ply.CreatePMLegs:AddEffects(EF_BONEMERGE)
				ply.CreatePMLegs:SetPlaybackRate(1)
				ply.CreatePMLegs.LastTick = CurTime()
			else
				ply.CreatePMLegs:SetPos(shootPos + off)
				ply.CreatePMLegs:SetAngles(CalcPlayerModelsAngle(ply))
				ply.CreatePMLegs:FrameAdvance(CurTime() - ply.CreateLegs.LastTick)
				ply.CreatePMLegs:DrawModel()
				ply.CreatePMLegs.LastTick = CurTime()
			end
		else
			-- Cleanup leg models
			if IsValid(ply.CreateLegs) then
				ply.CreateLegs:SetNoDraw(true)
				SafeRemoveEntity(ply.CreateLegs)
				ply.CreateLegs = nil
			end
			
			if IsValid(ply.CreatePMLegs) then
				ply.CreatePMLegs:SetNoDraw(true)
				SafeRemoveEntity(ply.CreatePMLegs)
				ply.CreatePMLegs = nil
			end
		end
	end)
end


-- Server-side kick logic
if SERVER then
	util.AddNetworkString("Kicking")
	
	-- Cache ConVars
	local cv_kick_enabled, cv_kick_delay, cv_kick_damage_min, cv_kick_damage_max
	local cv_kick_viewpunch, cv_kick_blowdoor, cv_kick_chancetoblowdoor, cv_killmove_by_kicking
	
	local function CacheKickConVars()
		cv_kick_enabled = GetConVar("bsmod_kick_enabled")
		cv_kick_delay = GetConVar("bsmod_kick_delay")
		cv_kick_damage_min = GetConVar("bsmod_kick_damage_min")
		cv_kick_damage_max = GetConVar("bsmod_kick_damage_max")
		cv_kick_viewpunch = GetConVar("bsmod_kick_viewpunch_amount")
		cv_kick_blowdoor = GetConVar("bsmod_kick_blowdoor")
		cv_kick_chancetoblowdoor = GetConVar("bsmod_kick_chancetoblowdoor")
		cv_killmove_by_kicking = GetConVar("bsmod_killmove_by_kicking")
	end
	
	hook.Add("Initialize", "BSModCacheKickConVars", CacheKickConVars)
	timer.Simple(0, function() if not cv_kick_enabled then CacheKickConVars() end end)
	
	local function GetCVarInt(cv)
		return cv and cv:GetInt() or 0
	end
	local function GetCVarFloat(cv)
		return cv and cv:GetFloat() or 0
	end
	
	-- Kick a door off its hinges
	local function FakeDoor(Door, attacker, amount)
		local pos = Door:GetPos()
		local ang = Door:GetAngles()
		local model = Door:GetModel()
		local skin = Door:GetSkin()

		Door:SetNotSolid(true)
		Door:SetNoDraw(true)

		local ent = ents.Create("prop_physics")
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:SetModel(model)
		if skin then ent:SetSkin(skin) end
		ent:Spawn()
		ent:EmitSound("physics/wood/wood_furniture_break" .. math_random(1, 2) .. ".wav", 100)
		ent:SetVelocity(attacker:GetAimVector() * (amount * 300))
		
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:ApplyForceCenter(attacker:GetAimVector() * (amount * 300))
		end
		
		-- Reset door after delay
		timer.Simple(10, function()
			if IsValid(Door) then
				Door:SetNotSolid(false)
				Door:SetNoDraw(false)
			end
			if IsValid(ent) then
				ent:Remove()
			end
		end)
	end
	
	local function KickHit(ply)
		if ply.inKillMove then return end
		
		local damage = math_random(GetCVarInt(cv_kick_damage_min), GetCVarInt(cv_kick_damage_max))
		
		local bul = {
			Attacker = ply,
			Damage = damage,
			Force = 20,
			Distance = 75,
			HullSize = 1,
			Tracer = 0,
			Dir = ply:EyeAngles():Forward(),
			Src = ply:GetShootPos(),
			Callback = function(attacker, trace, damageinfo)
				if not trace then return end
				
				if trace.HitPos:Distance(ply:GetShootPos()) <= 75 then
					util.ScreenShake(trace.HitPos, 1, 10, 0.5, 250)
					
					if trace.MatType == MAT_FLESH then
						trace.Entity:EmitSound("player/kick/foot_kickbody.wav", 100)
					else
						ply:EmitSound("player/kick/foot_kickwall.wav", 100)
						
						local fx = EffectData()
						fx:SetStart(trace.HitPos)
						fx:SetOrigin(trace.HitPos)
						fx:SetNormal(trace.HitNormal)
						util.Effect("kick_groundhit", fx)
					end
					
					-- Door kicking
					local entClass = trace.Entity:GetClass()
					if entClass == "func_door_rotating" or entClass == "prop_door_rotating" then
						local canBlowDoor = GetCVarInt(cv_kick_blowdoor) >= 1
						local blowChance = GetCVarInt(cv_kick_chancetoblowdoor)
						
						if canBlowDoor and math_random(1, blowChance) == 1 and entClass == "prop_door_rotating" then
							FakeDoor(trace.Entity, ply, damage)
							ply:EmitSound("ambient/materials/door_hit1.wav", 100)
						else
							ply:EmitSound("ambient/materials/door_hit1.wav", 100)
							
							local oldname = ply:GetName()
							ply:SetName("kickingpl" .. ply:EntIndex())
							
							trace.Entity:SetKeyValue("Speed", "500")
							trace.Entity:SetKeyValue("Open Direction", "Both directions")
							trace.Entity:Fire("unlock", "", 0.01)
							trace.Entity:Fire("openawayfrom", "kickingpl" .. ply:EntIndex(), 0.01)
							
							timer.Simple(0.02, function()
								if IsValid(ply) then ply:SetName(oldname) end
							end)
							
							timer.Simple(0.3, function()
								if IsValid(trace.Entity) then
									trace.Entity:SetKeyValue("Speed", "100")
								end
							end)
						end
					end
				end
			end
		}
		
		ply:FireBullets(bul, false)
	end
	
	function BSModKick(ply)
		-- Check if kicking should trigger killmove
		if GetCVarInt(cv_killmove_by_kicking) ~= 0 then
			if KMCheck and KMCheck(ply) then return false end
		end
		
		if not ply:Alive() or ply.inKillMove then return false end
		if GetCVarInt(cv_kick_enabled) ~= 1 then return false end
		
		local kickDelay = GetCVarFloat(cv_kick_delay)
		if kickDelay <= 0 then kickDelay = 0.7 end
		
		if not ply.StopKick or ply.StopKick < CurTime() then
			local viewPunchAmount = GetCVarFloat(cv_kick_viewpunch)
			
			ply:SetNWBool("Kicking", true)
			ply.KickTime = CurTime()
			ply.StopKick = ply.KickTime + kickDelay
			
			if ply.ResetLuaAnimation then
				ply:ResetLuaAnimation("bsmod_kickanim")
			end
			
			net.Start("Kicking")
			net.WriteBool(true)
			net.Send(ply)
			
			ply:ViewPunch(Angle(viewPunchAmount, 0, 0))
			ply:EmitSound("player/kick/foot_fire.wav", 100)
			
			timer.Remove("BSModKick_" .. ply:SteamID())
			timer.Create("BSModKick_" .. ply:SteamID(), 0.15, 1, function()
				if IsValid(ply) then KickHit(ply) end
			end)
		end
	end
	
	concommand.Add("bsmod_kick", BSModKick)
	
	-- Reset kick state on spawn/death
	hook.Add("PlayerSpawn", "BSModKickPlayerSpawn", function(ply)
		ply.Kicking = false
		ply.KickTime = -1
		ply.StopKick = -1
		ply:SetNWBool("Kicking", false)
	end)
	
	hook.Add("PlayerDeath", "BSModKickPlayerDeath", function(ply)
		ply.Kicking = false
		ply.KickTime = -1
		ply.StopKick = -1
		ply:SetNWBool("Kicking", false)
		
		local steamId = ply:SteamID()
		if steamId then
			timer.Remove("BSModKick_" .. steamId)
		end
	end)
	
	-- Clean up timers on disconnect
	hook.Add("PlayerDisconnected", "BSModKickPlayerDisconnected", function(ply)
		local steamId = ply:SteamID()
		if steamId then
			timer.Remove("BSModKick_" .. steamId)
		end
	end)
end
