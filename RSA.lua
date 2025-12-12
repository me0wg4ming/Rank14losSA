--[[
RSA (Rank 14 Sound Alerts) - SuperWoW Enhanced Version
Proactive ability detection using GUID scanning and UNIT_CASTEVENT
Falls back to Combat Log on vanilla clients
OPTIMIZED VERSION - Fixed memory leaks, performance, and detection issues
]]

local _G = getfenv(0)
local version = "0.5-SuperWoW-AlertFrame"

-- Performance: Cache global functions
local strfind = string.find
local strlower = string.lower
local strformat = string.format
local tinsert = table.insert
local tgetn = table.getn
local pairs = pairs
local GetTime = GetTime

-- SavedVariables for Alert Frame position (initialized in PLAYER_ENTERING_WORLD)
-- RSA_AlertFrameX, RSA_AlertFrameY, RSA_AlertFrameEnabled, RSA_AlertFrameBgAlpha are SavedVariables

-- Alert Frame reference
local RSA_AlertFrame = nil
local RSA_MoveMode = false

-- Constants
local MAX_BUFFS = 32
local MAX_DEBUFFS = 16
local RSA_BUFF = 54
local RSA_CAST = 67
local RSA_DEBUFF = 83
local RSA_FADING = 92
local RSA_MENU_TEXT = { "Enabled", "Enabled outside of Battlegrounds", "Show Alert Frame", "Move Alert Frame", }
local RSA_MENU_SETS = { "enabled", "outside", "alertFrame", "moveAlert", }
local RSA_MENU_WHITE = {}
RSA_MENU_WHITE[1] = true
local RSA_SOUND_OPTION_NOBUTTON = {}
RSA_SOUND_OPTION_NOBUTTON[RSA_BUFF] = true
RSA_SOUND_OPTION_NOBUTTON[RSA_CAST] = true
RSA_SOUND_OPTION_NOBUTTON[RSA_DEBUFF] = true
RSA_SOUND_OPTION_NOBUTTON[RSA_FADING] = true
local RSA_SOUND_OPTION_WHITE = {}
RSA_SOUND_OPTION_WHITE[1] = true
RSA_SOUND_OPTION_WHITE[RSA_BUFF + 1] = true
RSA_SOUND_OPTION_WHITE[RSA_CAST + 1] = true
RSA_SOUND_OPTION_WHITE[RSA_DEBUFF + 1] = true
RSA_SOUND_OPTION_WHITE[RSA_FADING + 1] = true
local RSA_SOUND_OPTION_TEXT = {
	"When an enemy recieves a buff:",
	"Adrenaline Rush",
	"Arcane Power",
	"Barkskin",
	"Battle Stance",
	"Berserker Rage",
	"Berserker Stance",
	"Bestial Wrath",
	"Blade Flurry",
	"Blessing of Freedom",
	"Blessing of Protection",
	"Cannibalize",
	"Cold Blood",
	"Combustion",
	"Dash",
	"Death Wish",
	"Defensive Stance",
	"Desperate Prayer",
	"Deterrence",
	"Divine Favor",
	"Divine Shield",
	"Earthbind Totem",
	"Elemental Mastery",
	"Evasion",
	"Evocation",
	"Fear Ward",
	"First Aid",
	"Frenzied Regeneration",
	"Freezing Trap",
	"Grounding Totem",
	"Ice Block",
	"Inner Focus",
	"Innervate",
	"Intimidation",
	"Last Stand",
	"Mana Tide Totem",
	"Nature's Grasp",
	"Nature's Swiftness",
	"Power Infusion",
	"Presence of Mind",
	"Rapid Fire",
	"Recklessness",
	"Reflector",
	"Retaliation",
	"Sacrifice",
	"Shield Wall",
	"Sprint",
	"Stone form",
	"Sweeping Strikes",
	"Tranquility",
	"Tremor Totem",
	"Trinket",
	"Will of the Forsaken",
	"",
	"When an enemy starts casting:",
	"Entangling Roots",
	"Escape Artist",
	"Fear",
	"Hearthstone",
	"Hibernate",
	"Howl of Terror",
	"Mind Control",
	"Polymorph",
	"Revive Pet",
	"Scare Beast",
	"War Stomp",
	"",
	"When a friendly player recieves a debuff:",
	"Blind",
	"Concussion Blow",
	"Counterspell - Silenced",
	"Death Coil",
	"Disarm",
	"Hammer of Justice",
	"Intimidating Shout",
	"Psychic Scream",
	"Repetance",
	"Scatter Shot",
	"Seduction",
	"Silence",
	"Spell Lock",
	"Wyvern Sting",
	"",
	"When a buff fades:",
	"Barkskin",
	"Blessing of Protection",
	"Deterrence",
	"Divine Shield",
	"Evasion",
	"Ice Block",
	"Shield Wall",
	"",
	"When an enemy uses an ability:",
	"Kick",
	"Flash Bomb",
}

--[[===========================================================================
	SuperWoW Detection System
=============================================================================]]

local RSA_SW = {
	enabled = false,
	debugMode = false,
	guids = {},
	enemyGuids = {},
	trackedBuffs = {},
	trackedDebuffs = {},
	lastAlerts = {},
	SCAN_INTERVAL = 0.5,
	lastCleanup = 0,
	CLEANUP_INTERVAL = 30,
}

-- Cooldown settings (only for buffs/debuffs/fades - NO cooldown for casts!)
local COOLDOWN_BUFF = 2.0
local COOLDOWN_DEBUFF = 1.0
local COOLDOWN_FADE = 3.0
local COOLDOWN_USE = 0.5

-- Spell ID mappings for UNIT_CASTEVENT
RSA_SW.CAST_SPELL_IDS = {
	[339] = "EntanglingRoots",
	[1062] = "EntanglingRoots",
	[5195] = "EntanglingRoots",
	[5196] = "EntanglingRoots",
	[9852] = "EntanglingRoots",
	[9853] = "EntanglingRoots",
	[20484] = "EscapeArtist",
	[5782] = "Fear",
	[6213] = "Fear",
	[6215] = "Fear",
	[8068] = "Hearthstone",
	[2637] = "Hibernate",
	[18657] = "Hibernate",
	[18658] = "Hibernate",
	[5484] = "HowlofTerror",
	[17928] = "HowlofTerror",
	[605] = "MindControl",
	[10911] = "MindControl",
	[10912] = "MindControl",
	[118] = "Polymorph",
	[12824] = "Polymorph",
	[12825] = "Polymorph",
	[12826] = "Polymorph",
	[982] = "RevivePet",
	[1513] = "ScareBeast",
	[14326] = "ScareBeast",
	[14327] = "ScareBeast",
	[20549] = "WarStomp",
}

-- Buff Spell IDs
RSA_SW.BUFF_SPELL_IDS = {
	[13750] = "AdrenalineRush",
	[12042] = "ArcanePower",
	[22812] = "Barkskin",
	[51401] = "Barkskin",  -- Barkskin (Feral) Rank 1 - Turtle WoW
	[51451] = "Barkskin",  -- Barkskin (Feral) Rank 2 - Turtle WoW
	[51452] = "Barkskin",  -- Barkskin (Feral) Rank 3 - Turtle WoW
	[2687] = "BattleStance",
	[18499] = "BerserkerRage",
	[2458] = "BerserkerStance",
	[19574] = "BestialWrath",
	[13877] = "BladeFlurry",
	[1044] = "BlessingofFreedom",
	[1022] = "BlessingofProtection",
	[5599] = "BlessingofProtection",
	[10278] = "BlessingofProtection",
	[20577] = "Cannibalize",
	[14177] = "ColdBlood",
	[11129] = "Combustion",
	[1850] = "Dash",
	[9821] = "Dash",
	[12292] = "DeathWish",
	[71] = "DefensiveStance",
	[19236] = "DesperatePrayer",
	[19238] = "DesperatePrayer",
	[19240] = "DesperatePrayer",
	[19241] = "DesperatePrayer",
	[19242] = "DesperatePrayer",
	[19243] = "DesperatePrayer",
	[19296] = "Deterrence",
	[20216] = "DivineFavor",
	[642] = "DivineShield",
	[2484] = "EarthbindTotem",
	[16166] = "ElementalMastery",
	[5277] = "Evasion",
	[26669] = "Evasion",
	[12051] = "Evocation",
	[6346] = "FearWard",
	[22842] = "FrenziedRegeneration",
	[22895] = "FrenziedRegeneration",
	[22896] = "FrenziedRegeneration",
	[1499] = "FreezingTrap",
	[8178] = "GroundingTotem",
	[45438] = "IceBlock",
	[14751] = "InnerFocus",
	[29166] = "Innervate",
	[19577] = "Intimidation",
	[12975] = "LastStand",
	[16190] = "ManaTideTotem",
	[16689] = "Nature'sGrasp",
	[16810] = "Nature'sGrasp",
	[16811] = "Nature'sGrasp",
	[16812] = "Nature'sGrasp",
	[16813] = "Nature'sGrasp",
	[17116] = "Nature'sGrasp",
	[16188] = "Nature'sSwiftness",
	[10060] = "PowerInfusion",
	[12043] = "PresenceofMind",
	[3045] = "RapidFire",
	[1719] = "Recklessness",
	[23920] = "Reflector",
	[20230] = "Retaliation",
	[7812] = "Sacrifice",
	[871] = "ShieldWall",
	[2983] = "Sprint",
	[8696] = "Sprint",
	[11305] = "Sprint",
	[20594] = "Stoneform",
	[12328] = "SweepingStrikes",
	[740] = "Tranquility",
	[8918] = "Tranquility",
	[9862] = "Tranquility",
	[9863] = "Tranquility",
	[8143] = "TremorTotem",
	[23505] = "Trinket",
	[52317] = "Trinket",  -- PvP Trinket - Turtle WoW
	[7744] = "WilloftheForsaken",
}

-- Item/Ability Use Spell IDs (Flash Bomb, Kick, etc.)
RSA_SW.USE_SPELL_IDS = {
	[5134] = "FlashBomb",
	[1766] = "Kick",
	[1767] = "Kick",
	[1768] = "Kick",
	[1769] = "Kick",
	[38768] = "Kick",
}

-- Buff name mappings (English only, optimized for direct lookup)
RSA_SW.BUFF_NAMES = {
	["adrenaline rush"] = "AdrenalineRush",
	["arcane power"] = "ArcanePower",
	["barkskin"] = "Barkskin",
	["barkskin (feral)"] = "Barkskin",  -- Turtle WoW custom
	["battle stance"] = "BattleStance",
	["berserker rage"] = "BerserkerRage",
	["berserker stance"] = "BerserkerStance",
	["bestial wrath"] = "BestialWrath",
	["blade flurry"] = "BladeFlurry",
	["blessing of freedom"] = "BlessingofFreedom",
	["blessing of protection"] = "BlessingofProtection",
	["cannibalize"] = "Cannibalize",
	["cold blood"] = "ColdBlood",
	["combustion"] = "Combustion",
	["dash"] = "Dash",
	["death wish"] = "DeathWish",
	["defensive stance"] = "DefensiveStance",
	["desperate prayer"] = "DesperatePrayer",
	["deterrence"] = "Deterrence",
	["divine favor"] = "DivineFavor",
	["divine shield"] = "DivineShield",
	["earthbind totem"] = "EarthbindTotem",
	["elemental mastery"] = "ElementalMastery",
	["evasion"] = "Evasion",
	["evocation"] = "Evocation",
	["fear ward"] = "FearWard",
	["first aid"] = "FirstAid",
	["frenzied regeneration"] = "FrenziedRegeneration",
	["freezing trap"] = "FreezingTrap",
	["grounding totem"] = "GroundingTotem",
	["ice block"] = "IceBlock",
	["inner focus"] = "InnerFocus",
	["innervate"] = "Innervate",
	["intimidation"] = "Intimidation",
	["last stand"] = "LastStand",
	["mana tide totem"] = "ManaTideTotem",
	["nature's grasp"] = "Nature'sGrasp",
	["nature's swiftness"] = "Nature'sSwiftness",
	["power infusion"] = "PowerInfusion",
	["presence of mind"] = "PresenceofMind",
	["rapid fire"] = "RapidFire",
	["recklessness"] = "Recklessness",
	["retaliation"] = "Retaliation",
	["sacrifice"] = "Sacrifice",
	["shield wall"] = "ShieldWall",
	["sprint"] = "Sprint",
	["stone form"] = "Stoneform",
	["stoneform"] = "Stoneform",
	["sweeping strikes"] = "SweepingStrikes",
	["tranquility"] = "Tranquility",
	["tremor totem"] = "TremorTotem",
	["will of the forsaken"] = "WilloftheForsaken",
	["immune"] = "Trinket",
	["reflector"] = "Reflector",
}

-- Debuff name mappings (English only)
RSA_SW.DEBUFF_NAMES = {
	["blind"] = "Blind",
	["concussion blow"] = "ConcussionBlow",
	["counterspell"] = "Counterspell-Silenced",
	["death coil"] = "DeathCoil",
	["disarm"] = "Disarm",
	["hammer of justice"] = "HammerofJustice",
	["intimidating shout"] = "IntimidatingShout",
	["psychic scream"] = "PsychicScream",
	["repentance"] = "Repetance",
	["scatter shot"] = "ScatterShot",
	["seduction"] = "Seduction",
	["silence"] = "Silence",
	["spell lock"] = "SpellLock",
	["wyvern sting"] = "WyvernSting",
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
	
	local buffName = _G["RSABuffScannerTextLeft1"]
	if buffName and buffName:IsVisible() then
		return buffName:GetText()
	end
	return nil
end

local function ScanDebuffName(unit, debuffIndex)
	RSABuffScanner:ClearLines()
	RSABuffScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	RSABuffScanner:SetUnitDebuff(unit, debuffIndex)
	
	local debuffName = _G["RSABuffScannerTextLeft1"]
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
	
	-- Check 1: Must be a player (not NPC/mob)
	if not UnitIsPlayer(guid) then
		if RSA_SW.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r IsEnemy rejected (not a player): " .. name)
		end
		return false
	end
	
	-- Check 2: Players ALWAYS have a class - NPCs don't (or it's nil)
	local class = UnitClass(guid)
	if not class then
		if RSA_SW.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r IsEnemy rejected (no class): " .. name)
		end
		return false
	end
	
	-- Check 3: Skip elite/boss/rare NPCs (they can sometimes pass UnitIsPlayer)
	local classification = UnitClassification(guid)
	if classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite" then
		if RSA_SW.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r IsEnemy rejected (NPC classification: " .. classification .. "): " .. name)
		end
		return false
	end
	
	-- Check 4: Must be attackable (enemy faction)
	return UnitCanAttack("player", guid)
end

local function IsFriendly(guid)
	if not UnitExists(guid) then return false end
	
	-- Check 1: Must be a player (not NPC/mob)
	if not UnitIsPlayer(guid) then
		if RSA_SW.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r IsFriendly rejected (not a player): " .. name)
		end
		return false
	end
	
	-- Check 2: Players ALWAYS have a class
	local class = UnitClass(guid)
	if not class then
		if RSA_SW.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r IsFriendly rejected (no class): " .. name)
		end
		return false
	end
	
	-- Check 3: Skip elite/boss/rare NPCs
	local classification = UnitClassification(guid)
	if classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite" then
		if RSA_SW.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r IsFriendly rejected (NPC classification): " .. name)
		end
		return false
	end
	
	-- Check 4: Must NOT be attackable (friendly)
	return not UnitCanAttack("player", guid)
end

-- No cooldown for casts and item uses, only for buffs/debuffs/fades
--[[===========================================================================
	Distance Check (50 yard limit using SuperWoW)
=============================================================================]]

-- Check if SuperWoW UnitXP distance function is available
local UnitXP_GetDistance = nil
local distanceCheckAvailable = false

local function InitializeDistanceCheck()
	if UnitXP_GetDistance then
		return true -- Already initialized
	end
	
	if not UnitXP then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r UnitXP not found - Distance check DISABLED")
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[RSA]|r Alerts will NOT trigger (no range detection available)")
		return false
	end
	
	-- Test if UnitXP supports "distanceBetween"
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
	
	DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r UnitXP 'distanceBetween' not available - Distance check DISABLED")
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[RSA]|r Alerts will NOT trigger (no range detection available)")
	return false
end

local function GetDistance(guid)
	if not distanceCheckAvailable then
		return nil
	end
	
	if not guid or not UnitExists(guid) then
		return nil
	end
	
	local success, distance = pcall(function()
		return UnitXP_GetDistance("player", guid)
	end)
	
	if success and distance then
		return distance
	end
	
	return nil
end

local function IsWithinRange(guid, maxYards)
	-- If distance check not available, return false (disable alerts)
	if not distanceCheckAvailable then
		return false
	end
	
	local distance = GetDistance(guid)
	
	if not distance then
		-- Can't get distance for this GUID, don't alert
		return false
	end
	
	return distance <= maxYards
end

local function CanAlert(guid, ability, alertType)
	-- DISTANCE CHECK: Only alert for targets within 50 yards
	if not IsWithinRange(guid, 50) then
		if RSA_SW.debugMode then
			local distance = GetDistance(guid)
			if distance then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffcc00[R14 DEBUG]|r Target too far: %.1f yards (>50)", distance))
			end
		end
		return false
	end
	
	-- NO cooldown for casts!
	if alertType == "cast" then
		return true
	end
	
	-- Reduced cooldown for item uses
	if alertType == "use" then
		local now = GetTime()
		if not RSA_SW.lastAlerts[guid] then
			RSA_SW.lastAlerts[guid] = {}
		end
		local lastAlert = RSA_SW.lastAlerts[guid][ability]
		if lastAlert and (now - lastAlert) < COOLDOWN_USE then
			return false
		end
		RSA_SW.lastAlerts[guid][ability] = now
		return true
	end
	
	local now = GetTime()
	
	if not RSA_SW.lastAlerts[guid] then
		RSA_SW.lastAlerts[guid] = {}
	end
	
	local lastAlert = RSA_SW.lastAlerts[guid][ability]
	
	-- Determine cooldown based on alert type
	local cooldown = COOLDOWN_BUFF
	if alertType == "debuff" then
		cooldown = COOLDOWN_DEBUFF
	elseif alertType == "fade" then
		cooldown = COOLDOWN_FADE
	end
	
	if lastAlert and (now - lastAlert) < cooldown then
		return false
	end
	
	RSA_SW.lastAlerts[guid][ability] = now
	return true
end

--[[===========================================================================
	Memory Cleanup
=============================================================================]]

function RSA_SW:CleanupMemory()
	local now = GetTime()
	
	-- Cleanup old GUIDs that no longer exist
	for guid, _ in pairs(self.guids) do
		if not UnitExists(guid) then
			self.guids[guid] = nil
			self.enemyGuids[guid] = nil
			self.trackedBuffs[guid] = nil
			self.trackedDebuffs[guid] = nil
			self.lastAlerts[guid] = nil
		end
	end
	
	self.lastCleanup = now
end

--[[===========================================================================
	GUID Collection
=============================================================================]]

function RSA_SW:AddUnit(unit)
	if not unit then return end
	
	local exists, guid = UnitExists(unit)
	if not exists or not guid then return end
	
	-- Check 1: Pet Filter (like Spy/ShaguScan)
	-- Pet = NOT UnitIsPlayer AND UnitPlayerControlled
	local isPlayer = UnitIsPlayer(guid)
	local isControlled = UnitPlayerControlled(guid)
	local isPet = not isPlayer and isControlled
	
	if isPet then
		if self.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r AddUnit skipped (pet): " .. name)
		end
		return
	end
	
	-- Check 2: Must be a player
	if not isPlayer then
		if self.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r AddUnit skipped (not a player): " .. name)
		end
		return
	end
	
	-- Check 3: Players ALWAYS have a class - NPCs don't
	local class = UnitClass(guid)
	if not class then
		if self.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r AddUnit skipped (no class): " .. name)
		end
		return
	end
	
	-- Check 4: Skip elite/boss/rare NPCs
	local classification = UnitClassification(guid)
	if classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite" then
		if self.debugMode then
			local name = UnitName(guid) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r AddUnit skipped (NPC classification: " .. classification .. "): " .. name)
		end
		return
	end
	
	-- Passed all checks - this is a real player
	self.guids[guid] = GetTime()
	
	if IsEnemy(guid) then
		self.enemyGuids[guid] = GetTime()
	end
end

--[[===========================================================================
	Buff Scanner
=============================================================================]]

function RSA_SW:ScanBuffs(guid)
	if not UnitExists(guid) then
		-- Cleanup on non-existent GUID
		self.trackedBuffs[guid] = nil
		self.lastAlerts[guid] = nil
		return
	end
	
	if not IsEnemy(guid) then return end
	
	local currentBuffs = {}
	local playerName = UnitName(guid) or "Unknown"
	
	for i = 1, MAX_BUFFS do
		local buffName = ScanBuffName(guid, i)
		if buffName then
			local nameLower = strlower(buffName)
			
			-- Optimized: Direct lookup instead of loop
			local configKey = RSA_SW.BUFF_NAMES[nameLower]
			if configKey then
				currentBuffs[configKey] = true
				
				local isAlreadyTracked = self.trackedBuffs[guid] and self.trackedBuffs[guid][configKey]
				
				if not isAlreadyTracked then
					if self.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[R14 DEBUG]|r NEW BUFF (Scanner): " .. playerName .. " -> " .. configKey)
					end
					
					if RSAConfig.buffs.enabled and RSAConfig.buffs[configKey] and CanAlert(guid, configKey, "buff") then
						if self.debugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 DEBUG]|r Playing sound: " .. configKey .. ".mp3")
						end
						RSA_PlaySoundFile(configKey, playerName, guid)
					elseif self.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r Sound disabled in config for: " .. configKey)
					end
				end
			end
		end
	end
	
	-- Check for faded buffs
	if self.trackedBuffs[guid] then
		for configKey, _ in pairs(self.trackedBuffs[guid]) do
			if not currentBuffs[configKey] then
				if self.debugMode then
					DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[R14 DEBUG]|r BUFF FADED: " .. playerName .. " -> " .. configKey)
				end
				
				if RSAConfig.fadingBuffs.enabled and RSAConfig.fadingBuffs[configKey] then
					local fadeKey = configKey .. "_fade"
					if CanAlert(guid, fadeKey, "fade") then
						if self.debugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 DEBUG]|r Playing sound: " .. configKey .. "down.mp3")
						end
						RSA_PlaySoundFile(configKey.."down", playerName, guid)
					elseif self.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r Fade sound on cooldown: " .. configKey)
					end
				elseif self.debugMode then
					DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r Fade sound disabled in config for: " .. configKey)
				end
			end
		end
	end
	
	self.trackedBuffs[guid] = currentBuffs
end

--[[===========================================================================
	Debuff Scanner
=============================================================================]]

function RSA_SW:ScanDebuffs(guid)
	if not UnitExists(guid) then
		-- Cleanup on non-existent GUID
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
			
			-- Optimized: Direct lookup instead of loop
			local configKey = RSA_SW.DEBUFF_NAMES[nameLower]
			if configKey then
				currentDebuffs[configKey] = true
				
				if not self.trackedDebuffs[guid] or not self.trackedDebuffs[guid][configKey] then
					if self.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[R14 DEBUG]|r NEW DEBUFF: " .. playerName .. " -> " .. configKey)
					end
					
					if RSAConfig.debuffs.enabled and RSAConfig.debuffs[configKey] and CanAlert(guid, configKey, "debuff") then
						if self.debugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 DEBUG]|r Playing sound: " .. configKey .. ".mp3")
						end
						RSA_PlaySoundFile(configKey, playerName, guid)
					elseif self.debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r Sound disabled in config for: " .. configKey)
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
	
	scanTimer = scanTimer + arg1
	if scanTimer < RSA_SW.SCAN_INTERVAL then return end
	scanTimer = 0
	
	-- Periodic memory cleanup
	local now = GetTime()
	if now - RSA_SW.lastCleanup > RSA_SW.CLEANUP_INTERVAL then
		RSA_SW:CleanupMemory()
	end
	
	-- Scan enemy buffs
	for guid, _ in pairs(RSA_SW.enemyGuids) do
		if UnitExists(guid) then
			RSA_SW:ScanBuffs(guid)
		else
			RSA_SW.enemyGuids[guid] = nil
			RSA_SW.trackedBuffs[guid] = nil
			RSA_SW.lastAlerts[guid] = nil
		end
	end
	
	-- Scan party debuffs
	for i = 1, 4 do
		local unit = "party"..i
		if UnitExists(unit) then
			local _, guid = UnitExists(unit)
			if guid then
				RSA_SW:AddUnit(unit)
				RSA_SW:ScanDebuffs(guid)
			end
		end
	end
	
	-- Scan raid debuffs
	for i = 1, 40 do
		local unit = "raid"..i
		if UnitExists(unit) then
			local _, guid = UnitExists(unit)
			if guid then
				RSA_SW:AddUnit(unit)
				RSA_SW:ScanDebuffs(guid)
			end
		end
	end
	
	-- Scan player debuffs
	local _, playerGuid = UnitExists("player")
	if playerGuid then
		RSA_SW:ScanDebuffs(playerGuid)
	end
end)

--[[===========================================================================
	GUID Collection Events
=============================================================================]]

local guidFrame = CreateFrame("Frame")
guidFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
guidFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
guidFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
guidFrame:RegisterEvent("UNIT_AURA")
guidFrame:RegisterEvent("UNIT_HEALTH")
guidFrame:RegisterEvent("UNIT_CASTEVENT")

guidFrame:SetScript("OnEvent", function()
	if not RSA_SW.enabled then return end
	
	if event == "UPDATE_MOUSEOVER_UNIT" then
		RSA_SW:AddUnit("mouseover")
	elseif event == "PLAYER_TARGET_CHANGED" then
		RSA_SW:AddUnit("target")
		RSA_SW:AddUnit("targettarget")
	elseif event == "PLAYER_ENTERING_WORLD" then
		RSA_SW:AddUnit("player")
		RSA_SW:AddUnit("target")
		RSA_SW:AddUnit("targettarget")
	elseif event == "UNIT_CASTEVENT" then
		RSA_SW:OnUnitCastEvent(arg1, arg2, arg3, arg4, arg5)
	else
		local unit = arg1
		if unit then
			RSA_SW:AddUnit(unit)
		end
	end
end)

--[[===========================================================================
	UNIT_CASTEVENT Handler
=============================================================================]]

function RSA_SW:OnUnitCastEvent(casterGUID, targetGUID, eventType, spellID, castDuration)
	-- Safety checks
	if not spellID or not casterGUID then return end
	if eventType ~= "START" and eventType ~= "CAST" then return end
	
	-- Check 1: Must be a player (not NPC/mob)
	if not UnitIsPlayer(casterGUID) then
		if self.debugMode then
			local name = UnitName(casterGUID) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r UNIT_CASTEVENT skipped (not a player): " .. name .. " SpellID: " .. spellID)
		end
		return
	end
	
	-- Check 2: Players ALWAYS have a class
	local class = UnitClass(casterGUID)
	if not class then
		if self.debugMode then
			local name = UnitName(casterGUID) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r UNIT_CASTEVENT skipped (no class): " .. name .. " SpellID: " .. spellID)
		end
		return
	end
	
	-- Check 3: Skip elite/boss/rare NPCs
	local classification = UnitClassification(casterGUID)
	if classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite" then
		if self.debugMode then
			local name = UnitName(casterGUID) or "Unknown"
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r UNIT_CASTEVENT skipped (NPC classification): " .. name .. " SpellID: " .. spellID)
		end
		return
	end
	
	-- Check 4: Must be enemy
	if not IsEnemy(casterGUID) then return end
	
	local casterName = UnitName(casterGUID) or "Unknown"
	
	-- FIRST: Check instant item uses (Flash Bomb, Kick, etc.) - Check this BEFORE casts!
	local useConfigKey = self.USE_SPELL_IDS[spellID]
	if useConfigKey then
		if self.debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[R14 DEBUG]|r ITEM USE: " .. casterName .. " -> " .. useConfigKey .. " (SpellID: " .. spellID .. ")")
		end
		
		if RSAConfig.use and RSAConfig.use.enabled and RSAConfig.use[useConfigKey] and CanAlert(casterGUID, useConfigKey, "use") then
			if self.debugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 DEBUG]|r Playing sound: " .. useConfigKey .. ".mp3")
			end
			RSA_PlaySoundFile(useConfigKey, casterName, casterGUID)
		elseif self.debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r Sound disabled in config for: " .. useConfigKey)
		end
		
		self:AddUnit(casterGUID)
		return
	end
	
	-- Check targeted casts (only alert if YOU are target)
	local castConfigKey = self.CAST_SPELL_IDS[spellID]
	if castConfigKey then
		local _, playerGuid = UnitExists("player")
		if targetGUID ~= playerGuid then return end
		
		if self.debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[R14 DEBUG]|r CAST START: " .. casterName .. " -> " .. castConfigKey .. " (on YOU)")
		end
		
		if RSAConfig.casts.enabled and RSAConfig.casts[castConfigKey] and CanAlert(casterGUID, castConfigKey, "cast") then
			if self.debugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 DEBUG]|r Playing sound: " .. castConfigKey .. ".mp3")
			end
			RSA_PlaySoundFile(castConfigKey, casterName, casterGUID)
		elseif self.debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r Sound disabled in config for: " .. castConfigKey)
		end
		
		self:AddUnit(casterGUID)
		return
	end
	
	-- Check instant buffs
	local buffConfigKey = self.BUFF_SPELL_IDS[spellID]
	if buffConfigKey then
		if self.debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[R14 DEBUG]|r INSTANT BUFF: " .. casterName .. " -> " .. buffConfigKey .. " (SpellID: " .. spellID .. ")")
		end
		
		if RSAConfig.buffs.enabled and RSAConfig.buffs[buffConfigKey] and CanAlert(casterGUID, buffConfigKey, "buff") then
			if self.debugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff[R14 DEBUG]|r Playing sound: " .. buffConfigKey .. ".mp3")
			end
			RSA_PlaySoundFile(buffConfigKey, casterName, casterGUID)
		elseif self.debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[R14 DEBUG]|r Sound disabled in config for: " .. buffConfigKey)
		end
		
		if not self.trackedBuffs[casterGUID] then
			self.trackedBuffs[casterGUID] = {}
		end
		self.trackedBuffs[casterGUID][buffConfigKey] = true
		
		if self.debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[R14 DEBUG]|r Buff tracked for fade detection: " .. buffConfigKey)
		end
		
		self:AddUnit(casterGUID)
		return
	end
	
	if self.debugMode and (eventType == "CAST" or eventType == "START") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[R14 DEBUG]|r Unknown Spell ID: " .. spellID .. " from " .. casterName)
	end
end

--[[===========================================================================
	SuperWoW Initialization
=============================================================================]]

function RSA_SW:Initialize()
	-- Safety check for config
	if not RSAConfig then return false end
	
	local hasSuperWoW = (GetPlayerBuffID ~= nil and CombatLogAdd ~= nil and SpellInfo ~= nil)
	
	if hasSuperWoW then
		self.enabled = true
		scanFrame:Show()
		guidFrame:Show()
		print("|cff00ff00[RSA]|r SuperWoW detected - Enhanced mode active!")
		return true
	else
		-- SuperWoW required - addon won't function without it
		return false
	end
end

function RSA_SW:Enable()
	if self.enabled then
		scanFrame:Show()
		guidFrame:Show()
	end
end

function RSA_SW:Disable()
	if self.enabled then
		scanFrame:Hide()
		guidFrame:Hide()
	end
end

--[[===========================================================================
	Core RSA Functions
=============================================================================]]

local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function RSA_SlashCmdHandler(msg)
	if msg and string.lower(msg) == "save" then
		-- Force position save message
		if RSA_AlertFrameX and RSA_AlertFrameY then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Position saved: X=" .. math.floor(RSA_AlertFrameX) .. ", Y=" .. math.floor(RSA_AlertFrameY))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r No position to save (use Move Alert Frame first)")
		end
		return
	end
	RSAMenuFrame_Toggle()
end

function RSA_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("PLAYER_LOGOUT")
end

function RSA_OnEvent(event)
	if event == "PLAYER_LOGOUT" then
		-- SavedVariables werden automatisch gespeichert
		-- Nichts extra nötig, aber Event muss registriert sein
		return
	end
	
	if event == "PLAYER_ENTERING_WORLD" then
		this:UnregisterEvent("PLAYER_ENTERING_WORLD")
		
		-- âœ… CHECK FOR SUPERWOW FIRST (before doing anything else)
		local hasSuperWoW = (GetPlayerBuffID ~= nil and CombatLogAdd ~= nil and SpellInfo ~= nil)
		
		if not hasSuperWoW then
			-- âœ… SUPERWOW NOT FOUND - DISABLE ADDON COMPLETELY
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000============================================|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA] CRITICAL ERROR: SuperWoW NOT DETECTED!|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00This addon REQUIRES SuperWoW to function.|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Without SuperWoW, ability detection will not work.|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Please install SuperWoW from:|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00https://github.com/balakethelock/SuperWoW|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000RSA addon has been DISABLED.|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Please reload UI after installing SuperWoW.|r")
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000============================================|r")
			
			-- âœ… Block slash command
			SLASH_RSA1 = "/rsa"
			SlashCmdList["RSA"] = function()
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r RSA is DISABLED - SuperWoW not detected!")
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Please install SuperWoW and reload UI.|r")
			end
			
			-- âœ… Block debug commands
			SLASH_RSASTATUS1 = "/rsastatus"
			SlashCmdList["RSASTATUS"] = function()
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r RSA is DISABLED - SuperWoW not detected!")
			end
			
			SLASH_R14DEBUG1 = "/r14debug"
			SlashCmdList["R14DEBUG"] = function()
				DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r RSA is DISABLED - SuperWoW not detected!")
			end
			
			-- âœ… Unregister ALL events to prevent any background processing
			RSAMenuFrame:UnregisterAllEvents()
			
			-- âœ… Hide frames
			if scanFrame then scanFrame:Hide() end
			if guidFrame then guidFrame:Hide() end
			
			-- âœ… Disable config
			if RSAConfig then
				RSAConfig.enabled = false
			end
			
			-- âœ… STOP HERE - don't continue with initialization
			return
		end
		
		-- âœ… SuperWoW found - continue with normal initialization
		if not RSAConfig or not RSAConfig.version or RSAConfig.version ~= version then
			RSAConfig = {
				["enabled"] = true,
				["outside"] = true,
				["version"] = version,
				["buffs"] = {
					["enabled"] = true,
					["AdrenalineRush"] = true,
					["ArcanePower"] = true,
					["Barkskin"] = true,
					["BattleStance"] = false,
					["BerserkerRage"] = true,
					["BerserkerStance"] = false,
					["BestialWrath"] = true,
					["BladeFlurry"] = true,
					["BlessingofFreedom"] = true,
					["BlessingofProtection"] = true,
					["Cannibalize"] = true,
					["ColdBlood"] = true,
					["Combustion"] = true,
					["Dash"] = true,
					["DeathWish"] = true,
					["DefensiveStance"] = false,
					["DesperatePrayer"] = true,
					["Deterrence"] = true,
					["DivineFavor"] = true,
					["DivineShield"] = true,
					["EarthbindTotem"] = true,
					["ElementalMastery"] = true,
					["Evasion"] = true,
					["Evocation"] = true,
					["FearWard"] = true,
					["FirstAid"] = true,
					["FrenziedRegeneration"] = true,
					["FreezingTrap"] = true,
					["GroundingTotem"] = true,
					["IceBlock"] = true,
					["InnerFocus"] = true,
					["Innervate"] = true,
					["Intimidation"] = true,
					["LastStand"] = true,
					["ManaTideTotem"] = true,
					["Nature'sGrasp"] = true,
					["Nature'sSwiftness"] = true,
					["PowerInfusion"] = true,
					["PresenceofMind"] = true,
					["RapidFire"] = true,
					["Recklessness"] = true,
					["Reflector"] = true,
					["Retaliation"] = true,
					["Sacrifice"] = true,
					["ShieldWall"] = true,
					["Sprint"] = true,
					["Stoneform"] = true,
					["SweepingStrikes"] = true,
					["Tranquility"] = true,
					["TremorTotem"] = true,
					["Trinket"] = true,
					["WilloftheForsaken"] = true,
				},
				["casts"] = {
					["enabled"] = true,
					["EntanglingRoots"] = true,
					["EscapeArtist"] = true,
					["Fear"] = true,
					["Hearthstone"] = true,
					["Hibernate"] = true,
					["HowlofTerror"] = true,
					["MindControl"] = true,
					["Polymorph"] = true,
					["RevivePet"] = true,
					["ScareBeast"] = true,
					["WarStomp"] = true,
				},
				["debuffs"] = {
					["enabled"] = true,
					["Blind"] = true,
					["ConcussionBlow"] = true,
					["Counterspell-Silenced"] = true,
					["DeathCoil"] = true,
					["Disarm"] = true,
					["HammerofJustice"] = true,
					["IntimidatingShout"] = true,
					["PsychicScream"] = true,
					["Repetance"] = true,
					["ScatterShot"] = true,
					["Seduction"] = true,
					["Silence"] = true,
					["SpellLock"] = true,
					["WyvernSting"] = true,
				},
				["fadingBuffs"] = {
					["enabled"] = true,
					["Barkskin"] = true,
					["BlessingofProtection"] = true,
					["Deterrence"] = true,
					["DivineShield"] = true,
					["Evasion"] = true,
					["IceBlock"] = true,
					["ShieldWall"] = true,
				},
				["use"] = {
					["enabled"] = true,
					["Kick"] = true,
					["FlashBomb"] = true,
				},
			}
		end
		
		RSA_SW:Initialize()
		
		-- Initialize distance check (requires SuperWoW UnitXP)
		InitializeDistanceCheck()
		
		-- Initialize Alert Frame SavedVariables defaults (only if not set)
		if RSA_AlertFrameEnabled == nil then
			RSA_AlertFrameEnabled = true
		end
		if RSA_AlertFrameBgAlpha == nil then
			RSA_AlertFrameBgAlpha = 0.7
		end
		-- RSA_AlertFrameX and RSA_AlertFrameY stay nil until user moves the frame
		
		-- Create Alert Frame
		RSA_CreateAlertFrame()
		
		if RSAConfig.enabled then
			if not RSAConfig.outside then
				this:RegisterEvent("ZONE_CHANGED_NEW_AREA")
				RSA_UpdateState()
			else
				RSA_Enable()
			end
		end
		
		SlashCmdList["RSA"] = RSA_SlashCmdHandler
		SLASH_RSA1 = "/rsa"
		
	elseif event == "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF" then
		if not RSA_SW.enabled then
			if strfind(arg1, "begins to cast") or strfind(arg1, "begins to perform") then
				RSA_FilterCasts(arg1)
			else
				RSA_FilterBuffs(arg1)
			end
		end
	elseif event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE" then
		if not RSA_SW.enabled then
			if strfind(arg1, "begins to cast") or strfind(arg1, "begins to perform") then
				RSA_FilterCasts(arg1)
			elseif strfind(arg1, "hits") or strfind(arg1, "crits") then
				RSA_FilterAttacks(arg1)
			end
		end
	elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS" then
		if not RSA_SW.enabled then
			RSA_FilterBuffs(arg1)
		end
	elseif event == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE" then
		if not RSA_SW.enabled then
			RSA_FilterDebuffs(arg1)
		end
	elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
		if not RSA_SW.enabled then
			RSA_FilterDebuffs(arg1)
		end
	elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then
		if not RSA_SW.enabled then
			RSA_FilterFadingBuffs(arg1)
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		RSA_UpdateState()
	end
end

function RSA_UpdateState()
	if GetRealZoneText() == "Alterac Valley" or GetRealZoneText() == "Arathi Basin" or GetRealZoneText() == "Warsong Gulch" then
		RSA_Enable()
	else
		RSA_Disable()
	end
end

function RSA_Disable()
	RSA_SW:Disable()
	
	RSAMenuFrame:UnregisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF")
	RSAMenuFrame:UnregisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
	RSAMenuFrame:UnregisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
	RSAMenuFrame:UnregisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE")
	RSAMenuFrame:UnregisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS")
	RSAMenuFrame:UnregisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
end

function RSA_Enable()
	RSA_SW:Enable()
end

--[[===========================================================================
	Alert Frame System
=============================================================================]]

function RSA_CreateAlertFrame()
	if RSA_AlertFrame then return end
	
	RSA_AlertFrame = CreateFrame("Frame", "RSAAlertFrame", UIParent)
	RSA_AlertFrame:SetWidth(400)
	RSA_AlertFrame:SetHeight(50)
	RSA_AlertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
	RSA_AlertFrame:SetMovable(true)
	RSA_AlertFrame:EnableMouse(false)  -- Only enable mouse in move mode
	RSA_AlertFrame:SetClampedToScreen(true)
	RSA_AlertFrame:RegisterForDrag("LeftButton")
	RSA_AlertFrame:SetFrameStrata("HIGH")
	
	-- Make frame click-through (huge insets = no hit area)
	RSA_AlertFrame:SetHitRectInsets(10000, 10000, 10000, 10000)
	
	-- Background (no border like Snowball addon)
	RSA_AlertFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = nil,
		tile = false,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	RSA_AlertFrame:SetBackdropColor(0, 0, 0, RSA_AlertFrameBgAlpha)
	
	-- Spell Icon
	RSA_AlertFrame.icon = RSA_AlertFrame:CreateTexture(nil, "ARTWORK")
	RSA_AlertFrame.icon:SetWidth(32)
	RSA_AlertFrame.icon:SetHeight(32)
	RSA_AlertFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	
	-- Alert Text
	RSA_AlertFrame.text = RSA_AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	RSA_AlertFrame.text:SetPoint("LEFT", RSA_AlertFrame.icon, "RIGHT", 8, 0)
	RSA_AlertFrame.text:SetText("")
	RSA_AlertFrame.text:SetTextColor(1, 0.8, 0)
	
	-- Drag scripts
	RSA_AlertFrame:SetScript("OnDragStart", function()
		if RSA_MoveMode then
			this:StartMoving()
		end
	end)
	
	RSA_AlertFrame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
		local x, y = this:GetCenter()
		local ux, uy = UIParent:GetCenter()
		RSA_AlertFrameX = x - ux
		RSA_AlertFrameY = y - uy
	end)
	
	RSA_AlertFrame:Hide()
	RSA_AlertFrame.fadeTime = 0
	
	-- Fade out animation
	RSA_AlertFrame:SetScript("OnUpdate", function()
		if not this:IsVisible() then return end
		
		this.fadeTime = this.fadeTime + arg1
		
		if this.fadeTime > 4 then
			local alpha = 1 - ((this.fadeTime - 4) / 1)
			if alpha <= 0 then
				this:Hide()
				this:SetAlpha(1)
			else
				this:SetAlpha(alpha)
			end
		else
			this:SetAlpha(1)
		end
	end)
	
	-- Restore position
	if RSA_AlertFrameX and RSA_AlertFrameY then
		RSA_AlertFrame:ClearAllPoints()
		RSA_AlertFrame:SetPoint("CENTER", UIParent, "CENTER", RSA_AlertFrameX, RSA_AlertFrameY)
	end
end

-- Spell Icon Paths (ConfigKey -> Icon)
local RSA_SPELL_ICONS = {
	-- Buffs
	["AdrenalineRush"] = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
	["ArcanePower"] = "Interface\\Icons\\Spell_Nature_Lightning",
	["Barkskin"] = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
	["BattleStance"] = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
	["BerserkerRage"] = "Interface\\Icons\\Spell_Nature_AncestralGuardian",
	["BerserkerStance"] = "Interface\\Icons\\Ability_Racial_Avatar",
	["BestialWrath"] = "Interface\\Icons\\Ability_Druid_FerociousBite",
	["BladeFlurry"] = "Interface\\Icons\\Ability_Warrior_Punishingblow",
	["BlessingofFreedom"] = "Interface\\Icons\\Spell_Holy_SealOfValor",
	["BlessingofProtection"] = "Interface\\Icons\\Spell_Holy_SealOfProtection",
	["Cannibalize"] = "Interface\\Icons\\Ability_Racial_Cannibalize",
	["ColdBlood"] = "Interface\\Icons\\Spell_Ice_Lament",
	["Combustion"] = "Interface\\Icons\\Spell_Fire_SealOfFire",
	["Dash"] = "Interface\\Icons\\Ability_Druid_Dash",
	["DeathWish"] = "Interface\\Icons\\Spell_Shadow_DeathPact",
	["DefensiveStance"] = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
	["DesperatePrayer"] = "Interface\\Icons\\Spell_Holy_Restoration",
	["Deterrence"] = "Interface\\Icons\\Ability_Whirlwind",
	["DivineFavor"] = "Interface\\Icons\\Spell_Holy_Heal",
	["DivineShield"] = "Interface\\Icons\\Spell_Holy_DivineIntervention",
	["EarthbindTotem"] = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
	["ElementalMastery"] = "Interface\\Icons\\Spell_Nature_WispHeal",
	["Evasion"] = "Interface\\Icons\\Spell_Shadow_ShadowWard",
	["Evocation"] = "Interface\\Icons\\Spell_Nature_Purge",
	["FearWard"] = "Interface\\Icons\\Spell_Holy_Excorcism",
	["FirstAid"] = "Interface\\Icons\\Spell_Holy_Heal",
	["FrenziedRegeneration"] = "Interface\\Icons\\Ability_BullRush",
	["FreezingTrap"] = "Interface\\Icons\\Spell_Frost_ChainsOfIce",
	["GroundingTotem"] = "Interface\\Icons\\Spell_Nature_GroundingTotem",
	["IceBlock"] = "Interface\\Icons\\Spell_Frost_Frost",
	["InnerFocus"] = "Interface\\Icons\\Spell_Frost_WindWalkOn",
	["Innervate"] = "Interface\\Icons\\Spell_Nature_Lightning",
	["Intimidation"] = "Interface\\Icons\\Ability_Devour",
	["LastStand"] = "Interface\\Icons\\Spell_Holy_AshesToAshes",
	["ManaTideTotem"] = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
	["Nature'sGrasp"] = "Interface\\Icons\\Spell_Nature_NaturesWrath",
	["Nature'sSwiftness"] = "Interface\\Icons\\Spell_Nature_RavenForm",
	["PowerInfusion"] = "Interface\\Icons\\Spell_Holy_PowerInfusion",
	["PresenceofMind"] = "Interface\\Icons\\Spell_Nature_EnchantArmor",
	["RapidFire"] = "Interface\\Icons\\Ability_Hunter_RunningShot",
	["Recklessness"] = "Interface\\Icons\\Ability_CriticalStrike",
	["Reflector"] = "Interface\\Icons\\Spell_Frost_FrostWard",
	["Retaliation"] = "Interface\\Icons\\Ability_Warrior_Challange",
	["Sacrifice"] = "Interface\\Icons\\Spell_Shadow_SacrificialShield",
	["ShieldWall"] = "Interface\\Icons\\Ability_Warrior_ShieldWall",
	["Sprint"] = "Interface\\Icons\\Ability_Rogue_Sprint",
	["Stoneform"] = "Interface\\Icons\\Spell_Shadow_UnholyStrength",
	["SweepingStrikes"] = "Interface\\Icons\\Ability_Rogue_SliceDice",
	["Tranquility"] = "Interface\\Icons\\Spell_Nature_Tranquility",
	["TremorTotem"] = "Interface\\Icons\\Spell_Nature_TremorTotem",
	["Trinket"] = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02",
	["WilloftheForsaken"] = "Interface\\Icons\\Spell_Shadow_RaiseDead",
	-- Casts
	["EntanglingRoots"] = "Interface\\Icons\\Spell_Nature_StrangleVines",
	["EscapeArtist"] = "Interface\\Icons\\Ability_Rogue_Trip",
	["Fear"] = "Interface\\Icons\\Spell_Shadow_Possession",
	["Hearthstone"] = "Interface\\Icons\\INV_Misc_Rune_01",
	["Hibernate"] = "Interface\\Icons\\Spell_Nature_Sleep",
	["HowlofTerror"] = "Interface\\Icons\\Spell_Shadow_DeathScream",
	["MindControl"] = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
	["Polymorph"] = "Interface\\Icons\\Spell_Nature_Polymorph",
	["RevivePet"] = "Interface\\Icons\\Ability_Hunter_BeastSoothe",
	["ScareBeast"] = "Interface\\Icons\\Ability_Druid_Cower",
	["WarStomp"] = "Interface\\Icons\\Ability_WarStomp",
	-- Debuffs
	["Blind"] = "Interface\\Icons\\Spell_Shadow_MindSteal",
	["ConcussionBlow"] = "Interface\\Icons\\Ability_ThunderBolt",
	["Counterspell-Silenced"] = "Interface\\Icons\\Spell_Frost_IceShock",
	["DeathCoil"] = "Interface\\Icons\\Spell_Shadow_DeathCoil",
	["Disarm"] = "Interface\\Icons\\Ability_Warrior_Disarm",
	["HammerofJustice"] = "Interface\\Icons\\Spell_Holy_SealOfMight",
	["IntimidatingShout"] = "Interface\\Icons\\Ability_GolemThunderClap",
	["PsychicScream"] = "Interface\\Icons\\Spell_Shadow_PsychicScream",
	["Repetance"] = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
	["ScatterShot"] = "Interface\\Icons\\Ability_GolemStormBolt",
	["Seduction"] = "Interface\\Icons\\Spell_Shadow_MindSteal",
	["Silence"] = "Interface\\Icons\\Spell_Shadow_ImpPhaseShift",
	["SpellLock"] = "Interface\\Icons\\Spell_Shadow_MindRot",
	["WyvernSting"] = "Interface\\Icons\\INV_Spear_02",
	-- Use
	["Kick"] = "Interface\\Icons\\Ability_Kick",
	["FlashBomb"] = "Interface\\Icons\\INV_Misc_Bomb_08",
}

function RSA_ShowAlert(spellName, playerName, casterGUID)
	if not RSA_AlertFrame then return end
	if not RSA_AlertFrameEnabled then return end
	if RSA_MoveMode then return end  -- Don't show alerts in move mode
	
	-- Check if this caster is our current target
	local isTarget = false
	if casterGUID then
		local targetExists, targetGUID = UnitExists("target")
		if targetExists and targetGUID == casterGUID then
			isTarget = true
		end
	end
	
	-- Target priority: Only allow non-target alerts to override if current alert is also non-target
	-- or if the current alert has been showing for at least 1 second
	if RSA_AlertFrame:IsVisible() and not isTarget then
		if RSA_AlertFrame.isTargetAlert and RSA_AlertFrame.fadeTime < 1 then
			-- Current alert is from target and still fresh, don't override
			return
		end
	end
	
	-- Format spell name for display
	local displayName = spellName
	-- Check for "down" suffix (fading buffs)
	local isFade = false
	if string.sub(displayName, -4) == "down" then
		displayName = string.sub(displayName, 1, -5)
		isFade = true
	end
	
	-- Set spell icon
	local iconPath = RSA_SPELL_ICONS[displayName] or "Interface\\Icons\\INV_Misc_QuestionMark"
	RSA_AlertFrame.icon:SetTexture(iconPath)
	
	-- Build alert text: "Name casts Spell" or "Name's Spell fades"
	local alertText
	if isFade then
		if playerName and playerName ~= "" and playerName ~= "Unknown" then
			alertText = playerName .. "'s " .. displayName .. " fades"
		else
			alertText = displayName .. " fades"
		end
	elseif playerName and playerName ~= "" and playerName ~= "Unknown" then
		alertText = playerName .. " casts " .. displayName
	else
		alertText = displayName
	end
	
	RSA_AlertFrame.text:SetText(alertText)
	
	-- Center icon + text in frame
	local textWidth = RSA_AlertFrame.text:GetStringWidth()
	local totalWidth = 32 + 8 + textWidth  -- icon + spacing + text
	local offsetX = -totalWidth / 2 + 16  -- center point, +16 to account for icon center
	
	RSA_AlertFrame.icon:ClearAllPoints()
	RSA_AlertFrame.icon:SetPoint("CENTER", RSA_AlertFrame, "CENTER", offsetX, 0)
	
	RSA_AlertFrame:SetAlpha(1)
	RSA_AlertFrame:Show()
	RSA_AlertFrame.fadeTime = 0
	RSA_AlertFrame.isTargetAlert = isTarget
end

function RSA_ToggleMoveMode()
	RSA_MoveMode = not RSA_MoveMode
	
	if RSA_MoveMode then
		if not RSA_AlertFrame then
			RSA_CreateAlertFrame()
		end
		RSA_AlertFrame:EnableMouse(true)
		RSA_AlertFrame:SetHitRectInsets(0, 0, 0, 0)  -- Enable clicking
		
		-- Set move mode text and center it with icon
		local moveText = ">> DRAG TO MOVE <<"
		RSA_AlertFrame.text:SetText(moveText)
		RSA_AlertFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		
		-- Center icon + text
		local textWidth = RSA_AlertFrame.text:GetStringWidth()
		local totalWidth = 32 + 8 + textWidth
		local offsetX = -totalWidth / 2 + 16
		RSA_AlertFrame.icon:ClearAllPoints()
		RSA_AlertFrame.icon:SetPoint("CENTER", RSA_AlertFrame, "CENTER", offsetX, 0)
		
		RSA_AlertFrame:SetAlpha(1)
		RSA_AlertFrame:Show()
		RSA_AlertFrame:SetScript("OnUpdate", nil)  -- Disable fade while moving
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Alert Frame move mode |cff00ff00ENABLED|r - Drag to reposition")
	else
		RSA_AlertFrame:EnableMouse(false)
		RSA_AlertFrame:SetHitRectInsets(10000, 10000, 10000, 10000)  -- Disable clicking (click-through)
		RSA_AlertFrame:Hide()
		-- Re-enable fade script
		RSA_AlertFrame:SetScript("OnUpdate", function()
			if not this:IsVisible() then return end
			this.fadeTime = this.fadeTime + arg1
			if this.fadeTime > 4 then
				local alpha = 1 - ((this.fadeTime - 4) / 1)
				if alpha <= 0 then
					this:Hide()
					this:SetAlpha(1)
				else
					this:SetAlpha(alpha)
				end
			else
				this:SetAlpha(1)
			end
		end)
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Alert Frame move mode |cffff0000DISABLED|r - Position saved")
	end
end

function RSA_PlaySoundFile(spell, playerName, casterGUID)
	-- Show visual alert with player name and GUID for target priority
	RSA_ShowAlert(spell, playerName, casterGUID)
	
	local mp3Path = "Interface\\AddOns\\Rank14losSA\\Voice\\"..spell..".mp3"
	local success = PlaySoundFile(mp3Path, "Master")
	
	if not success and RSA_SW.debugMode then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RSA]|r Sound file not found: " .. mp3Path)
	end
end

function RSA_Subtable(index)
	if index < RSA_BUFF then
		return "buffs"
	elseif index < RSA_CAST then
		return "casts"
	elseif index < RSA_DEBUFF then
		return "debuffs"
	elseif index < RSA_FADING then
		return "fadingBuffs"
	else
		return "use"
	end
end

function RSA_SoundText(index)
	if RSA_SOUND_OPTION_WHITE[index] then
		return "enabled" 
	else
		return string.gsub(RSA_SOUND_OPTION_TEXT[index], " ", "")
	end
end

function RSACheckButton_OnClick()
	if this.variable then
		if this:GetChecked() then
			RSAConfig[this.variable] = true
		else
			RSAConfig[this.variable] = false
		end
		if this.index == 1 then
			RSAMenuFrame_UpdateDependencies()
			if RSAConfig.outside and this:GetChecked() then
				RSA_Enable()
			else
				RSA_Disable()
			end
		elseif this.index == 2 then
			if this:GetChecked() then
				RSAMenuFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
				RSA_Enable()
			else
				RSAMenuFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
				RSA_UpdateState()
			end
		elseif this.index == 3 then
			-- Show Alert Frame toggle
			RSA_AlertFrameEnabled = this:GetChecked()
			if RSA_AlertFrameEnabled then
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Alert Frame |cff00ff00ENABLED|r")
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RSA]|r Alert Frame |cffff0000DISABLED|r")
			end
		elseif this.index == 4 then
			-- Move Alert Frame toggle
			RSA_ToggleMoveMode()
			-- Uncheck after toggle (it's a momentary action)
			this:SetChecked(RSA_MoveMode)
		end
	else
		if this:GetChecked() then
			RSAConfig[RSA_Subtable(this.index)][RSA_SoundText(this.index)] = true
		else
			RSAConfig[RSA_Subtable(this.index)][RSA_SoundText(this.index)] = false
		end
		if RSA_SOUND_OPTION_WHITE[this.index] then
			RSASoundOptionFrame_Update()
		end
	end
end

function RSAMenuFrame_Toggle()
	if RSAMenuFrame:IsVisible() then
		RSAMenuFrame:Hide()
	else
		RSAMenuFrame:Show()
	end
end

function RSAMenuFrame_Update()
	local button, fontString
	for i=1,4 do
		fontString = _G["RSAMenuFrameButton"..i.."Text"]
		fontString:SetText(RSA_MENU_TEXT[i])
		button = _G["RSAMenuFrameButton"..i]
		button.variable = RSA_MENU_SETS[i]
		button.index = i
		
		-- Set checked state based on variable
		if i == 1 or i == 2 then
			button:SetChecked(RSAConfig[button.variable])
		elseif i == 3 then
			button:SetChecked(RSA_AlertFrameEnabled)
		elseif i == 4 then
			button:SetChecked(RSA_MoveMode)
		end
		
		if RSA_MENU_WHITE[i] then
			fontString:SetTextColor(1,1,1)
		end
	end
	
	-- Create Background Alpha Slider (only once)
	if not RSAMenuFrame.alphaSlider then
		local slider = CreateFrame("Slider", "RSAAlphaSlider", RSAMenuFrame, "OptionsSliderTemplate")
		slider:SetWidth(180)
		slider:SetHeight(16)
		slider:SetPoint("TOPLEFT", RSAMenuFrameButton4, "BOTTOMLEFT", 0, -15)
		slider:SetMinMaxValues(0, 100)
		slider:SetValueStep(1)
		
		-- Convert stored alpha (0-0.7) to display value (0-100)
		-- 0.7 alpha = 100%, 0 alpha = 0%
		local displayValue = (RSA_AlertFrameBgAlpha / 0.7) * 100
		slider:SetValue(displayValue)
		
		_G[slider:GetName().."Low"]:SetText("0%")
		_G[slider:GetName().."High"]:SetText("100%")
		_G[slider:GetName().."Text"]:SetText("Background: " .. math.floor(displayValue) .. "%")
		
		slider:SetScript("OnValueChanged", function()
			local displayVal = this:GetValue()
			-- Convert display (0-100) to alpha (0-0.7)
			RSA_AlertFrameBgAlpha = (displayVal / 100) * 0.7
			
			-- Update label
			_G[this:GetName().."Text"]:SetText("Background: " .. math.floor(displayVal) .. "%")
			
			if RSA_AlertFrame then
				RSA_AlertFrame:SetBackdropColor(0, 0, 0, RSA_AlertFrameBgAlpha)
			end
		end)
		
		RSAMenuFrame.alphaSlider = slider
	else
		-- Convert stored alpha to display value
		local displayValue = (RSA_AlertFrameBgAlpha / 0.7) * 100
		RSAMenuFrame.alphaSlider:SetValue(displayValue)
		_G[RSAMenuFrame.alphaSlider:GetName().."Text"]:SetText("Background: " .. math.floor(displayValue) .. "%")
	end
	
	RSAMenuFrame_UpdateDependencies()
end

function RSAMenuFrame_UpdateDependencies()
	if RSAConfig.enabled then
		OptionsFrame_EnableCheckBox(RSAMenuFrameButton2)
	else
		OptionsFrame_DisableCheckBox(RSAMenuFrameButton2)
	end
end

function RSASoundOptionFrame_Toggle()
	if RSASoundOptionFrame:IsVisible() then
		RSASoundOptionFrame:Hide()
	else
		RSASoundOptionFrame:Show()
	end
end

function RSASoundOptionFrame_Update()
	local button, fontString
	local offset = FauxScrollFrame_GetOffset(RSASoundOptionFrameScrollFrame)
	for i=1,17 do
		local index = offset + i
		fontString = _G["RSASoundOptionFrameButton"..i.."Text"]
		fontString:SetText(RSA_SOUND_OPTION_TEXT[index])
		
		button = _G["RSASoundOptionFrameButton"..i]
		button.index = index
		
		if RSA_SOUND_OPTION_NOBUTTON[index] then
			button:Hide()
		else
			button:Show()
			button:SetChecked(RSAConfig[RSA_Subtable(index)][RSA_SoundText(index)])
		end
		
		if RSA_SOUND_OPTION_WHITE[index] then
			OptionsFrame_EnableCheckBox(button)
			fontString:SetTextColor(1,1,1)
		else
			if RSAConfig[RSA_Subtable(index)]["enabled"] then
				OptionsFrame_EnableCheckBox(button)
			else
				OptionsFrame_DisableCheckBox(button)
			end
		end
	end
	
	FauxScrollFrame_Update(RSASoundOptionFrameScrollFrame, tgetn(RSA_SOUND_OPTION_TEXT), 17, 16)
end

--[[===========================================================================
	Debug Commands
=============================================================================]]

SLASH_RSASTATUS1 = "/rsastatus"
SlashCmdList["RSASTATUS"] = function()
	print("|cff00ff00========== RSA Status ==========|r")
	
	local hasSuperWoW = (GetPlayerBuffID ~= nil and CombatLogAdd ~= nil and SpellInfo ~= nil)
	if hasSuperWoW then
		print("|cff00ff00SuperWoW:|r |cff00ff00AVAILABLE|r")
		print("|cff00ff00Scanner:|r " .. (RSA_SW.enabled and "|cff00ff00ACTIVE|r" or "|cffff0000INACTIVE|r"))
	else
		print("|cff00ff00SuperWoW:|r |cffff0000NOT AVAILABLE|r")
		print("|cffffcc00Using Combat Log fallback|r")
	end
	
	if RSA_SW.enabled then
		local guidCount = 0
		for _ in pairs(RSA_SW.guids) do guidCount = guidCount + 1 end
		local enemyCount = 0
		for _ in pairs(RSA_SW.enemyGuids) do enemyCount = enemyCount + 1 end
		
		print("|cff00ff00Tracked GUIDs:|r " .. guidCount)
		print("|cff00ff00  Enemies:|r " .. enemyCount)
	end
	
	print("|cff00ff00RSA Enabled:|r " .. tostring(RSAConfig.enabled))
	print("|cff00ff00Outside BGs:|r " .. tostring(RSAConfig.outside))
	print("|cff00ff00Buffs:|r " .. tostring(RSAConfig.buffs.enabled))
	print("|cff00ff00Casts:|r " .. tostring(RSAConfig.casts.enabled))
	print("|cff00ff00Debuffs:|r " .. tostring(RSAConfig.debuffs.enabled))
	print("|cff00ff00Fading:|r " .. tostring(RSAConfig.fadingBuffs.enabled))
	print("|cff00ff00Use:|r " .. tostring(RSAConfig.use and RSAConfig.use.enabled or false))
	
	print("|cff00ff00Debug Mode:|r " .. (RSA_SW.debugMode and "|cffff00ffENABLED|r" or "|cffaaaaa DISABLED|r"))
	
	print("|cff00ff00================================|r")
end

SLASH_R14DEBUG1 = "/r14debug"
SlashCmdList["R14DEBUG"] = function()
	RSA_SW.debugMode = not RSA_SW.debugMode
	
	if RSA_SW.debugMode then
		print("|cffff00ff[R14 Debug]|r Debug mode |cff00ff00ENABLED|r")
		print("|cffffcc00All buff/debuff/cast/use detections will be logged to chat|r")
	else
		print("|cffff00ff[R14 Debug]|r Debug mode |cffff0000 DISABLED|r")
	end
end