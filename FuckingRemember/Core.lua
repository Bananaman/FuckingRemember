--[[

    Project:   "FuckingRemember: Your Dailies"
    Author:    VideoPlayerCode
    URL:       https://github.com/VideoPlayerCode/FuckingRemember
    License:   Apache License, Version 2.0

]]

local FuckingRemember = CreateFrame('Frame');

-- Turn important globals into locals.
local CollapseQuestHeader = CollapseQuestHeader;
local ExpandQuestHeader = ExpandQuestHeader;
local GetQuestLogTitle = GetQuestLogTitle;
local GetRealZoneText = GetRealZoneText;
local GetTime = GetTime;

-- Easily print messages to the chat frame.
local function Print(msg)
    assert(msg, 'You must provide a message.');
    if (type(msg) ~= "string") then msg = tostring(msg); end
    msg = '|cFF00AAFFRemember:|r ' .. msg;
    DEFAULT_CHAT_FRAME:AddMessage(msg);
    return msg;
end

-- Check all active dailies and alert the player about any completed-but-undelivered dailies.
local function scanDailies()
    -- Scan all quests and open any collapsed headers on the way (so that we can scan their quests too).
    local finishedDailies, openedHeaders;
    local questIndex = 0;
    local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily;
    while (true) do
        questIndex = questIndex + 1;
        questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
        if (not questLogTitleText) then
            break; -- No more quest log entries.
        end

        if (isHeader) then
            if (isCollapsed) then
                if (not openedHeaders) then openedHeaders = {}; end
                openedHeaders[#openedHeaders+1] = questIndex;
                ExpandQuestHeader(questIndex);
            end
        else -- It's a Quest.
            if (isDaily and isComplete) then
                if (not finishedDailies) then finishedDailies = {}; end
                finishedDailies[#finishedDailies+1] = questLogTitleText;
            end
        end
    end

    -- Collapse the opened headers again. We must do this backwards to close the correct offsets.
    if (openedHeaders and #openedHeaders > 0) then
        for i=#openedHeaders, 1, -1 do
            questIndex = openedHeaders[i];
            questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
            if (isHeader) then
                CollapseQuestHeader(questIndex);
            else
                break; -- What?! Should never be able to happen... abort.
            end
        end
    end

    -- Alert the player about their completed dailies!
    if (finishedDailies and #finishedDailies > 0) then
        table.sort(finishedDailies); -- Sort BEFORE re-coloring anything.
        for k,v in ipairs(finishedDailies) do
            if (v:match('^Wanted: ')) then -- Heroic/Normal dungeon daily. English clients only.
                finishedDailies[k] = '|cFFFF66FF'..v..'|r'; -- Light pink.
            end
        end
        local msg = Print('"' .. table.concat(finishedDailies, '", "') .. '".'); -- Returns formatted msg.
        UIErrorsFrame:AddMessage(msg); -- Also display it in the "error text" area of the screen.
        PlaySoundFile([[Interface\AddOns\FuckingRemember\alert.ogg]]);

        return true; -- Found!
    end
end

-- Localized names for Shattrath City, extracted from LibBabble-Zone-3.0.
-- NOTE: "select(6, GetMapZones(3))" works too, but would break if map offsets ever differ.
local GAME_LOCALE = GetLocale();
local shattrathName = 'Shattrath City'; -- Default. Intended for "enUS" and "enGB".
local L = {
    deDE = 'Shattrath',
    frFR = 'Shattrath',
    zhCN = '沙塔斯城',
    zhTW = '撒塔斯城',
    koKR = '샤트라스',
    esES = 'Ciudad de Shattrath',
    esMX = 'Ciudad de Shattrath',
    ruRU = 'Шаттрат',
}
if (L[GAME_LOCALE]) then shattrathName = L[GAME_LOCALE]; end
L = nil;

-- Set up an "automatic scan" trigger which happens every time the player enters Shattrath City.
-- NOTE: Only reacts to broad changes like entering/leaving a major city or zone;
-- doesn't react to mere subzone changes (that's what "ZONE_CHANGED" is for).
local lastAlert;
FuckingRemember:RegisterEvent('ZONE_CHANGED_NEW_AREA');
FuckingRemember:SetScript('OnEvent', function(self, event, ...)
    -- Only perform scan when the player ENTERS "Shattrath City".
    if (GetRealZoneText() ~= shattrathName) then return; end

    -- Don't allow another scan/potential alert shortly after a previous alert. Prevents fluttering when traveling
    -- outside Shattrath through the parts where you alternate between being in Shattrath or Terokkar several times.
    if (lastAlert and (GetTime() - lastAlert) < 10) then return; end

    -- Scan the player's dailies, and keep track of the last alert-time if an alert was triggered.
    local foundDailies = scanDailies();
    if (foundDailies) then
        lastAlert = GetTime();
    end
end);

-- Register a slash command to easily check the list anywhere (without having to enter Shattrath, hehe).
local messages = {'You are awesome!', 'Hug a cat today!', 'Do not eat the yellow snow.'};
local lastMsgIndex;
SlashCmdList['FUCKINGREMEMBER'] = function(msg)
    local foundDailies = scanDailies(); -- Triggers an alert if necessary.
    if (not foundDailies) then -- There are no completed dailies (nothing ready to deliver).
        local msgIndex;
        while (true) do -- Search for a random index which isn't the last-used message, to avoid repeats.
            msgIndex = math.random(1, #messages);
            if (msgIndex ~= lastMsgIndex) then break; end
        end
        local msg = messages[msgIndex]; -- :-)
        lastMsgIndex = msgIndex;
        Print(msg); -- Only in the chat-box, with no alert sounds.
    end
end
SLASH_FUCKINGREMEMBER1 = '/fuckingremember';
