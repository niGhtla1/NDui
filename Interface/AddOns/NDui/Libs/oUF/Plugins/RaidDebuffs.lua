-------------------------------
-- oUF_RaidDebuffs, by yleaf
-- NDui MOD
-------------------------------
local _, ns = ...
local B, C, L, DB = unpack(ns)
local oUF = ns.oUF or oUF

local debugMode = false
local next = next
local class = DB.MyClass
local RaidDebuffsIgnore, invalidPrio = {}, -1

local DispellColor = {
	["Magic"]	= {.2, .6, 1},
	["Curse"]	= {.6, 0, 1},
	["Disease"]	= {.6, .4, 0},
	["Poison"]	= {0, .6, 0},
	["none"]	= {0, 0, 0},
}

local DispellPriority = {
	["Magic"]	= 4,
	["Curse"]	= 3,
	["Disease"]	= 2,
	["Poison"]	= 1,
}

local DispellFilter
do
	local dispellClasses = {
		["DRUID"] = {
			["Magic"] = false,
			["Curse"] = true,
			["Poison"] = true,
		},
		["MONK"] = {
			["Magic"] = true,
			["Poison"] = true,
			["Disease"] = true,
		},
		["PALADIN"] = {
			["Magic"] = false,
			["Poison"] = true,
			["Disease"] = true,
		},
		["PRIEST"] = {
			["Magic"] = false,
			["Disease"] = false,
		},
		["SHAMAN"] = {
			["Magic"] = false,
			["Curse"] = true,
		},
		["MAGE"] = {
			["Curse"] = true,
		},
	}

	DispellFilter = dispellClasses[class] or {}
end

local function checkSpecs()
	if class == "DRUID" then
		if GetSpecialization() == 4 then
			DispellFilter.Magic = true
		else
			DispellFilter.Magic = false
		end
	elseif class == "MONK" then
		if GetSpecialization() == 2 then
			DispellFilter.Magic = true
		else
			DispellFilter.Magic = false
		end
	elseif class == "PALADIN" then
		if GetSpecialization() == 1 then
			DispellFilter.Magic = true
		else
			DispellFilter.Magic = false
		end
	elseif class == "PRIEST" then
		if GetSpecialization() == 3 then
			DispellFilter.Magic = false
			DispellFilter.Disease = false
		else
			DispellFilter.Magic = true
			DispellFilter.Disease = true
		end
	elseif class == "SHAMAN" then
		if GetSpecialization() == 3 then
			DispellFilter.Magic = true
		else
			DispellFilter.Magic = false
		end
	end
end

local function UpdateDebuffFrame(self, name, icon, count, debuffType, duration, expiration, spellId)
	local rd = self.RaidDebuffs
	if name then
		if rd.icon then
			rd.icon:SetTexture(icon)
			rd.icon:Show()
		end

		if rd.count then
			if count and count > 1 then
				rd.count:SetText(count)
				rd.count:Show()
			else
				rd.count:Hide()
			end
		end

		if rd.timer then
			rd.duration = duration
			if duration and duration > 0 then
				rd.expiration = expiration
				rd:SetScript("OnUpdate", B.CooldownOnUpdate)
				rd.timer:Show()
			else
				rd:SetScript("OnUpdate", nil)
				rd.timer:Hide()
			end
		end

		if rd.cd then
			if duration and duration > 0 then
				rd.cd:SetCooldown(expiration - duration, duration)
				rd.cd:Show()
			else
				rd.cd:Hide()
			end
		end

		local c = DispellColor[debuffType] or DispellColor.none
		if rd.ShowDebuffBorder and rd.Shadow then
			rd.Shadow:SetBackdropBorderColor(c[1], c[2], c[3])
		end

		if rd.glowFrame then
			if rd.priority == 6 then
				B.ShowOverlayGlow(rd.glowFrame)
			else
				B.HideOverlayGlow(rd.glowFrame)
			end
		end

		rd:Show()
	else
		rd:Hide()
	end
end

local instName
local function checkInstance()
	if IsInInstance() then
		instName = GetInstanceInfo()
	else
		instName = nil
	end
end

local function Update(self, _, unit)
	if unit ~= self.unit then return end

	local rd = self.RaidDebuffs
	rd.priority = invalidPrio
	local _name, _icon, _count, _debuffType, _duration, _expiration, _spellId
	local debuffs = rd.Debuffs or {}
	local isCharmed = UnitIsCharmed(unit)
	local canAttack = UnitCanAttack("player", unit)
	local prio

	for i = 1, 40 do
		local name, icon, count, debuffType, duration, expiration, _, _, _, spellId = UnitAura(unit, i, "HARMFUL")
		if not name then break end

		if rd.ShowDispellableDebuff and debuffType and filter == "HARMFUL" and (not isCharmed) and (not canAttack) then
			if rd.FilterDispellableDebuff then
				prio = DispellFilter[debuffType] and (DispellPriority[debuffType] + 6) or 2
				if prio == 2 then debuffType = nil end
			else
				prio = DispellPriority[debuffType]
			end

			if prio and prio > rd.priority then
				rd.priority, rd.index, rd.filter = prio, i, filter
				_name, _icon, _count, _debuffType, _duration, _expiration, _spellId = name, icon, count, debuffType, duration, expiration, spellId
			end
		end

		local instPrio
		if instName and debuffs[instName] then
			instPrio = debuffs[instName][spellId]
		end

		if not RaidDebuffsIgnore[spellId] and instPrio and (instPrio == 6 or instPrio > rd.priority) then
			rd.priority, rd.index, rd.filter = instPrio, i, filter
			_name, _icon, _count, _debuffType, _duration, _expiration, _spellId = name, icon, count, debuffType, duration, expiration, spellId
		end
	end

	if debugMode then
		rd.priority = 6
		_spellId = 47540
		_name, _, _icon = GetSpellInfo(_spellId)
		_count, _debuffType, _duration, _expiration = 2, "Magic", 10, GetTime()+10, 0
	end

	if rd.priority == invalidPrio then
		rd.index, _name = nil, nil
	end

	UpdateDebuffFrame(self, _name, _icon, _count, _debuffType, _duration, _expiration, _spellId)
end

local function Path(self, ...)
	return (self.RaidDebuffs.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self)
	local rd = self.RaidDebuffs
	if rd then
		self:RegisterEvent("UNIT_AURA", Path)
		rd.ForceUpdate = ForceUpdate
		rd.__owner = self
		return true
	end

	checkSpecs()
	self:RegisterEvent("PLAYER_TALENT_UPDATE", checkSpecs, true)
	checkInstance()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", checkInstance, true)
end

local function Disable(self)
	if self.RaidDebuffs then
		self:UnregisterEvent("UNIT_AURA", Path)
		self.RaidDebuffs:Hide()
		self.RaidDebuffs.__owner = nil
	end

	self:UnregisterEvent("PLAYER_TALENT_UPDATE", checkSpecs)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", checkInstance)
end

oUF:AddElement("RaidDebuffs", Update, Enable, Disable)