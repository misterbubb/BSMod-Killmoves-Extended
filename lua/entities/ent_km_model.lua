AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

--[[
function ENT:Initialize() end
function ENT:PreEntityCopy() end
function ENT:PostEntityCopy() end
function ENT:PostEntityPaste() end
]]

function ENT:Think()
	if SERVER then 
		if !IsValid(self:GetOwner()) then self:Remove() end
		
		if IsValid(self:GetOwner()) then
			local owner = self:GetOwner()
			
			if self.maxKMTime != nil and owner.kmModel == self then
				
				if self.curKMTime == nil then self.curKMTime = 0 else self.curKMTime = self.curKMTime + FrameTime() end
				
				if self.curKMTime > self.maxKMTime - 0.4 then
					local headBone = self:GetAttachment(self:LookupAttachment( "eyes" ))
					--print("DEW IT!!!")
					if headBone != nil then
						owner:SetPos(Vector(headBone.Pos.x, headBone.Pos.y, headBone.Pos.z + (owner:GetPos().z - owner:EyePos().z)))
						owner:SetEyeAngles(Angle(headBone.Ang.x, headBone.Ang.y, 0))
					end
				end
			end
		end
	end
	
	self:NextThink(CurTime())
	return true
end

function ENT:RemoveDelay(delay)
	timer.Simple(delay, function()
		if !IsValid(self) then return end
		
		self:Remove()
	end)
end

function ENT:GetActiveWeapon()
	return self.Weapon
end

if ( SERVER ) then return end

function ENT:Draw() self:DrawModel() end
function ENT:DrawTranslucent() self:Draw() end
