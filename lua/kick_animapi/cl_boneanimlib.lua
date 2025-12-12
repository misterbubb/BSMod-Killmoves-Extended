if SERVER or GetLuaAnimations ~= nil then return end

include("sh_boneanimlib.lua")

-- Performance: Cache frequently used globals
local CurTime = CurTime
local FrameTime = FrameTime
local IsValid = IsValid
local pairs = pairs
local ipairs = ipairs
local math_cos = math.cos
local math_min = math.min
local math_pi = math.pi
local angle_zero = angle_zero
local vector_origin = vector_origin

local ANIMATIONFADEOUTTIME = 0.125

net.Receive("bal_reset", function()
	local ent = net.ReadEntity()
	local anim = net.ReadString()
	local time = net.ReadFloat()
	local power = net.ReadFloat()
	local timescale = net.ReadFloat()
	if ent:IsValid() then
		ent:ResetLuaAnimation(anim, time ~= -1 and time, power ~= -1 and power, timescale ~= -1 and timescale)
	end
end)

net.Receive("bal_set", function()
	local ent = net.ReadEntity()
	local anim = net.ReadString()
	local time = net.ReadFloat()
	local power = net.ReadFloat()
	local timescale = net.ReadFloat()
	if ent:IsValid() then
		ent:SetLuaAnimation(anim, time ~= -1 and time, power ~= -1 and power, timescale ~= -1 and timescale)
	end
end)

net.Receive("bal_stop", function()
	local ent = net.ReadEntity()
	local anim = net.ReadString()
	local tim = net.ReadFloat()
	if tim == 0 then tim = nil end
	if ent:IsValid() then
		ent:StopLuaAnimation(anim, tim)
	end
end)

net.Receive("bal_stopgroup", function()
	local ent = net.ReadEntity()
	local animgroup = net.ReadString()
	local tim = net.ReadFloat()
	if tim == 0 then tim = nil end
	if ent:IsValid() then
		ent:StopLuaAnimationGroup(animgroup, tim)
	end
end)

net.Receive("bal_stopall", function()
	local ent = net.ReadEntity()
	local tim = net.ReadFloat()
	if tim == 0 then tim = nil end
	if ent:IsValid() then
		ent:StopAllLuaAnimations(tim)
	end
end)

local Animations = GetLuaAnimations()

local function AdvanceFrame(tGestureTable, tFrameData)
	tGestureTable.FrameDelta = tGestureTable.FrameDelta + FrameTime() * tFrameData.FrameRate * tGestureTable.TimeScale
	if tGestureTable.FrameDelta > 1 then
		tGestureTable.Frame = tGestureTable.Frame + 1
		tGestureTable.FrameDelta = math.min(1, tGestureTable.FrameDelta - 1)
		if tGestureTable.Frame > #tGestureTable.FrameData then
			tGestureTable.Frame = math.min(tGestureTable.RestartFrame or 1, #tGestureTable.FrameData)
			return true
		end
	end
	return false
end

local function CosineInterpolation(y1, y2, mu)
	local mu2 = (1 - math_cos(mu * math_pi)) / 2
	return y1 * (1 - mu2) + y2 * mu2
end

local EMPTYBONEINFO = {MU = 0, MR = 0, MF = 0, RU = 0, RR = 0, RF = 0}
local function GetFrameBoneInfo(pl, tGestureTable, iFrame, iBoneID)
	local tPrev = tGestureTable.FrameData[iFrame]
	if tPrev then
		return tPrev.BoneInfo[iBoneID] or tPrev.BoneInfo[pl:GetBoneName(iBoneID)] or EMPTYBONEINFO
	end
	return EMPTYBONEINFO
end

local function DoCurrentFrame(tGestureTable, tFrameData, iCurFrame, pl, fAmount, fFrameDelta, fPower, bNoInterp, tBuffer)
	for iBoneID, tBoneInfo in pairs(tFrameData.BoneInfo) do
		if type(iBoneID) ~= "number" then
			iBoneID = pl:LookupBone(iBoneID)
		end
		if not iBoneID then continue end

		if not tBuffer[iBoneID] then tBuffer[iBoneID] = Matrix() end
		local mBoneMatrix = tBuffer[iBoneID]

		local vCurBonePos, aCurBoneAng = mBoneMatrix:GetTranslation(), mBoneMatrix:GetAngles()
		if not tBoneInfo.Callback or not tBoneInfo.Callback(pl, mBoneMatrix, iBoneID, vCurBonePos, aCurBoneAng, fFrameDelta, fPower) then
			local vUp = aCurBoneAng:Up()
			local vRight = aCurBoneAng:Right()
			local vForward = aCurBoneAng:Forward()

			if bNoInterp then
				mBoneMatrix:Translate((tBoneInfo.MU * vUp + tBoneInfo.MR * vRight + tBoneInfo.MF * vForward) * fAmount)
				mBoneMatrix:Rotate(Angle(tBoneInfo.RR, tBoneInfo.RU, tBoneInfo.RF) * fAmount)
			else
				local bi1 = GetFrameBoneInfo(pl, tGestureTable, iCurFrame - 1, iBoneID)
				mBoneMatrix:Translate(CosineInterpolation(bi1.MU * vUp + bi1.MR * vRight + bi1.MF * vForward, tBoneInfo.MU * vUp + tBoneInfo.MR * vRight + tBoneInfo.MF * vForward, fFrameDelta) * fPower)
				mBoneMatrix:Rotate(CosineInterpolation(Angle(bi1.RR, bi1.RU, bi1.RF), Angle(tBoneInfo.RR, tBoneInfo.RU, tBoneInfo.RF), fFrameDelta) * fPower)
			end
		end
	end
end

local function BuildBonePositions(pl)
	local tBuffer = {}
	local tLuaAnimations = pl.LuaAnimations
	
	for sGestureName, tGestureTable in pairs(tLuaAnimations) do
		local iCurFrame = tGestureTable.Frame
		local tFrameData = tGestureTable.FrameData[iCurFrame]
		local fFrameDelta = tGestureTable.FrameDelta
		local fDieTime = tGestureTable.DieTime
		local fPower = tGestureTable.Power
		
		if fDieTime and fDieTime - ANIMATIONFADEOUTTIME <= CurTime() then
			fPower = fPower * (fDieTime - CurTime()) / ANIMATIONFADEOUTTIME
		end
		
		local fAmount = fPower * fFrameDelta
		DoCurrentFrame(tGestureTable, tFrameData, iCurFrame, pl, fAmount, fFrameDelta, fPower, tGestureTable.Type == TYPE_POSTURE, tBuffer)
	end

	for iBoneID, mMatrix in pairs(tBuffer) do
		pl:ManipulateBonePosition(iBoneID, mMatrix:GetTranslation())
		pl:ManipulateBoneAngles(iBoneID, mMatrix:GetAngles())
	end
end

local function ProcessAnimations(pl)
	pl:ResetBoneMatrix()
	local tLuaAnimations = pl.LuaAnimations
	
	for sGestureName, tGestureTable in pairs(tLuaAnimations) do
		local iCurFrame = tGestureTable.Frame
		local tFrameData = tGestureTable.FrameData[iCurFrame]
		local fDieTime = tGestureTable.DieTime

		if fDieTime and fDieTime <= CurTime() then
			pl:StopLuaAnimation(sGestureName)
		elseif tGestureTable.Type == TYPE_GESTURE then
			if AdvanceFrame(tGestureTable, tFrameData) then
				pl:StopLuaAnimation(sGestureName)
			end
		elseif tGestureTable.Type == TYPE_POSTURE then
			if tGestureTable.FrameDelta < 1 and tGestureTable.TimeToArrive then
				tGestureTable.FrameDelta = math_min(1, tGestureTable.FrameDelta + FrameTime() * (1 / tGestureTable.TimeToArrive))
			end
		else
			AdvanceFrame(tGestureTable, tFrameData)
		end
	end

	if pl.LuaAnimations then
		BuildBonePositions(pl)
	end
end

hook.Add("Think", "BoneAnimThink", function()
	for _, pl in ipairs(player.GetAll()) do
		-- Skip players in killmoves to avoid interfering with killmove bone manipulation
		if pl.LuaAnimations and pl:IsValid() and not pl.inKillMove then
			ProcessAnimations(pl)
		end
	end
end)

local meta = FindMetaTable("Entity")
if not meta then return end

function meta:ResetBoneMatrix()
	-- Don't reset bones during killmoves
	if self.inKillMove then return end
	
	for i = 0, self:GetBoneCount() - 1 do
		self:ManipulateBoneAngles(i, angle_zero)
		self:ManipulateBonePosition(i, vector_origin)
	end
end

function meta:ResetLuaAnimation(sAnimation, fDieTime, fPower, fTimeScale)
	local animtable = Animations[sAnimation]
	if animtable then
		self.LuaAnimations = self.LuaAnimations or {}
		self.LuaAnimations[sAnimation] = {
			Frame = animtable.StartFrame or 1,
			FrameDelta = animtable.Type == TYPE_POSTURE and not animtable.TimeToArrive and 1 or 0,
			FrameData = animtable.FrameData,
			TimeScale = fTimeScale or animtable.TimeScale or 1,
			Type = animtable.Type,
			RestartFrame = animtable.RestartFrame,
			TimeToArrive = animtable.TimeToArrive,
			Power = fPower or animtable.Power or 1,
			DieTime = fDieTime or animtable.DieTime,
			Group = animtable.Group
		}
		self:ResetLuaAnimationProperties()
	end
end

function meta:SetLuaAnimation(sAnimation, fDieTime, fPower, fTimeScale)
	if self.LuaAnimations and self.LuaAnimations[sAnimation] then return end
	self:ResetLuaAnimation(sAnimation, fDieTime, fPower, fTimeScale)
end

function meta:ResetLuaAnimationProperties()
	local anims = self.LuaAnimations
	if anims and table.Count(anims) > 0 then
		self:SetIK(false)
	else
		self.LuaAnimations = nil
		self:ResetBoneMatrix()
	end
end

function meta:StopLuaAnimation(sAnimation, fTime)
	local anims = self.LuaAnimations
	if anims and anims[sAnimation] then
		if fTime then
			if anims[sAnimation].DieTime then
				anims[sAnimation].DieTime = math.min(anims[sAnimation].DieTime, CurTime() + fTime)
			else
				anims[sAnimation].DieTime = CurTime() + fTime
			end
		else
			anims[sAnimation] = nil
		end
		self:ResetLuaAnimationProperties()
	end
end

function meta:StopLuaAnimationGroup(sGroup, fTime)
	if self.LuaAnimations then
		for animname, animtable in pairs(self.LuaAnimations) do
			if animtable.Group == sGroup then
				self:StopLuaAnimation(animname, fTime)
			end
		end
	end
end

function meta:StopAllLuaAnimations(fTime)
	if self.LuaAnimations then
		for name in pairs(self.LuaAnimations) do
			self:StopLuaAnimation(name, fTime)
		end
	end
end
