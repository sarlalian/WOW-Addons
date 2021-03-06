-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

-- mod name in lower case
local modName = "Retribution"
local version = 1

--================== Initialize Variables =====================
local Spell1 = nil
local Spell2 = nil
local Spell3 = nil

-- create a module in the main addon
local mod = WA:RegisterClassModule(modName)

-- any error sets this to false
local enabled = true

--================== Initialize Spec Variables =====================
local InquisitionRefresh 	= 5
local InquisitionApplyMin 	= 3
local InquisitionRefreshMin	= 3
local undead				= "Undead"
local demon					= "Demon"
local ConsecrateManaMin		= 20000

--------------------------------------------------------------------------------
local GlobalCD 						= 85256 -- tv for gcd
-- list of spellId
local HammerOfWrathID 				= 24275	-- hammer of wrath
local CrusaderStrikeID 				= 35395	-- crusader strike
local TemplarsVerdictID				= 85256	-- templar's verdict
local InquisitionID					= 84963	-- inquisition
local DivineStormID					= 53385	-- divine storm
local JudgementID					= 20271	-- judgement
local ConsecrationID				= 26573	-- consecration
local ExorcismID					= 879	-- exorcism
local HolyWrathID					= 2812 	-- holy wrath
local ZealotryID					= 85696 -- zealotry
local InquisitionID					= 84963 -- inquisition

-- buffs
local ZealotryBuff 					= GetSpellInfo(ZealotryID)	-- zealotry
local DivinePurposeBuff				= GetSpellInfo(90174)		-- divine purpose
local ArtOfWarBuff					= GetSpellInfo(59578)		-- the art of war
local InquisitionBuff 				= GetSpellInfo(InquisitionID)		-- inquisition
-- Local Vars
local StartTime, TargetCreatureType


function mod.rotation(StartTime, GCDTimeLeft)
	if(enabled) then
		
		HolyPower 			= UnitPower("player",SPELL_POWER_HOLY_POWER)
		Health 				= UnitHealth("player")
		HealthMax 			= UnitHealthMax("player")
		HealthPercent 		= (Health / HealthMax) * 100
		UnitHasteLevel		= 1 + UnitSpellHaste("player") / 100

		THealth 			= UnitHealth("target")
		THealthMax 			= UnitHealthMax("target")
		THealthPercent 		= (THealth / THealthMax) * 100
		TargetCreatureType	= UnitCreatureType("target")

		BuffDivinePurpose 	= WA:GetBuff(DivinePurposeBuff)
		BuffArtOfWar 		= WA:GetBuff(ArtOfWarBuff)
		BuffZealotry 		= WA:GetBuff(ZealotryBuff)
		BuffInquisition 	= WA:GetBuff(InquisitionBuff)
		
		CrusaderStrikeCD 	= WA:GetCooldown(CrusaderStrikeID)
		JudgementCD			= WA:GetCooldown(JudgementID)
		ConsecrationCD		= WA:GetCooldown(ConsecrationID)
		HolyWrathCD			= WA:GetCooldown(HolyWrathID)
		HammerOfWrathCD		= WA:GetCooldown(HammerOfWrathID)
		
		-- Single Target Rotation
		if(BuffInquisition <= 0 and (HolyPower >= InquisitionApplyMin or BuffDivinePurpose > 0)) then
			-- Apply Inquisition at 3HP
			Spell1 = Inquisition
		elseif(BuffInquisition <= InquisitionRefresh and HolyPower >= InquisitionRefreshMin) then
			-- Refresh Inquisition at 3HP
			Spell1 = Inquisition
		elseif(HolyPower >= 3) then
			-- TV at 3HP
			Spell1 = TemplarsVerdict
		elseif(HolyPower < 3 and CrusaderStrikeCD <= 0) then
			-- CrusaderStrike filler
			Spell1 = CrusaderStrike
		elseif(BuffInquisition <= 0 and BuffDivinePurpose > 0) then
			-- Apply Inquisition with DP
			Spell1 = Inquisition
		elseif(BuffDivinePurpose > 0) then
			-- TV with DP
			Spell1 = TemplarsVerdict
		elseif (TargetCreatureType == undead or TargetCreatureType == demon) and BuffArtOfWar > 0 then
			-- Exorcisim if Undead or Demon with AOW
			Spell1 = Exorcism
		elseif(IsUsableSpell(HammerOfWrathID) and HammerOfWrathCD <=0 ) then
			-- Execute Range -- Hammer of Wrath
			Spell1 = HammerOfWrath
		elseif(BuffArtOfWar > 0) then
			-- Exorcism with AOW
			Spell1 = Exorcism
		elseif(JudgementCD <= 0) then
			-- Judgement
			Spell1 = Judgement
		elseif(HolyWrathCD <= 0) then
			-- Holy Wrath
			Spell1 = HolyWrath
		elseif(UnitPower("player") > ConsecrateManaMin and ConsecrationCD <= 0) then
			Spell1 = Consecration
		else
			Spell1 = CrusaderStrike
		end
		if(Spell1 == CrusaderStrike) then
			Spell2 = DivineStorm
		else
			Spell2 = Spell1
		end		
		WA:SpellFire(Spell1, Spell2, Spell3)
	end
end

function mod.OnInitialize()
	mod.checkSpec()
	if (enabled) then
		WA:Print("Initializing _ret")
		WA:SetToggle(1, 0, "Consecration")		
		-- WA:SetToggle(2, 0, nil)
		-- WA:SetToggle(3, 1, nil)
		WA:SetToggle(4, 1, "Rebuke")
		
		WA:RegisterRangeSpell("Holy Light")
	
		CrusaderStrike			= WA:RegisterSpell(1, "Crusader Strike")
		DivineStorm				= WA:RegisterSpell(2, "Divine Storm")
		Judgement				= WA:RegisterSpell(3, "Judgement")
		Inquisition				= WA:RegisterSpell(4, "Inquisition")
		HammerOfWrath			= WA:RegisterSpell(5, "Hammer of Wrath")
		HolyWrath				= WA:RegisterSpell(6, "Holy Wrath")
		Consecrate				= WA:RegisterSpell(7, "Consecration")
		TemplarsVerdict			= WA:RegisterSpell(8, "Templar's Verdict")
		Exorcism				= WA:RegisterSpell(9, "Exorcism")
		
		Rebuke					= WA:RegisterSpell(12, "Rebuke")

		-- ==================== REGISTER ROTATION ==============================
		WA:setRotation(mod.rotation, "Retribution")
	end
end

function mod.checkSpec()
	PointsSpent = 0
	_, _, _, _, PointsSpent, _, _, _ = GetTalentTabInfo(3)	-- Check that enough points are spent in the right tree
	if(PointsSpent >= 30) then
		enabled = true
	else
		enabled =  false
	end
end