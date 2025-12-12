--[[
Bone Animations Library
Created by William "JetBoom" Moodhe
Optimized for BSMod Extended
]]

if GetLuaAnimations ~= nil then return end

TYPE_GESTURE = 0
TYPE_POSTURE = 1
TYPE_STANCE = 2
TYPE_SEQUENCE = 3

INTERP_LINEAR = 0
INTERP_COSINE = 1
INTERP_CUBIC = 2
INTERP_DEFAULT = INTERP_COSINE

local Animations = {}

function GetLuaAnimations()
	return Animations
end

function RegisterLuaAnimation(sName, tInfo)
	if tInfo.FrameData then
		local BonesUsed = {}
		for iFrame, tFrame in ipairs(tInfo.FrameData) do
			for iBoneID, tBoneTable in pairs(tFrame.BoneInfo) do
				BonesUsed[iBoneID] = (BonesUsed[iBoneID] or 0) + 1
				tBoneTable.MU = tBoneTable.MU or 0
				tBoneTable.MF = tBoneTable.MF or 0
				tBoneTable.MR = tBoneTable.MR or 0
				tBoneTable.RU = tBoneTable.RU or 0
				tBoneTable.RF = tBoneTable.RF or 0
				tBoneTable.RR = tBoneTable.RR or 0
			end
		end

		if #tInfo.FrameData > 1 then
			for iBoneUsed, iTimesUsed in pairs(BonesUsed) do
				for iFrame, tFrame in ipairs(tInfo.FrameData) do
					if not tFrame.BoneInfo[iBoneUsed] then
						tFrame.BoneInfo[iBoneUsed] = {MU = 0, MF = 0, MR = 0, RU = 0, RF = 0, RR = 0}
					end
				end
			end
		end
	end
	Animations[sName] = tInfo
end
