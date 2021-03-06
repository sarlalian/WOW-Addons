-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "DEATHKNIGHT" then return end

-- mod name in lower case
local modName = "Frost"
local version = 1

--================== Initialize Variables =====================
local Spell1 = nil
local Spell2 = nil
local Spell3 = nil

-- create a module in the main addon
local mod = WA:RegisterClassModule(modName)
local db

-- any error sets this to false
local enabled = true

-- spells used
local spellHB 	= GetSpellInfo(49184)	-- howling blast
local spellPS 	= GetSpellInfo(45462)	-- plague strike
local spellOB 	= GetSpellInfo(67725)	-- obliterate
local spellBS 	= GetSpellInfo(61696)	-- blood strike
local spellFS 	= GetSpellInfo(49143)	-- frost strike
local spellHoW 	= GetSpellInfo(57330)	-- horn of winter
local spellDC	= GetSpellInfo(47541) 	-- death coil
local spellDnD	= GetSpellInfo(43265) 	-- death and decay
local spellFP 	= GetSpellInfo(48266) 	-- frost presence

-- buffs
local buffKM	= GetSpellInfo(51124)	-- killing machine
local buffRM	= GetSpellInfo(59052) 	-- freezing fog (rime proc)

-- debuffs
local debuffFF	= GetSpellInfo(59921)	-- frost fever
local debuffBP	= GetSpellInfo(59879)	-- blood plague

-- this function, if it exists, will be called at init
function mod.OnInitialize()
	db = WA:RegisterClassModuleDB(modName, defaults)
end


--================== Initialize Spec Variables =====================
local StartTime					= GetTime()
local BloodTapFinish 			= StartTime
local HornOfWinterFinish 		= StartTime
local DeathAndDecayFinish		= StartTime
local FrostStrikeCost			= 40

local ApplyFrostFever			= false
local ApplyBloodPlague			= false

local BuffKillingMachine		= GetSpellInfo(51124)	-- killing machine
local BuffRime					= GetSpellInfo(59052) 	-- freezing fog (rime proc)

-- debuffs
local spellDC					= GetSpellInfo(47541)	-- death coil

--------------------------------------------------------------------------------
-- priority based system
-- only suggesting first skill atm
--------------------------------------------------------------------------------
-- Diseases
-- Ob if both Frost/Unholy pairs and/or both Death runes are up, or if KM is procced
-- BS if both Blood Runes are up
-- FS if RP capped
-- Rime
-- Ob
-- BS
-- HoW
--------------------------------------------------------------------------------

local readyRunes = { 0, 0, 0, 0 }

function mod.rotation(StartTime, GCDTimeLeft)
	if (enabled) then
		RunicPower = UnitPower("player")	
		Health = UnitHealth("player")
		HealthMax = UnitHealthMax("player")
		HealthPercent = (Health / HealthMax) * 100

		BloodTapCD, BloodTapFinish					= WA:GetActualSpellCD(BloodTapFinish, "Blood Tap")
		HornOfWinterCD, HornOfWinterFinish 			= WA:GetActualSpellCD(HornOfWinterFinish, "Horn of Winter")
		DeathAndDecayCD, DeathAndDecayFinish		= WA:GetActualSpellCD(DeathAndDecayFinish, "Death and Decay")
		
		-- get rune status
		-- runeMapping: 1 - blood, 2 - unholy, 3 - frost, 4 - death
		for i = 1, 4 do readyRunes[i] = 0 end
	
		for i = 1, 6 do
			cdStart, cdDuration, cdReady = GetRuneCooldown(i)
			cd = 0
			if not cdReady then
				cd = cdStart + cdDuration - StartTime - GCDTimeLeft
			end
			if cd < 0 then cd = 0 end
			runeType = GetRuneType(i)
			if cd == 0 then readyRunes[runeType] = readyRunes[runeType] + 1 end
		end
		-- unholy frost pairs
		local readyUF = min(readyRunes[2], readyRunes[3])

		-- ============================ Outbreak ============================
		-- Outputs:
		-- OutbreakCD
		--------------------------------------
		OutbreakStart, OutbreakDuration, _ = GetSpellCooldown("Outbreak")
		OutbreakCD = OutbreakStart + OutbreakDuration - GetTime()
		if (OutbreakCD < 0) then
			OutbreakCD = 0
		end
				
		-- bp
		local _, _, _, _, _, BloodPlagueDuration, BloodPlagueExpires = UnitDebuff("target", "Blood Plague", nil, "PLAYER")
		local BloodPlagueLeft = 0
		if BloodPlagueDuration and BloodPlagueDuration > 0 then
			BloodPlagueLeft = BloodPlagueExpires - StartTime
		end
		if BloodPlagueLeft <= 0 then
			ApplyBloodPlague = true
		elseif (BloodPlagueLeft < 6) and (readyRunes[3] > 0 or readyRunes[4] > 0) then 
			ApplyBloodPlague = true
		else
			ApplyBloodPlague = false
		end
		
		
		
		-- Oblit CD
		local ob = (readyUF > 0) or (readyRunes[4] >= 2) or (readyRunes[2] > 0 and readyRunes[4] > 0) or (readyRunes[3] > 0 and readyRunes[4] > 0)
		-- [2] Ob if both Frost/Unholy pairs and/or both Death runes are up, or if KM is procced
		------------------------------------------------------------------------------
		local KM = UnitBuff("player", BuffKillingMachine, nil, "PLAYER")
		-- There is a minor bug where there is a delay between the first Howling Blast and FF on the target
		-- I could try and account for it, but the dps loss of 2x HB in a row is fairly insignificant and the
		-- fix is somewhat complicated, so I'm just going to ignore it.
		
		-- Single Target Rotation
		if(not UnitDebuff("target", "Frost Fever", nil, "PLAYER")) then
			Spell1 = HowlingBlast
			WA:SetTitle("NoFF")
		elseif(ApplyBloodPlague) then
			Spell1 = PlagueStrike
			WA:SetTitle("NoBP")
		elseif(KM and ob) then
			Spell1 = Obliterate
			WA:SetTitle("Oblit KM")
		elseif(readyUF >= 2) then
			Spell1 = Obliterate
			WA:SetTitle("Oblit 2xUF")
		elseif(readyRunes[4] >= 2) then
			Spell1 = Obliterate
			WA:SetTitle("Oblit 2xDR")
		elseif(UnitPower("player") == UnitPowerMax("player")) then
			Spell1 = FrostStrike
			WA:SetTitle("RPMax")
		elseif(UnitBuff("player", BuffRime, nil, "PLAYER"))then
			Spell1 = HowlingBlast
			WA:SetTitle("Rime")
		elseif(ob) then
			Spell1 = Obliterate
			WA:SetTitle("Oblit")
		elseif(RunicPower > FrostStrikeCost) then
			Spell1 = FrostStrike
			WA:SetTitle("FS")
		elseif(HornOfWinterCD <= 0) then
			Spell1 = HornOfWinter
			WA:SetTitle("Horn")
		end
		
		if (readyRunes[3] >= 2) or (readyRunes[4] >= 2) then
			Spell2 = HowlingBlast
		elseif(readyRunes[2] >= 2) then
			if(DeathAndDecayCD <= 0) then
				Spell2 = DeathAndDecay
			else
				Spell2 = PlagueStrike
			end
		elseif(UnitPower("player") == UnitPowerMax("player")) then
			Spell2 = FrostStrike
		elseif(readyRunes[3] > 0 or readyRunes[4] > 0) then
			Spell2 = HowlingBlast
		elseif(readyRunes[2] > 0) then
			if(DeathAndDecayCD <= 0) then
				Spell2 = DeathAndDecay
			else
				Spell2 = PlagueStrike
			end
		elseif(RunicPower > FrostStrikeCost) then
			Spell2 = FrostStrike
		elseif(HornOfWinterCD <= 0) then
			Spell1 = HornOfWinter
		end
		WA:SpellFire(Spell1, Spell2, Spell3)
	end
end

function mod.OnInitialize()
	mod.checkSpec()
	if (enabled) then
		WA:Print("Initializing Frost")
		WA:SetToggle(1, 0, "Death Coil")		
		WA:SetToggle(2, 0, "Necrotic Strike")
		-- WA:SetToggle(3, 1, nil)
		WA:SetToggle(4, 1, "Mind Freeze")
		WA.GCD_Duration	= 1.0
		
		WA:RegisterRangeSpell("Icy Touch")
		
		-- ==================== REGISTER SPELL COLORS ==============================
		Outbreak				= WA:RegisterSpell(1, "Outbreak")
		IcyTouch				= WA:RegisterSpell(2, "Icy Touch")
		PlagueStrike			= WA:RegisterSpell(3, "Plague Strike")
		BloodTap				= WA:RegisterSpell(4, "Blood Tap")		
		HornOfWinter			= WA:RegisterSpell(5, "Horn of Winter")
		DeathCoil				= WA:RegisterSpell(6, "Death Coil")
		DeathAndDecay			= WA:RegisterSpell(7, "Death and Decay")
		BloodBoil				= WA:RegisterSpell(8, "Blood Boil")
		Obliterate				= WA:RegisterSpell(9, "Obliterate")
		FrostStrike				= WA:RegisterSpell(10, "Frost Strike")
		HowlingBlast			= WA:RegisterSpell(11, "Howling Blast")
		MindFreeze				= WA:RegisterSpell(12, "Mind Freeze")

		-- ==================== REGISTER ROTATION ==============================
		WA:setRotation(mod.rotation, "Unholy")
	end
end

function mod.checkSpec()
	PointsSpent = 0
	_, _, _, _, PointsSpent, _, _, _ = GetTalentTabInfo(2)	-- Check that enough points are spent in the right tree
	if(PointsSpent >= 30) then
		enabled = true
	else
		enabled = false
	end
end
