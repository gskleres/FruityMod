-- ===========================================================================
--	Popups when a Tech or Civic are completed
-- ===========================================================================
include("TechAndCivicSupport"); -- (Already includes Civ6Common and InstanceManager) PopulateUnlockablesForTech, PopulateUnlockablesForCivic, GetUnlockablesForCivic, GetUnlockablesForTech

	
-- ===========================================================================
--	CONSTANTS / MEMBERS
-- ===========================================================================
local RELOAD_CACHE_ID		:string = "TechCivicCompletedPopup";
local m_unlockIM			:table = InstanceManager:new( "UnlockInstance", "Top", Controls.UnlockStack );
local m_isWaitingToShowPopup:boolean = false;
local m_isDisabledByTutorial:boolean = false;
local m_kQueuedPopups		:table	 = {};
local m_bIsCivic            :boolean = false;
local m_quote_audio;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function ShowCompletedPopup(completedPopup:table)
	do return end; -- TAG_DISABLE_CIVIC_AND_TECH_POPUPS remove the civic/tech completed popups
	if completedPopup.tech ~= nil then
		ShowTechCompletedPopup(completedPopup.player, completedPopup.tech, completedPopup.isCanceled);
        m_bIsCivic = false;
	else
		ShowCivicCompletedPopup(completedPopup.player, completedPopup.civic, completedPopup.isCanceled);
        m_bIsCivic = true;
	end

	-- Queue Popup through UI Manager
	UIManager:QueuePopup( ContextPtr, PopupPriority.Low);	-- Made low so any Boost popups related will be shown first
	m_isWaitingToShowPopup = true;

	RefreshSize();
end

-- ===========================================================================
function ShowCivicCompletedPopup(player:number, civic:number, isCanceled:boolean)
	local civicInfo:table = GameInfo.Civics[civic];
	if civicInfo ~= nil then
		local civicType = civicInfo.CivicType;

		local isCivicUnlockGovernmentType:boolean = false;

		-- Update Header
		Controls.HeaderLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_CIVIC_COMPLETE"));

		-- Update Theme Icons
		Controls.TopLeftIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme1");
		Controls.LeftBottomIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme2");
		Controls.RightBottomIcon:SetTexture(0, 0, "CompletedPopup_CivicTheme3");

		-- Update Research Icon
		Controls.ResearchIconFrame:SetTexture(0, 0, "CompletedPopup_CivicFrame");

		local icon = "ICON_" .. civicInfo.CivicType;
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(icon,160);
		if textureSheet ~= nil then
			Controls.ResearchIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		end

		-- Update Research Name
		Controls.ResearchName:SetText(Locale.ToUpper(Locale.Lookup(civicInfo.Name)));

		-- Show Free Government Change Label
		Controls.CivicMsgLabel:SetHide(false);
		Controls.CivicMsgLabel:SetText(Locale.Lookup("LOC_UI_CIVIC_PROGRESS_COMPLETE_BLURB", civicInfo.Name));

		-- Update Unlocked Icons
		m_unlockIM:ResetInstances();

		local unlockableTypes = GetUnlockablesForCivic(civicType, player);
		local unlockCount = unlockableTypes and #unlockableTypes or 0;
		
		PopulateUnlockablesForCivic( player, civic, m_unlockIM );
		Controls.UnlockCountLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_UNLOCKED_BY_CIVIC", unlockCount));
	
		Controls.UnlockStack:CalculateSize();
		Controls.UnlockStack:ReprocessAnchoring();

		-- Update Quote
		local quote;

		-- Pick a quote at random.
		local results = DB.Query("SELECT Quote, QuoteAudio from CivicQuotes where CivicType = ? ORDER BY RANDOM() LIMIT 1", civicType);

		if(results) then
			for i, row in ipairs(results) do
				quote = row.Quote;
				m_quote_audio = row.QuoteAudio;
				break;
			end
		end


		-- If we have a quote, display it.  
		-- Otherwise, hide the quote box.
		if(quote and #quote > 0) then
			Controls.QuoteLabel:LocalizeAndSetText(quote);
		
			if(m_quote_audio and #m_quote_audio > 0) then
				Controls.QuoteAudio:SetHide(false);
				Controls.QuoteButton:RegisterCallback(Mouse.eLClick, function() 
					UI.PlaySound(m_quote_audio);
				end);
			else
				Controls.QuoteAudio:SetHide(true);
				Controls.QuoteButton:ClearCallback(Mouse.eLClick);
			end

			Controls.QuoteButton:SetHide(false);
		else
			Controls.QuoteButton:SetHide(true);
		end
		
		-- Determine if we've unlocked a new government type
		for _,unlockItem in ipairs(unlockableTypes) do
			local typeInfo = GameInfo.Types[unlockItem];
			if(typeInfo and typeInfo.Kind == "KIND_GOVERNMENT") then
				isCivicUnlockGovernmentType = true;
			end
		end

		-- Update Government Button depending on if we unlocked a new government type
		if isCivicUnlockGovernmentType then
			Controls.ChangeGovernmentButton:SetText(Locale.Lookup("LOC_GOVT_CHANGE_GOVERNMENTS"));
			Controls.ChangeGovernmentButton:ClearCallback( eLClick );
			Controls.ChangeGovernmentButton:RegisterCallback( eLClick, OnChangeGovernment );
			Controls.ChangeGovernmentButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		else
			Controls.ChangeGovernmentButton:SetText(Locale.Lookup("LOC_GOVT_CHANGE_POLICIES"));
			Controls.ChangeGovernmentButton:ClearCallback( eLClick );
			Controls.ChangeGovernmentButton:RegisterCallback( eLClick, OnChangePolicy );
			Controls.ChangeGovernmentButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		end

		-- Show Change Government Button
		Controls.ChangeGovernmentButton:SetHide(false);
	end
end

-- ===========================================================================
function ShowTechCompletedPopup(player:number, techId:number, isCanceled:boolean)
	local techInfo:table = GameInfo.Technologies[techId];
	if techInfo ~= nil then
		local techType = techInfo.TechnologyType;

		-- Update Header
		Controls.HeaderLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_TECH_COMPLETE"));

		-- Update Theme Icons
		Controls.TopLeftIcon:SetTexture(0, 0, "CompletedPopup_TechTheme1");
		Controls.LeftBottomIcon:SetTexture(0, 0, "CompletedPopup_TechTheme2");
		Controls.RightBottomIcon:SetTexture(0, 0, "CompletedPopup_TechTheme3");

		-- Update Research Icon
		Controls.ResearchIconFrame:SetTexture(0, 0, "CompletedPopup_TechFrame");

		local icon = "ICON_" .. techInfo.TechnologyType;
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(icon,160);
		if textureSheet ~= nil then
			Controls.ResearchIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		end

		-- Update Research Name
		Controls.ResearchName:SetText(Locale.Lookup(techInfo.Name));

		-- Hide Free Government Change Label
		Controls.CivicMsgLabel:SetHide(true);

		-- Update Unlocked Icons
		m_unlockIM:ResetInstances();
		local unlockableTypes = GetUnlockablesForTech( techType, player );
		local count = unlockableTypes and #unlockableTypes or 0;

		PopulateUnlockablesForTech(player, techId, m_unlockIM);
		Controls.UnlockCountLabel:SetText(Locale.Lookup("LOC_RESEARCH_COMPLETE_UNLOCKED_BY_TECH", #unlockableTypes));
		
		Controls.UnlockStack:CalculateSize();
		Controls.UnlockStack:ReprocessAnchoring();

		-- Update Quote
		local quote;

		-- Pick a quote at random.

		local results = DB.Query("SELECT Quote, QuoteAudio from TechnologyQuotes where TechnologyType = ? ORDER BY RANDOM() LIMIT 1", techInfo.TechnologyType);
		if(results ~= nil) then
			for i, row in ipairs(results) do
				quote = row.Quote;
				m_quote_audio = row.QuoteAudio;
			end
		end

		-- If we have a quote, display it.  
		-- Otherwise, hide the quote box.
		if(quote and #quote > 0) then
			Controls.QuoteLabel:LocalizeAndSetText(quote);
		
			if(m_quote_audio and #m_quote_audio > 0) then
				Controls.QuoteAudio:SetHide(false);
				Controls.QuoteButton:RegisterCallback(Mouse.eLClick, function() 
					UI.PlaySound(m_quote_audio);
				end);
			else
				Controls.QuoteAudio:SetHide(true);
				Controls.QuoteButton:ClearCallback(Mouse.eLClick);
			end

			Controls.QuoteButton:SetHide(false);
		else
			Controls.QuoteButton:SetHide(true);
		end
		
		-- Hide Change Government Button
		Controls.ChangeGovernmentButton:SetHide(true);
	end
end

-- ===========================================================================
function RefreshSize()

	-- Manually adjust the height so that there is minimal space for the image control.
	local PADDING:number = 30;
	local quote_height = math.max(100, Controls.QuoteLabel:GetSizeY() + PADDING);
	Controls.QuoteButton:SetSizeY(quote_height);

	Controls.BottomControlStack:CalculateSize();
	Controls.BottomControlStack:ReprocessAnchoring();

	Controls.PopupBackgroundImage:DoAutoSize();
	Controls.PopupDrowShadowGrid:DoAutoSize();
end

-- ===========================================================================
function OnCivicCompleted( player:number, civic:number, isCanceled:boolean)
	if player == Game.GetLocalPlayer() and (not m_isDisabledByTutorial) then
		local civicCompletedEntry:table = { player=player, civic=civic, isCanceled=isCanceled };

		if not m_isWaitingToShowPopup then
			ShowCompletedPopup(civicCompletedEntry);
		else
			-- Add to queue if already showing a tech/civic completed popup
			table.insert(m_kQueuedPopups, civicCompletedEntry);
		end
	end
end

-- ===========================================================================
function OnResearchCompleted( player:number, tech:number, isCanceled:boolean)
	if player == Game.GetLocalPlayer() and (not m_isDisabledByTutorial) then
		local techCompletedEntry:table = { player=player, tech=tech, isCanceled=isCanceled };

		if not m_isWaitingToShowPopup then
			ShowCompletedPopup(techCompletedEntry);
		else
			-- Add to queue if already showing a tech/civic completed popup
			table.insert(m_kQueuedPopups, techCompletedEntry);
		end
	end
end

-- ===========================================================================
--	Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()
	-- Dequeue popup from UI mananger (will re-queue if another is about to show).
	UIManager:DequeuePopup( ContextPtr );

	-- Find first entry in table, display that, then remove it from the internal queue
	for i, entry in ipairs(m_kQueuedPopups) do
		ShowCompletedPopup(entry);
		table.remove(m_kQueuedPopups, i);
		break;
	end

	-- If no more popups are in the queue, close the whole context down.
	if table.count(m_kQueuedPopups) == 0 then
		m_isWaitingToShowPopup = false;
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClose()
    if m_bIsCivic then
        UI.PlaySound("Stop_Speech_Civics");
    else
        UI.PlaySound("Stop_Speech_Tech");
    end
	Close();
end

-- ===========================================================================
function OnChangeGovernment()	
	Close();
	LuaEvents.TechCivicCompletedPopup_GovernmentOpenGovernments();	-- Open Government Screen	
	UI.PlaySound("Stop_Speech_Civics");
end

-- ===========================================================================
function OnChangePolicy()	
	Close();
	LuaEvents.TechCivicCompletedPopup_GovernmentOpenPolicies();		-- Open Government Screen	
	UI.PlaySound("Stop_Speech_Civics");
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then		
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);		
	end
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnShow( )
    UI.PlaySound("Pause_Advisor_Speech");
    UI.PlaySound("Resume_TechCivic_Speech");
    if(m_quote_audio and #m_quote_audio > 0) then
        UI.PlaySound(m_quote_audio);
    end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden",		ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "kQueuedPopups",	m_kQueuedPopups );
	-- TODO: Add current popup to queue list.
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
	end
end

-- ===========================================================================
--	LUA Event
--	Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context ~= RELOAD_CACHE_ID then
		return;
	end
	local isHidden:boolean = contextTable["isHidden"]; 
	if not isHidden then
		local kQueuedPopups:table = contextTable["kQueuedPopups"];
		if kQueuedPopups ~= nil then
			for _,entry in ipairs(kQueuedPopups) do
				ShowCompletedPopup( entry );
			end
		end
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnDisableTechAndCivicPopups()
	m_isDisabledByTutorial = true;
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnEnableTechAndCivicPopups()
	m_isDisabledByTutorial = false;
end

-- ===========================================================================
function Initialize()	
	-- Controls Events
	Controls.CloseButton:RegisterCallback( eLClick, OnClose );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
    ContextPtr:SetShowHandler( OnShow );

	-- LUA Events
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
	LuaEvents.TutorialUIRoot_DisableTechAndCivicPopups.Add( OnDisableTechAndCivicPopups );
	LuaEvents.TutorialUIRoot_EnableTechAndCivicPopups.Add( OnEnableTechAndCivicPopups );

	-- Game Events
	Events.ResearchCompleted.Add(OnResearchCompleted);
	Events.CivicCompleted.Add(OnCivicCompleted);
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
end
Initialize();
