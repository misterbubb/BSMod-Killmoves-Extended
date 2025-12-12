function EFFECT:Init(data)
	local Pos = data:GetOrigin()
	local Norm = data:GetNormal()
	local emitter = ParticleEmitter(Pos)
	
	if not emitter then return end
	
	-- Create multiple particles for a better dust effect
	for i = 1, 3 do
		local particle = emitter:Add("effects/flour", Pos + Norm * math.random(2, 5))
		if particle then
			particle:SetDieTime(math.Rand(0.3, 0.6))
			particle:SetStartAlpha(math.random(180, 255))
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.random(3, 6))
			particle:SetEndSize(math.random(8, 14))
			particle:SetColor(30, 30, 30)
			particle:SetCollide(true)
			particle:SetBounce(0.3)
			particle:SetVelocity(Norm * math.random(10, 30) + VectorRand() * 5)
			particle:SetGravity(Vector(0, 0, -50))
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-2, 2))
		end
	end
	
	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
