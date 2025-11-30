if CLIENT then
	SWEP.PrintName = "KillMove Initiated"
	SWEP.Slot = -10
	SWEP.SlotPos = -10
end

SWEP.Author = ""
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.Instructions = ""

SWEP.Spawnable = false 

SWEP.ViewModel = "" 
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 54

SWEP.Primary.ClipSize = -1 
SWEP.Primary.DefaultClip = -1 
SWEP.Primary.Automatic = false 
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo	= "none"

SWEP.DrawAmmo = false

SWEP.HitDistance = 75

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:Deploy()
end 

function SWEP:Reload() 
end 

function SWEP:Think()
end 

function SWEP:PrimaryAttack(right) 
end

function SWEP:SecondaryAttack()
end