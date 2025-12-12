--[[
BSMod Punch SWEP
Original by AnOldLady, ported by RandomPerson189
Optimized for BSMod Extended
]]

-- Resource files
if SERVER then
	resource.AddFile("models/weapons/c_limbs.mdl")
	resource.AddFile("materials/effects/flour.vmt")
	
	-- Fist sounds
	resource.AddFile("sound/player/fists/fists_crackl.wav")
	resource.AddFile("sound/player/fists/fists_crackr.wav")
	resource.AddFile("sound/player/fists/fists_fire01.wav")
	resource.AddFile("sound/player/fists/fists_fire02.wav")
	resource.AddFile("sound/player/fists/fists_fire03.wav")
	resource.AddFile("sound/player/fists/fists_hit01.wav")
	resource.AddFile("sound/player/fists/fists_hit02.wav")
	resource.AddFile("sound/player/fists/fists_hit03.wav")
	resource.AddFile("sound/player/fists/fists_miss01.wav")
	resource.AddFile("sound/player/fists/fists_miss02.wav")
	resource.AddFile("sound/player/fists/fists_miss03.wav")
	
	-- Kick sounds
	resource.AddFile("sound/player/kick/foot_fire.wav")
	resource.AddFile("sound/player/kick/foot_kickbody.wav")
	resource.AddFile("sound/player/kick/foot_kickdoor.wav")
	resource.AddFile("sound/player/kick/foot_kickguy.wav")
	resource.AddFile("sound/player/kick/foot_kickhead.wav")
	resource.AddFile("sound/player/kick/foot_kickwall.wav")
	
	util.AddNetworkString("bsmodscreenshake")
end

if CLIENT then
	SWEP.PrintName = "BSMod Punch"
	SWEP.Slot = 0
	SWEP.SlotPos = 1
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/weapon_bsmod_punch")
end

SWEP.Author = "Original by AnOldLady, ported by RandomPerson189"
SWEP.Contact = ""
SWEP.Purpose = "Beat em up!"
SWEP.Instructions = "Left Click: Left punch, Right Click: Right punch, R: Block"

SWEP.Spawnable = true

SWEP.ViewModel = "models/weapons/c_limbs.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = true
SWEP.ViewModelFOV = 54

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.HitDistance = 75

-- Cache sound tables
local FireSounds = {
	"player/fists/fists_fire01.wav",
	"player/fists/fists_fire02.wav",
	"player/fists/fists_fire03.wav"
}

local HitSounds = {
	"player/fists/fists_hit01.wav",
	"player/fists/fists_hit02.wav",
	"player/fists/fists_hit03.wav"
}

local MissSounds = {
	"player/fists/fists_miss01.wav",
	"player/fists/fists_miss02.wav",
	"player/fists/fists_miss03.wav"
}

function SWEP:FireSound()
	self:EmitSound(FireSounds[math.random(1, 3)], 100, 100, 1, CHAN_AUTO)
end

function SWEP:HitSound()
	self:EmitSound(HitSounds[math.random(1, 3)], 100, 100, 1, CHAN_AUTO)
end

function SWEP:MissSound()
	self:EmitSound(MissSounds[math.random(1, 3)], 100, 100, 1, CHAN_AUTO)
end

function SWEP:Initialize()
	-- Precache sounds
	for _, snd in ipairs(FireSounds) do util.PrecacheSound(snd) end
	for _, snd in ipairs(HitSounds) do util.PrecacheSound(snd) end
	for _, snd in ipairs(MissSounds) do util.PrecacheSound(snd) end
	util.PrecacheSound("player/fists/fists_crackl.wav")
	util.PrecacheSound("player/fists/fists_crackr.wav")
	
	self:SetHoldType("fist")
end

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "NextMeleeAttack")
	self:NetworkVar("Float", 1, "NextMeleeAttack2")
end

function SWEP:Deploy()
	if SERVER then
		self:GetOwner().blocking = false
		
		timer.Simple(0.1, function()
			if not IsValid(self) then return end
			self:EmitSound("player/fists/fists_crackl.wav")
		end)
		
		timer.Simple(0.5, function()
			if not IsValid(self) then return end
			self:EmitSound("player/fists/fists_crackr.wav")
		end)
	end
	
	local vm = self:GetOwner():GetViewModel()
	if IsValid(vm) then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("fist_draw"))
	end
	
	return true
end

function SWEP:Reload()
	-- Block is handled in Think
end

function SWEP:Think()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	
	-- Don't process during killmoves
	if owner.inKillMove then
		if owner.blocking then
			owner.blocking = false
			self:SetHoldType("fist")
		end
		return
	end
	
	local vm = owner:GetViewModel()
	
	-- Blocking logic
	if owner:KeyDown(IN_RELOAD) then
		if not owner.blocking then
			if SERVER and IsValid(vm) then
				vm:SendViewModelMatchingSequence(vm:LookupSequence("fist_blocking"))
				if owner.killMovable then owner:SetKillMovable(false) end
			end
			owner.blocking = true
			self:SetHoldType("camera")
		end
	elseif owner.blocking then
		if SERVER and IsValid(vm) then
			vm:SendViewModelMatchingSequence(vm:LookupSequence("fist_blocking_end"))
		end
		owner.blocking = false
		self:SetHoldType("fist")
	end
	
	-- Process melee attacks
	local meleetime = self:GetNextMeleeAttack()
	local meleetime2 = self:GetNextMeleeAttack2()
	
	if meleetime > 0 and CurTime() > meleetime then
		self:DealDamage()
		self:SetNextMeleeAttack(0)
	end
	
	if meleetime2 > 0 and CurTime() > meleetime2 then
		self:DealDamage()
		self:SetNextMeleeAttack2(0)
	end
end

function SWEP:PrimaryAttack(right)
	local owner = self:GetOwner()
	if not IsValid(owner) or owner.blocking or owner.inKillMove then return end
	
	local punchDelay = GetConVar("bsmod_punch_delay"):GetFloat()
	local viewPunchAmount = GetConVar("bsmod_punch_viewpunch_amount"):GetFloat()
	
	local vm = owner:GetViewModel()
	local anim = right and "fist_rightpunch" or "fist_leftpunch"
	
	owner:SetAnimation(PLAYER_ATTACK1)
	
	if IsValid(vm) then
		vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
	end
	
	self:FireSound()
	
	if right then
		owner:ViewPunch(Angle(0, viewPunchAmount, viewPunchAmount))
		self:SetNextSecondaryFire(CurTime() + punchDelay)
		self:SetNextMeleeAttack2(CurTime() + 0.1)
	else
		owner:ViewPunch(Angle(0, -viewPunchAmount, viewPunchAmount))
		self:SetNextPrimaryFire(CurTime() + punchDelay)
		self:SetNextMeleeAttack(CurTime() + 0.1)
	end
end

function SWEP:SecondaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) or owner.blocking or owner.inKillMove then return end
	self:PrimaryAttack(true)
end

-- Cache ConVars for better performance
local cv_punch_damage_min = GetConVar("bsmod_punch_damage_min")
local cv_punch_damage_max = GetConVar("bsmod_punch_damage_max")
local cv_punch_effect = GetConVar("bsmod_punch_effect")

function SWEP:DealDamage()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	
	owner:LagCompensation(true)
	
	if IsFirstTimePredicted() then
		local damageMin = cv_punch_damage_min and cv_punch_damage_min:GetInt() or 10
		local damageMax = cv_punch_damage_max and cv_punch_damage_max:GetInt() or 15
		local showEffect = cv_punch_effect and cv_punch_effect:GetInt() ~= 0
		
		local bullet = {
			Num = 1,
			Src = owner:GetShootPos(),
			Dir = owner:EyeAngles():Forward(),
			Spread = Vector(0, 0, 0),
			Tracer = 0,
			Force = 20,
			HullSize = 1,
			Distance = self.HitDistance,
			Damage = math.random(damageMin, damageMax),
			Callback = function(attacker, trace, damageinfo)
				if not IsValid(trace.Entity) then return end
				
				if showEffect then
					local fx = EffectData()
					fx:SetStart(trace.HitPos)
					fx:SetOrigin(trace.HitPos)
					fx:SetNormal(trace.HitNormal)
					util.Effect("kick_groundhit", fx)
				end
				
				if trace.Entity:IsNPC() or trace.Entity:IsPlayer() then
					local pushDir = owner:GetForward()
					trace.Entity:SetVelocity(Vector(pushDir.x, pushDir.y, 0) * 250)
					self:HitSound()
				else
					self:MissSound()
				end
				
				util.ScreenShake(trace.HitPos, 0.5, 10, 0.5, 250)
			end
		}
		
		owner:FireBullets(bullet, false)
	end
	
	owner:LagCompensation(false)
end

-- Blocking damage reduction
if SERVER then
	-- Cache blocking resistance ConVar
	local cv_blocking_resistance = GetConVar("bsmod_punch_blocking_resistance")
	
	hook.Add("EntityTakeDamage", "BSModPunchTakeDamage", function(ent, dmginfo)
		if not ent.blocking then return end
		
		-- Don't block environmental damage
		local dmgType = dmginfo:GetDamageType()
		if bit.band(dmgType, DMG_FALL + DMG_BURN + DMG_DROWN + DMG_POISON + DMG_SLOWBURN + DMG_DROWNRECOVER) ~= 0 then
			return
		end
		
		local resistance = cv_blocking_resistance and cv_blocking_resistance:GetInt() or 50
		local damage = dmginfo:GetDamage()
		local reduction = math.ceil((damage / 100) * resistance)
		dmginfo:SetDamage(damage - reduction)
		
		local vm = ent:GetViewModel()
		if IsValid(vm) then
			vm:SendViewModelMatchingSequence(vm:LookupSequence("fist_blocking_flinch"))
			
			timer.Simple(vm:SequenceDuration(), function()
				if not IsValid(ent) or not ent.blocking then return end
				vm:SendViewModelMatchingSequence(vm:LookupSequence("fist_blocking"))
			end)
		end
	end)
end
