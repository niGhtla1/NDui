local _, ns = ...
local B, C, L, DB = unpack(ns)
local module = B:RegisterModule("Misc")

local tostring, tonumber, pairs = tostring, tonumber, pairs
local tremove, tinsert = table.remove, table.insert
local strsplit, random = string.split, math.random

--[[
	Miscellaneous 各种有用没用的小玩意儿
]]
function module:OnLogin()
	self:AddAlerts()
	self:Expbar()
	self:Focuser()
	self:Mailbox()
	self:MissingStats()
	self:ShowItemLevel()
	self:QuickJoin()
	self:QuestNotifier()
	self:GuildBest()
	if NDuiDB["Misc"]["ParagonRep"] then
		hooksecurefunc("ReputationFrame_Update", self.HookParagonRep)
	end
	self:NakedIcon()
	self:ExtendInstance()
	self:PetFilterTab()

	-- Hide Bossbanner
	if NDuiDB["Misc"]["HideBanner"] then
		BossBanner:UnregisterAllEvents()
	end

	-- Fix patch 27326
	GuildControlUIRankSettingsFrameRosterLabel = CreateFrame("Frame", nil, B.HiddenFrame)
end

-- Archaeology counts
do
	local function CalculateArches()
		print("|cff0080ff【NDui】".."|c0000FF00"..L["Arch Count"]..":")
		local total = 0
		for i = 1, GetNumArchaeologyRaces() do
			local numArtifacts = GetNumArtifactsByRace(i)
			local count = 0
			for j = 1, numArtifacts do
				local completionCount = select(10, GetArtifactInfoByRace(i, j))
				count = count + completionCount
			end
			local name = GetArchaeologyRaceInfo(i)
			if numArtifacts > 1 then
				print("     - |cfffed100"..name..": ".."|cff70C0F5"..count)
				total = total + count
			end 
		end
		print("    -> |c0000ff00"..TOTAL..": ".."|cffff0000"..total)
		print("|cff70C0F5------------------------")
	end

	local function AddCalculateIcon()
		local bu = CreateFrame("Button", nil, ArchaeologyFrameCompletedPage)
		bu:SetPoint("TOPRIGHT", -45, -45)
		bu:SetSize(35, 35)
		B.PixelIcon(bu, "Interface\\ICONS\\Ability_Iyyokuk_Calculate", true)
		B.AddTooltip(bu, "ANCHOR_RIGHT", L["Arch Count"], "system")
		bu:SetScript("OnMouseUp", CalculateArches)
	end

	local function setupMisc(event, addon)
		if addon == "Blizzard_ArchaeologyUI" then
			AddCalculateIcon()
			-- Repoint Bar
			ArcheologyDigsiteProgressBar.ignoreFramePositionManager = true
			ArcheologyDigsiteProgressBar:SetPoint("BOTTOM", 0, 150)
			B.CreateMF(ArcheologyDigsiteProgressBar)

			B:UnregisterEvent(event, setupMisc)
		end
	end

	B:RegisterEvent("ADDON_LOADED", setupMisc)
end

-- Hide errors in combat
do
	local erList = {
		[ERR_ABILITY_COOLDOWN] = true,
		[ERR_ATTACK_MOUNTED] = true,
		[ERR_OUT_OF_ENERGY] = true,
		[ERR_OUT_OF_FOCUS] = true,
		[ERR_OUT_OF_HEALTH] = true,
		[ERR_OUT_OF_MANA] = true,
		[ERR_OUT_OF_RAGE] = true,
		[ERR_OUT_OF_RANGE] = true,
		[ERR_OUT_OF_RUNES] = true,
		[ERR_OUT_OF_HOLY_POWER] = true,
		[ERR_OUT_OF_RUNIC_POWER] = true,
		[ERR_OUT_OF_SOUL_SHARDS] = true,
		[ERR_OUT_OF_ARCANE_CHARGES] = true,
		[ERR_OUT_OF_COMBO_POINTS] = true,
		[ERR_OUT_OF_CHI] = true,
		[ERR_OUT_OF_POWER_DISPLAY] = true,
		[ERR_SPELL_COOLDOWN] = true,
		[ERR_ITEM_COOLDOWN] = true,
		[SPELL_FAILED_BAD_IMPLICIT_TARGETS] = true,
		[SPELL_FAILED_BAD_TARGETS] = true,
		[SPELL_FAILED_CASTER_AURASTATE] = true,
		[SPELL_FAILED_NO_COMBO_POINTS] = true,
		[SPELL_FAILED_SPELL_IN_PROGRESS] = true,
		[SPELL_FAILED_TARGET_AURASTATE] = true,
		[ERR_NO_ATTACK_TARGET] = true,
	}

	local function setupMisc(event, ...)
		if NDuiDB["Misc"]["HideErrors"] then
			local text = select(2, ...)
			if InCombatLockdown() and erList[text] then
				UIErrorsFrame:UnregisterEvent(event)
			else
				UIErrorsFrame:RegisterEvent(event)
			end
		else
			B:UnregisterEvent(event, setupMisc)
		end
	end

	B:RegisterEvent("UI_ERROR_MESSAGE", setupMisc)
end

-- Show BID and highlight price
do
	local function setupMisc(event, addon)
		if addon == "Blizzard_AuctionUI" then
			hooksecurefunc("AuctionFrameBrowse_Update", function()
				local numBatchAuctions = GetNumAuctionItems("list")
				local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame)
				for i = 1, NUM_BROWSE_TO_DISPLAY do
					local index = offset + i + (NUM_AUCTION_ITEMS_PER_PAGE * AuctionFrameBrowse.page)
					if index <= numBatchAuctions + (NUM_AUCTION_ITEMS_PER_PAGE * AuctionFrameBrowse.page) then
						local name, _, _, _, _, _, _, _, _, buyoutPrice, bidAmount =  GetAuctionItemInfo("list", offset + i)
						local alpha = .5
						local color = "yellow"
						if name then
							local itemName = _G["BrowseButton"..i.."Name"]
							local moneyFrame = _G["BrowseButton"..i.."MoneyFrame"]
							local buyoutMoney = _G["BrowseButton"..i.."BuyoutFrameMoney"]
							if buyoutPrice/10000 >= 5000 then color = "red" end
							if bidAmount > 0 then
								name = name .. " |cffffff00"..BID.."|r"
								alpha = 1.0
							end
							itemName:SetText(name)
							moneyFrame:SetAlpha(alpha)
							SetMoneyFrameColor(buyoutMoney:GetName(), color)
						end
					end
				end
			end)

			B:UnregisterEvent(event, setupMisc)
		end
	end

	B:RegisterEvent("ADDON_LOADED", setupMisc)
end

-- Drag AltPowerbar
do
	local mover = CreateFrame("Frame", "NDuiAltBarMover", PlayerPowerBarAlt)
	mover:SetPoint("CENTER", UIParent, 0, -200)
	mover:SetSize(20, 20)
	B.CreateMF(PlayerPowerBarAlt, mover)

	hooksecurefunc(PlayerPowerBarAlt, "SetPoint", function(_, _, parent)
		if parent ~= mover then
			PlayerPowerBarAlt:ClearAllPoints()
			PlayerPowerBarAlt:SetPoint("CENTER", mover)
		end
	end)

	hooksecurefunc("UnitPowerBarAlt_SetUp", function(self)
		local statusFrame = self.statusFrame
		if statusFrame.enabled then
			statusFrame:Show()
			statusFrame.Hide = statusFrame.Show
		end
	end)
end

-- Get Naked
function module:NakedIcon()
	local bu = CreateFrame("Button", nil, CharacterFrameInsetRight)
	bu:SetSize(31, 33)
	bu:SetPoint("RIGHT", PaperDollSidebarTab1, "LEFT", -4, -2)
	B.PixelIcon(bu, "Interface\\ICONS\\SPELL_SHADOW_TWISTEDFAITH", true)
	B.AddTooltip(bu, "ANCHOR_RIGHT", L["Get Naked"])

	local function UnequipItemInSlot(i)
		local action = EquipmentManager_UnequipItemInSlot(i)
		EquipmentManager_RunAction(action)
	end

	bu:SetScript("OnDoubleClick", function()
		for i = 1, 17 do
			local texture = GetInventoryItemTexture("player", i)
			if texture then
				UnequipItemInSlot(i) 
			end
		end
	end)
end

-- ALT+RightClick to buy a stack
do
	local old_MerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick
	local cache = {}
	function MerchantItemButton_OnModifiedClick(self, ...)
		if IsAltKeyDown() then
			local id = self:GetID()
			local itemLink = GetMerchantItemLink(id)
			if not itemLink then return end
			local name, _, quality, _, _, _, _, maxStack, _, texture = GetItemInfo(itemLink)
			if maxStack and maxStack > 1 then
				if not cache[itemLink] then
					StaticPopupDialogs["BUY_STACK"] = {
						text = L["Stack Buying Check"],
						button1 = YES,
						button2 = NO,
						OnAccept = function()
							BuyMerchantItem(id, GetMerchantItemMaxStack(id))
							cache[itemLink] = true
						end,
						hideOnEscape = 1,
						hasItemFrame = 1,
					}

					local r, g, b = GetItemQualityColor(quality or 1)
					StaticPopup_Show("BUY_STACK", " ", " ", {["texture"] = texture, ["name"] = name, ["color"] = {r, g, b, 1}, ["link"] = itemLink, ["index"] = id, ["count"] = maxStack})
				else
					BuyMerchantItem(id, GetMerchantItemMaxStack(id))
				end
			end
		end

		old_MerchantItemButton_OnModifiedClick(self, ...)
	end
end

-- Auto screenshot when Achievement earned
do
	local f = CreateFrame("Frame")
	f:Hide()
	f:SetScript("OnUpdate", function(_, elapsed)
		f.delay = f.delay - elapsed
		if f.delay < 0 then
			Screenshot()
			f:Hide()
		end
	end)

	local function setupMisc(event)
		if not NDuiDB["Misc"]["Screenshot"] then
			B:UnregisterEvent(event, setupMisc)
		else
			f.delay = 1
			f:Show()
		end
	end

	B:RegisterEvent("ACHIEVEMENT_EARNED", setupMisc)
end

-- RC in MasterSound
do
	B:RegisterEvent("READY_CHECK", function()
		PlaySound(SOUNDKIT.READY_CHECK, "master")
	end)
end

-- Faster Looting
do
	local delay = 0
	local function setupMisc(event)
		if NDuiDB["Misc"]["FasterLoot"] then
			if GetTime() - delay >= .3 then
				delay = GetTime()
				if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
					for i = GetNumLootItems(), 1, -1 do
						LootSlot(i)
					end
					delay = GetTime()
				end
			end
		else
			B:UnregisterEvent(event, setupMisc)
		end
	end

	B:RegisterEvent("LOOT_READY", setupMisc)
end

-- Hide TalkingFrame
do
	local function NoTalkingHeads()
		hooksecurefunc(TalkingHeadFrame, "Show", function(self)
			self:Hide()
		end)
		TalkingHeadFrame.ignoreFramePositionManager = true
	end

	local function setupMisc(event, addon)
		if not NDuiDB["Misc"]["HideTalking"] then
			B:UnregisterEvent(event, setupMisc)
			return
		end

		if event == "PLAYER_ENTERING_WORLD" then
			B:UnregisterEvent(event, setupMisc)
			if IsAddOnLoaded("Blizzard_TalkingHeadUI") then
				NoTalkingHeads()
				B:UnregisterEvent("ADDON_LOADED", setupMisc)
			end
		elseif event == "ADDON_LOADED" and addon == "Blizzard_TalkingHeadUI" then
			NoTalkingHeads()
			B:UnregisterEvent(event, setupMisc)
		end
	end

	B:RegisterEvent("PLAYER_ENTERING_WORLD", setupMisc)
	B:RegisterEvent("ADDON_LOADED", setupMisc)
end

-- Extend Instance
function module:ExtendInstance()
	local bu = CreateFrame("Button", nil, RaidInfoFrame)
	bu:SetPoint("TOPRIGHT", -35, -5)
	bu:SetSize(25, 25)
	B.PixelIcon(bu, GetSpellTexture(80353), true)
	B.AddTooltip(bu, "ANCHOR_RIGHT", L["Extend Instance"], "system")

	bu:SetScript("OnMouseUp", function(_, btn)
		for i = 1, GetNumSavedInstances() do
			local _, _, _, _, _, extended, _, isRaid = GetSavedInstanceInfo(i)
			if isRaid then
				if btn == "LeftButton" then
					if not extended then
						SetSavedInstanceExtend(i, true)		-- extend
					end
				else
					if extended then
						SetSavedInstanceExtend(i, false)	-- cancel
					end
				end
			end
		end
		RequestRaidInfo()
		RaidInfoFrame_Update()
	end)
end

-- Repoint Vehicle
do
	local mover = B.CreateGear(VehicleSeatIndicator, "NDuiVehicleSeatMover")
	mover:SetPoint("BOTTOMRIGHT", UIParent, -360, 30)
	mover:SetFrameStrata("HIGH")
	B.AddTooltip(mover, "ANCHOR_TOP", L["Toggle"], "system")
	B.CreateMF(mover)

	hooksecurefunc(VehicleSeatIndicator, "SetPoint", function(_, _, parent)
		if parent ~= mover then
			VehicleSeatIndicator:ClearAllPoints()
			VehicleSeatIndicator:SetClampedToScreen(true)
			VehicleSeatIndicator:SetPoint("BOTTOMRIGHT", mover, "BOTTOMLEFT", -5, 0)
		end
	end)
end

-- Fix Drag Collections taint
do
	local done
	local function setupMisc(event, addon)
		if event == "ADDON_LOADED" and addon == "Blizzard_Collections" then
			CollectionsJournal:HookScript("OnShow", function()
				if not done then
					if InCombatLockdown() then
						B:RegisterEvent("PLAYER_REGEN_ENABLED", setupMisc)
					else
						B.CreateMF(CollectionsJournal)
					end
					done = true
				end
			end)
			B:UnregisterEvent(event, setupMisc)
		elseif event == "PLAYER_REGEN_ENABLED" then
			B.CreateMF(CollectionsJournal)
			B:UnregisterEvent(event, setupMisc)
		end
	end

	B:RegisterEvent("ADDON_LOADED", setupMisc)
end

-- Temporary taint fix
do
	InterfaceOptionsFrameCancel:SetScript("OnClick", function()
		InterfaceOptionsFrameOkay:Click()
	end)

	-- https://www.townlong-yak.com/bugs/Kjq4hm-DisplayModeCommunitiesTaint
	if (UIDROPDOWNMENU_OPEN_PATCH_VERSION or 0) < 1 then
		UIDROPDOWNMENU_OPEN_PATCH_VERSION = 1
		hooksecurefunc("UIDropDownMenu_InitializeHelper", function(frame)
			if UIDROPDOWNMENU_OPEN_PATCH_VERSION ~= 1 then return end

			if UIDROPDOWNMENU_OPEN_MENU and UIDROPDOWNMENU_OPEN_MENU ~= frame and not issecurevariable(UIDROPDOWNMENU_OPEN_MENU, "displayMode") then
				UIDROPDOWNMENU_OPEN_MENU = nil
				local t, f, prefix, i = _G, issecurevariable, " \0", 1
				repeat
					i, t[prefix .. i] = i+1
				until f("UIDROPDOWNMENU_OPEN_MENU")
			end
		end)
	end
end

-- Roll Gold
if DB.Client == "zhCN" then
	local maxGold, maxPacks, curGold, remainGold
	local keyword, goldList, index, finish = "#1", {}, 1, true
	local f = CreateFrame("Frame")

	local function sendMsg(msg)
		SendChatMessage(msg, "GUILD")
		--print(msg)
	end

	local function randomRoll(gold)
		local cur = random(1, gold - (maxPacks-index))
		gold = gold - cur
		return cur, gold
	end

	local function finishRoll()
		finish = true
		remainGold = nil
		index = 1
		wipe(goldList)
		f:UnregisterAllEvents()
	end

	f:SetScript("OnEvent", function(_, _, ...)
		if finish then return end
		local msg, author = ...
		if msg == keyword and not goldList[author] then
			if maxPacks == 1 then
				sendMsg(maxGold.."金都被"..author.."抢走了")
				finishRoll()
			elseif index == maxPacks then
				goldList[author] = remainGold
				sendMsg("所有的金币都已经被抢完，分别是：")
				local text = ""
				for k, v in pairs(goldList) do
					text = text..k..": "..v.."金 "
					if #text > 212 then	-- 255-13*3-4=212
						sendMsg(text)
						text = ""
					end
				end
				sendMsg(text)
				finishRoll()
			else
				curGold, remainGold = randomRoll(remainGold or maxGold)
				goldList[author] = curGold
				index = index + 1
				sendMsg(author.."抢到了"..curGold.."金。")
			end
		end
	end)

	SlashCmdList["ROLLGOLD"] = function(arg)
		if not arg then return end
		local max, num = strsplit(" ", tostring(arg))
		maxGold = tonumber(max)
		maxPacks = tonumber(num) or 1
		if maxPacks > 10 then maxPacks = 10 end
		finish = false
		f:RegisterEvent("CHAT_MSG_GUILD")
		sendMsg("我拿出了"..max.."金，装成"..maxPacks.."份，快输入 "..keyword.." 来抢吧。")
	end
	SLASH_ROLLGOLD1 = "/groll"
end

-- Select target when click on raid units
do
	local function fixRaidGroupButton()
		for i = 1, 40 do
			local bu = _G["RaidGroupButton"..i]
			if bu and bu.unit and not bu.clickFixed then
				bu:SetAttribute("type", "target")
				bu:SetAttribute("unit", bu.unit)

				bu.clickFixed = true
			end
		end
	end

	local function setupMisc(event, addon)
		if event == "ADDON_LOADED" and addon == "Blizzard_RaidUI" then
			if not InCombatLockdown() then
				fixRaidGroupButton()
			else
				B:RegisterEvent("PLAYER_REGEN_ENABLED", setupMisc)
			end
			B:UnregisterEvent(event, setupMisc)
		elseif event == "PLAYER_REGEN_ENABLED" then
			if RaidGroupButton1 and RaidGroupButton1:GetAttribute("type") ~= "target" then
				fixRaidGroupButton()
				B:UnregisterEvent(event, setupMisc)
			end
		end
	end

	B:RegisterEvent("ADDON_LOADED", setupMisc)
end

-- Instant delete
do
	hooksecurefunc(StaticPopupDialogs["DELETE_GOOD_ITEM"], "OnShow", function(self)
		self.editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
	end)
end

-- TradeFrame hook
do
	local infoText = B.CreateFS(TradeFrame, 16, "")
	infoText:ClearAllPoints()
	infoText:SetPoint("TOP", TradeFrameRecipientNameText, "BOTTOM", 0, -5)

	local function updateColor()
		local r, g, b = B.UnitColor("NPC")
		TradeFrameRecipientNameText:SetTextColor(r, g, b)

		local guid = UnitGUID("NPC")
		if not guid then return end
		local text = "|cffff0000"..L["Stranger"]
		if BNGetGameAccountInfoByGUID(guid) or IsCharacterFriend(guid) then
			text = "|cffffff00"..FRIEND
		elseif IsGuildMember(guid) then
			text = "|cff00ff00"..GUILD
		end
		infoText:SetText(text)
	end
	hooksecurefunc("TradeFrame_Update", updateColor)
end