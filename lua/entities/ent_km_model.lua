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
		local owner = self:GetOwner()
		
		-- Remove if owner is invalid or dead
		if !IsValid(owner) then 
			self:Remove() 
			return true
		end
		
		-- Remove if owner is no longer in a killmove (cleanup orphaned entities)
		if !owner.inKillMove and owner.kmModel ~= self and owner.kmAnim ~= self then
			-- Give a small grace period before removing
			if !self.orphanCheckTime then 
				self.orphanCheckTime = CurTime() 
			elseif CurTime() - self.orphanCheckTime > 1 then
				self:Remove()
				return true
			end
		else
			self.orphanCheckTime = nil
		end
		
		-- Safety timeout - remove after 30 seconds to prevent orphaned entities
		if !self.spawnTime then self.spawnTime = CurTime() end
		if CurTime() - self.spawnTime > 30 then
			self:Remove()
			return true
		end
		
		if self.maxKMTime != nil and owner.kmModel == self then
			if self.curKMTime == nil then self.curKMTime = 0 else self.curKMTime = self.curKMTime + FrameTime() end
			
			if self.curKMTime > self.maxKMTime - 0.4 then
				local eyesAttachment = self:LookupAttachment("eyes")
				if eyesAttachment and eyesAttachment > 0 then
					local headBone = self:GetAttachment(eyesAttachment)
					if headBone and headBone.Pos then
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

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	self:Draw()
end
