--[[
RSA_Detection.lua - SuperWoW Detection and Event Handling
Part of Rank14losSA addon
]]

local strfind = string.find
local strlower = string.lower
local GetTime = GetTime

-- Cooldown settings
local COOLDOWN_BUFF = 2.0
local COOLDOWN_DEBUFF = 1.0
local COOLDOWN_FADE = 3.0
local COOLDOWN_USE = 0.5

local MAX_BUFFS = 32
local MAX_DEBUFFS = 16

-- SuperWoW state
RSA_SW = {
	enabled = false,
	debugMode = false,
	inInstance = false,
	trackedDebuffs = {},
	lastAlerts = {},
	fadeWatchList = {},
	guids = {},
	enemyGuids = {},
	SCAN_INTERVAL = 0.5,
	lastCleanup = 0,
	CLEANUP_INTERVAL = 30,
}

--[[===========================================================================
	Tooltip Scanner
=============================================================================]]

local RSABuffScanner = CreateFrame("GameTooltip", "RSABuffScanner", nil, "GameTooltipTemplate")
RSABuffScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local function ScanBuffName(unit, buffIndex)
	RSABuffScanner:ClearLines()
	RSABuffScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	RSABuffScanner:SetUnitBuff(unit, buffIndex)
	local buffName = RSABuffScannerTextLeft1
	if buffName and buffName:IsVisible() then
		return buffName:GetText()
	end
	return nil
end

local function ScanDebuffName(unit, debuffIndex)
	RSABuffScanner:ClearLines()
	RSABuffScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	RSABuffScanner:SetUnitDebuff(unit, debuffIndex)
	local debuffName = RSABuffScannerTextLeft1
	if debuffName and debuffName:IsVisible() then
		return debuffName:GetText()
	end
	return nil
end

--[[===========================================================================
	Helper Functions
=============================================================================]]

local function IsEnemy(guid)
	if not UnitExists(guid) then return false end
	if not UnitIsPlayer(guid) then return false end
	local class = UnitClass(guid)
	if not class then return false end
	local classification = UnitClassification(guid)
	if classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite" then
		return false
	end
	return UnitCanAttack("player", guid)
end

local function IsFriendly(guid)
	if not UnitExists(guid) then return false end
	if not UnitIsPlayer(guid) then return false end
	local class = UnitClass(guid)
	if not class then return false end
	local classification = UnitClassification(guid)
	if classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite" then
		return false
	end
	return not UnitCanAttack("player", guid)
end

--[[===========================================================================
	Distance Check
=============================================================================]]

local UnitXP_GetDistance = nil
local distanceCheckAvailable = false

function InitializeDistanceCheck()
	if UnitXP_GetDistance then return true end
	if not UnitXP then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r UnitXP not found - Distance check DISABLED")
		return false
	end
	
	local success, result = pcall(function()
		return UnitXP("distanceBetween", "player", "player")
	end)
	
	if success and type(result) == "number" then
		UnitXP_GetDistance = function(unit1, unit2)
			return UnitXP("distanceBetween", unit1, unit2)
		end
		distanceCheckAvailable = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r UnitXP 'distanceBetween' detected - 50 yard range limit ACTIVE")
		return true
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r UnitXP 'distanceBetween' not available")
	return false
end

local function GetDistance(guid)
	if not distanceCheckAvailable then return nil end
	if not guid or not UnitExists(guid) then return nil end
	local success, distance = pcall(function()
		return UnitXP_GetDistance("player", guid)
	end)
	if success and distance then return distance end
	return nil
end

local function IsWithinRange(guid, maxYards)
	if not distanceCheckAvailable then return false end
	local distance = GetDistance(guid)
	if not distance then return false end
	return distance <= maxYards
end

local function CanAlert(guid, ability, alertType)
	if not IsWithinRange(guid, 50) then return false end
	if alertType == "cast" then return true end
	
	local now = GetTime()
	if not RSA_SW.lastAlerts[guid] then
		RSA_SW.lastAlerts[guid] = {}
	end
	
	local lastAlert = RSA_SW.lastAlerts[guid][ability]
	local cooldown = COOLDOWN_BUFF
	if alertType == "use" then cooldown = COOLDOWN_USE
	elseif alertType == "debuff" then cooldown = COOLDOWN_DEBUFF
	elseif alertType == "fade" then cooldown = COOLDOWN_FADE
	end
	
	if lastAlert and (now - lastAlert) < cooldown then return false end
	RSA_SW.lastAlerts[guid][ability] = now
	return true
end

--[[===========================================================================
	Memory Cleanup
=============================================================================]]

function RSA_SW:CleanupMemory()
	local now = GetTime()
	for guid, _ in pairs(self.fadeWatchList) do
		if not UnitExists(guid) then
			self.fadeWatchList[guid] = nil
		end
	end
	for guid, abilities in pairs(self.lastAlerts) do
		for ability, timestamp in pairs(abilities) do
			if now - timestamp > 60 then
				abilities[ability] = nil
			end
		end
		if not next(abilities) then
			self.lastAlerts[guid] = nil
		end
	end
	self.lastCleanup = now
end

--[[===========================================================================
	Instance Check
=============================================================================]]

function RSA_SW:UpdateInstanceStatus()
	local inInstance, instanceType = IsInInstance()
	local zone = GetZoneText()
	local isWinterVeilVale = (zone == "Winter Veil Vale")
	
	if inInstance and not isWinterVeilVale and (instanceType == "party" or instanceType == "raid") then
		if not self.inInstance then
			self.inInstance = true
			self.fadeWatchList = {}
			self.enemyGuids = {}
			self.guids = {}
			self.trackedDebuffs = {}
		end
	else
		if self.inInstance then
			self.inInstance = false
		end
	end
end

--[[===========================================================================
	Debuff Scanner
=============================================================================]]

function RSA_SW:ScanDebuffs(guid)
	if not UnitExists(guid) then
		self.trackedDebuffs[guid] = nil
		return
	end
	if not IsFriendly(guid) then return end
	
	local currentDebuffs = {}
	local playerName = UnitName(guid) or "Unknown"
	
	for i = 1, MAX_DEBUFFS do
		local debuffName = ScanDebuffName(guid, i)
		if debuffName then
			local nameLower = strlower(debuffName)
			local configKey = RSA_DEBUFF_NAMES[nameLower]
			if configKey then
				currentDebuffs[configKey] = true
				if not self.trackedDebuffs[guid] or not self.trackedDebuffs[guid][configKey] then
					if RSAConfig.debuffs.enabled and RSAConfig.debuffs[configKey] and CanAlert(guid, configKey, "debuff") then
						RSA_PlaySoundFile(configKey, playerName, guid)
					end
				end
			end
		end
	end
	self.trackedDebuffs[guid] = currentDebuffs
end

--[[===========================================================================
	Scanning Loop
=============================================================================]]

local scanFrame = CreateFrame("Frame")
local scanTimer = 0

scanFrame:SetScript("OnUpdate", function()
	if not RSA_SW.enabled then return end
	if not RSAConfig or not RSAConfig.enabled then return end
	if RSA_SW.inInstance then return end
	
	scanTimer = scanTimer + arg1
	if scanTimer < RSA_SW.SCAN_INTERVAL then return end
	scanTimer = 0
	
	local now = GetTime()
	if now - RSA_SW.lastCleanup > RSA_SW.CLEANUP_INTERVAL then
		RSA_SW:CleanupMemory()
	end
	
	-- Scan fade watch list
	for guid, buffList in pairs(RSA_SW.fadeWatchList) do
		if UnitExists(guid) then
			-- Get all current buffs on target
			local currentBuffs = {}
			for i = 1, 32 do
				local buffName = ScanBuffName(guid, i)
				if buffName then
					currentBuffs[strlower(buffName)] = true
				end
			end
			
			-- Check each watched buff
			for configKey, watchData in pairs(buffList) do
				local buffFound = false
				for buffNameLower, _ in pairs(currentBuffs) do
					if strfind(buffNameLower, watchData.pattern) then
						buffFound = true
						break
					end
				end
				if not buffFound then
					local fadeKey = configKey .. "_fade"
					if CanAlert(guid, fadeKey, "fade") then
						RSA_PlaySoundFile(configKey .. "down", watchData.playerName, guid)
					end
					buffList[configKey] = nil
				end
			end
			
			-- Clean up empty entries
			local hasBuffs = false
			for _, _ in pairs(buffList) do
				hasBuffs = true
				break
			end
			if not hasBuffs then
				RSA_SW.fadeWatchList[guid] = nil
			end
		else
			RSA_SW.fadeWatchList[guid] = nil
		end
	end
	
	-- Scan player debuffs
	if RSAConfig.debuffs and RSAConfig.debuffs.enabled then
		local _, playerGuid = UnitExists("player")
		if playerGuid then
			RSA_SW:ScanDebuffs(playerGuid)
		end
	end
end)

--[[===========================================================================
	Event Handler
=============================================================================]]

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_CASTEVENT")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

eventFrame:SetScript("OnEvent", function()
	if not RSA_SW.enabled then return end
	
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
		RSA_SW:UpdateInstanceStatus()
	elseif event == "UNIT_CASTEVENT" then
		RSA_SW:OnUnitCastEvent(arg1, arg2, arg3, arg4, arg5)
	end
end)

--[[===========================================================================
	UNIT_CASTEVENT Handler
=============================================================================]]

function RSA_SW:OnUnitCastEvent(casterGUID, targetGUID, eventType, spellID, castDuration)
	if not spellID or not casterGUID then return end
	
	-- Handle FAIL event
	if eventType == "FAIL" then
		if RSA_AlertFrame and RSA_AlertFrame:IsVisible() and RSA_AlertFrame.isCasting then
			if RSA_AlertFrame.trackingGUID == casterGUID then
				RSA_AlertFrame.isCasting = false
				RSA_AlertFrame.bar:SetWidth(0)
				RSA_AlertFrame.timerText:SetText("")
				
				-- Check if we have active buffs to show instead of hiding
				if RSA_AlertFrame.activeBuffs and next(RSA_AlertFrame.activeBuffs) ~= nil then
					RSA_ShowNextBuff()
				elseif RSA_MoveMode then
					-- Im Move-Mode: Zurück zum Platzhalter
					RSA_AlertFrame.text:SetText(">> DRAG TO MOVE <<")
					RSA_AlertFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					local textWidth = RSA_AlertFrame.text:GetStringWidth()
					local frameWidth = math.max(180, textWidth + 80)
					RSA_AlertFrame:SetWidth(frameWidth)
					RSA_AlertFrame.bar:SetWidth(frameWidth)
					RSA_AlertFrame.bar:SetVertexColor(0.5, 0.5, 0.5, RSA_AlertFrameBgAlpha or 0.7)
				else
					RSA_AlertFrame:Hide()
				end
			end
		end
		return
	end
	
	if eventType ~= "START" and eventType ~= "CAST" then return end
	if self.inInstance then return end
	if not UnitIsPlayer(casterGUID) then return end
	
	local class = UnitClass(casterGUID)
	if not class then return end
	
	local classification = UnitClassification(casterGUID)
	if classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite" then
		return
	end
	
	if not IsEnemy(casterGUID) then return end
	
	local casterName = UnitName(casterGUID) or "Unknown"
	
	-- Check item uses
	local useConfigKey = RSA_USE_SPELL_IDS[spellID]
	if useConfigKey then
		if RSAConfig.use and RSAConfig.use.enabled and RSAConfig.use[useConfigKey] and CanAlert(casterGUID, useConfigKey, "use") then
			RSA_PlaySoundFile(useConfigKey, casterName, casterGUID, nil, spellID)
		end
		return
	end
	
	-- Check casts
	local castConfigKey = RSA_CAST_SPELL_IDS[spellID]
	if castConfigKey then
		if eventType ~= "START" then return end
		local _, playerGuid = UnitExists("player")
		if targetGUID ~= playerGuid then return end
		
		if RSAConfig.casts.enabled and RSAConfig.casts[castConfigKey] then
			-- Für Casts: Immer anzeigen wenn in Range, kein Cooldown-Check
			if not distanceCheckAvailable or IsWithinRange(casterGUID, 50) then
				RSA_PlaySoundFile(castConfigKey, casterName, casterGUID, castDuration, spellID)
			end
		end
		return
	end
	
	-- Check buffs
	local buffConfigKey = RSA_BUFF_SPELL_IDS[spellID]
	if buffConfigKey then
		if RSAConfig.buffs.enabled and RSAConfig.buffs[buffConfigKey] and CanAlert(casterGUID, buffConfigKey, "buff") then
			RSA_PlaySoundFile(buffConfigKey, casterName, casterGUID, nil, spellID)
		end
		
		-- Add to fade watch list
		if RSAConfig.fadingBuffs and RSAConfig.fadingBuffs.enabled and RSAConfig.fadingBuffs[buffConfigKey] then
			if RSA_FADE_BUFF_PATTERNS[buffConfigKey] then
				if not self.fadeWatchList[casterGUID] then
					self.fadeWatchList[casterGUID] = {}
				end
				self.fadeWatchList[casterGUID][buffConfigKey] = {
					playerName = casterName,
					pattern = RSA_FADE_BUFF_PATTERNS[buffConfigKey],
				}
			end
		end
		return
	end
end

--[[===========================================================================
	SuperWoW Initialization
=============================================================================]]

function RSA_SW:Initialize()
	if not RSAConfig then return false end
	
	local hasSuperWoW = (GetPlayerBuffID ~= nil and CombatLogAdd ~= nil and SpellInfo ~= nil)
	
	if hasSuperWoW then
		self.enabled = true
		scanFrame:Show()
		eventFrame:Show()
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r SuperWoW detected - Enhanced mode active!")
		return true
	end
	return false
end

function RSA_SW:Enable()
	if self.enabled then
		scanFrame:Show()
		eventFrame:Show()
	end
end

function RSA_SW:Disable()
	if self.enabled then
		scanFrame:Hide()
		eventFrame:Hide()
	end
end
