-- SmartBiS.lua — shows Bisbeard's optimized loadout for a class|spec, with
-- PvE/PvP + phase selectors, auto-detected spec, "where it drops", and a
-- have/need check against your equipped gear. UI only; data in SmartBiS_DB.

local SLOT_ORDER = {
  "Head", "Neck", "Shoulders", "Back", "Chest", "Wrists", "Hands", "Waist",
  "Legs", "Feet", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2",
  "Main Hand", "Off Hand", "Ranged",
}
local PHASE_LABEL = { [0] = "Pre-Raid", [1] = "Phase 1", [2] = "Phase 2", [3] = "Phase 3", [4] = "Phase 4", [5] = "Phase 5" }
local INV_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }  -- for equipped scan

local function itemLink(id, name)
  return ("|cffffd100|Hitem:%d:0:0:0:0:0:0:0:0|h[%s]|h|r"):format(id, name)
end

-- specs present in the DB for a given class display name
local function specsForClass(className)
  local out = {}
  local cl = className and className:lower()
  for key in pairs(SmartBiS_DB or {}) do
    local class = key:match("^(.-)|")
    if class and (not cl or class:lower() == cl) then out[#out + 1] = key end
  end
  table.sort(out)
  return out
end

-- detect the player's class|spec key. UnitSpecAndIcon("player") returns the SPEC
-- NAME directly on CoA (e.g. "Invention"), or the CLASS name when the client
-- doesn't know the spec yet (needs a moment after login). Returns key, confident.
local function detectKey()
  local loc = UnitClass and UnitClass("player")           -- custom class display name
  if not loc then return nil, false end
  local classSpecs = specsForClass(loc)
  if #classSpecs == 0 then return nil, false end          -- class not in DB
  local specName
  local ok, spec = pcall(UnitSpecAndIcon, "player")
  if ok and type(spec) == "string" and spec ~= "" and spec ~= loc then specName = spec end
  if specName then
    for _, key in ipairs(classSpecs) do
      if key:lower() == (loc .. "|" .. specName):lower() then return key, true end
    end
  end
  return classSpecs[1], false                             -- fallback: first spec, not confident
end

-- what the player owns: equipped set + bag set
local function ownedSets()
  local equipped, bags = {}, {}
  for _, s in ipairs(INV_SLOTS) do
    local id = GetInventoryItemID("player", s)
    if id then equipped[id] = true end
  end
  for bag = 0, 4 do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local id = GetContainerItemID(bag, slot)
      if id then bags[id] = true end
    end
  end
  return equipped, bags
end

----------------------------------------------------------------------
local win
local manualSpec = false   -- set once the user picks a spec, to stop auto-override
local function ensureWindow()
  if win then return win end
  local f = CreateFrame("Frame", "SmartBiSFrame", UIParent)
  f:SetSize(490, 560); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "SmartBiSFrame")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14); f.title = title
  CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -6, -6)

  -- Spec selector (cycles the specs of the detected class)
  local spec = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  spec:SetSize(140, 22); spec:SetPoint("TOPLEFT", 16, -40)
  spec:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  spec:SetScript("OnClick", function(_, button)
    local key = SmartBiSSaved.spec
    local class = key and key:match("^(.-)|")
    local list = specsForClass(class)
    if #list < 2 then return end
    local idx = 1
    for i, k in ipairs(list) do if k == key then idx = i break end end
    idx = (button == "RightButton") and (idx - 1) or (idx + 1)
    if idx > #list then idx = 1 elseif idx < 1 then idx = #list end
    SmartBiSSaved.spec = list[idx]; manualSpec = true; SmartBiS_Refresh()
  end)
  f.specBtn = spec

  -- PvE / PvP toggle
  local mode = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  mode:SetSize(76, 22); mode:SetPoint("LEFT", spec, "RIGHT", 6, 0)
  mode:SetScript("OnClick", function()
    SmartBiSSaved.mode = (SmartBiSSaved.mode == "pvp") and "pve" or "pvp"; SmartBiS_Refresh()
  end)
  f.modeBtn = mode

  -- Phase selector
  local phase = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  phase:SetSize(104, 22); phase:SetPoint("LEFT", mode, "RIGHT", 6, 0)
  phase:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  phase:SetScript("OnClick", function(_, button)
    local p = SmartBiSSaved.phase or 0
    p = (button == "RightButton") and (p - 1) or (p + 1)
    if p > 5 then p = 0 elseif p < 0 then p = 5 end
    SmartBiSSaved.phase = p; SmartBiS_Refresh()
  end)
  f.phaseBtn = phase

  local body = CreateFrame("ScrollingMessageFrame", "SmartBiSBody", f)
  body:SetPoint("TOPLEFT", 18, -72); body:SetPoint("BOTTOMRIGHT", -18, 16)
  body:SetFontObject(GameFontHighlight); body:SetJustifyH("LEFT")
  body:SetFading(false); body:SetMaxLines(600); body:EnableMouseWheel(true)
  body:SetHyperlinksEnabled(true)
  body:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
  body:SetScript("OnHyperlinkEnter", function(self, link)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR"); GameTooltip:SetHyperlink(link); GameTooltip:Show()
  end)
  body:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
  body:SetScript("OnHyperlinkClick", function(_, link)
    if IsShiftKeyDown() and ChatEdit_GetActiveWindow() then ChatEdit_InsertLink(link) end
  end)
  f.body = body

  f:Hide()   -- start hidden; slash Shows before Refresh so lines render
  win = f
  return f
end

----------------------------------------------------------------------
function SmartBiS_Refresh()
  local f = ensureWindow()
  local key = SmartBiSSaved.spec
  local mode = SmartBiSSaved.mode or "pve"
  local phase = SmartBiSSaved.phase or 0
  f.modeBtn:SetText(mode == "pvp" and "PvP" or "PvE")
  f.phaseBtn:SetText(PHASE_LABEL[phase] or "?")   -- phases apply to PvP too
  f.specBtn:SetText(key and key:gsub("^.-|", "") or "Spec")

  local body = f.body; body:Clear()
  local data = key and SmartBiS_DB and SmartBiS_DB[key]
  if not data then
    f.title:SetText("SmartBiS")
    body:AddMessage("No spec detected. Use  |cff00ff00/sbis <Class>|<Spec>|r")
    body:AddMessage(" ")
    for _, s in ipairs(specsForClass(nil)) do body:AddMessage("  |cff00ff00" .. s .. "|r") end
    return
  end

  local col = (mode == "pvp") and "|cffff8888" or "|cff88ccff"
  f.title:SetText(key:gsub("|", "  |cffaaaaaa") .. "|r  " .. col .. (mode == "pvp" and "PvP · " or "") .. (PHASE_LABEL[phase] or "") .. "|r")

  local tbl = (mode == "pvp") and data.pvp or data.pve
  local slots = tbl and tbl[phase]
  if not slots then body:AddMessage("No data."); return end

  local equipped, bags = ownedSets()
  local equipN, ownN, total = 0, 0, 0
  for _, slot in ipairs(SLOT_ORDER) do
    local it = slots[slot]
    if it then
      total = total + 1
      local mark
      if equipped[it[1]] then mark = "|cff40ff40v|r"; equipN = equipN + 1; ownN = ownN + 1
      elseif bags[it[1]] then mark = "|cffffd000b|r"; ownN = ownN + 1
      else mark = "|cff555555-|r" end
      local set = (it[4] and it[4] ~= "") and ("  |cffdda0dd{" .. it[4] .. "}|r") or ""
      local ver = (it[3] and it[3] ~= "" and it[3] ~= "Unknown") and ("  |cff888888" .. it[3] .. "|r") or ""
      body:AddMessage(("%s |cffffd100%-10s|r %s%s%s"):format(mark, slot, itemLink(it[1], it[2]), ver, set))
      if it[6] and it[6] ~= "" then                                 -- recommended enchant
        local d = (it[7] and it[7] ~= "") and ("  |cff5a8a9c" .. it[7] .. "|r") or ""
        body:AddMessage("        |cff888888Ench|r |cff58c0e0" .. it[6] .. "|r" .. d)
      end
      if it[5] and it[5] ~= "" then
        body:AddMessage("        |cff707070> " .. it[5] .. "|r")   -- where it drops
      end
    end
  end
  body:AddMessage(" ")
  body:AddMessage(("|cffaaaaaaEquipped %d/%d  ·  Owned %d/%d    |r|cff40ff40v|r|cffaaaaaa equipped  |r|cffffd000b|r|cffaaaaaa bag|r"):format(equipN, total, ownN, total))
  for _ = 1, 60 do body:ScrollUp() end
end

local function toggleWindow()
  local f = ensureWindow()
  if f:IsShown() then f:Hide() else f:Show(); SmartBiS_Refresh() end   -- Show first so lines render
end

----------------------------------------------------------------------
-- Tooltip: flag any item that is BiS for the player's current spec.
----------------------------------------------------------------------
local bislookup, lookupKey = {}, nil
local function buildLookup(key)
  if key == lookupKey then return end
  lookupKey = key
  wipe(bislookup)
  local data = key and SmartBiS_DB and SmartBiS_DB[key]
  if not data then return end
  local function add(id, slot, p, pvp)
    local e = bislookup[id]
    if not e then e = { slot = slot, ph = {}, pvp = false }; bislookup[id] = e end
    if pvp then e.pvp = true else e.ph[p] = true end
  end
  if data.pve then
    for p = 0, 5 do local s = data.pve[p]; if s then for slot, it in pairs(s) do add(it[1], slot, p) end end end
  end
  if data.pvp then
    for p = 0, 5 do local s = data.pvp[p]; if s then for slot, it in pairs(s) do add(it[1], slot, nil, true) end end end
  end
end

local function tooltipInfo(e)
  local parts = {}
  for p = 0, 5 do if e.ph[p] then parts[#parts + 1] = PHASE_LABEL[p] end end
  if e.pvp then parts[#parts + 1] = "PvP" end
  return table.concat(parts, ", ")
end

local function onItemTooltip(tt)
  local _, link = tt:GetItem()
  if not link then return end
  local id = tonumber(link:match("item:(%d+)"))
  if not id then return end
  buildLookup(SmartBiSSaved and SmartBiSSaved.spec)
  local e = bislookup[id]
  if e then
    tt:AddLine("|cff00ccff*|r |cff00ccffSmartBiS BiS|r  |cffffd100" .. e.slot ..
      "|r  |cff888888" .. tooltipInfo(e) .. "|r")
    tt:Show()
  end
end
if GameTooltip then GameTooltip:HookScript("OnTooltipSetItem", onItemTooltip) end
if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", onItemTooltip) end

----------------------------------------------------------------------
SLASH_SMARTBIS1 = "/sbis"
SlashCmdList["SMARTBIS"] = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if msg ~= "" then
    local key = msg
    if not key:find("|") then
      local a, b = msg:match("^(%S+)%s+(.+)$"); if a and b then key = a .. "|" .. b end
    end
    if not (SmartBiS_DB and SmartBiS_DB[key]) then
      for k in pairs(SmartBiS_DB or {}) do if k:lower() == key:lower() then key = k break end end
    end
    if SmartBiS_DB and SmartBiS_DB[key] then SmartBiSSaved.spec = key; manualSpec = true
    else print("|cffff4444SmartBiS:|r unknown spec '" .. msg .. "'. Type /sbis to list.") end
    local f = ensureWindow(); f:Show(); SmartBiS_Refresh(); return
  end
  toggleWindow()
end

----------------------------------------------------------------------
-- pick up the current character's spec (UnitSpecAndIcon can lag a bit after login,
-- so retry). Won't clobber a spec the user manually chose this session.
local function autodetect()
  if manualSpec then return end
  local key, confident = detectKey()
  if not key then return end
  local savedClass = SmartBiSSaved.spec and SmartBiSSaved.spec:match("^(.-)|")
  local myClass = key:match("^(.-)|")
  if confident or not SmartBiSSaved.spec or savedClass ~= myClass then
    if SmartBiSSaved.spec ~= key then
      SmartBiSSaved.spec = key
      if win and win:IsShown() then SmartBiS_Refresh() end
    end
  end
end

-- Minimap button (self-contained, no LibDBIcon dependency)
local mbtn
local function updateMbtnPos()
  local a = math.rad(SmartBiSSaved.mbAngle or 220)
  mbtn:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end
local function createMinimapButton()
  if mbtn or not Minimap then return end
  local b = CreateFrame("Button", "SmartBiSMinimapButton", Minimap)
  b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp"); b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(19, 19); icon:SetPoint("CENTER"); icon:SetTexture("Interface\\Icons\\INV_Chest_Plate06")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetScript("OnClick", toggleWindow)
  b:SetScript("OnDragStart", function()
    b:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local px, py = GetCursorPosition(); px, py = px / scale, py / scale
      SmartBiSSaved.mbAngle = math.deg(math.atan2(py - my, px - mx))
      updateMbtnPos()
    end)
  end)
  b:SetScript("OnDragStop", function() b:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(b, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff00ccffSmartBiS|r")
    GameTooltip:AddLine("Click to open  ·  drag to move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  mbtn = b
  updateMbtnPos()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
  SmartBiSSaved = SmartBiSSaved or {}
  SmartBiSSaved.mode = SmartBiSSaved.mode or "pve"
  SmartBiSSaved.phase = SmartBiSSaved.phase or 0
  createMinimapButton()
  autodetect()
  if C_Timer and C_Timer.After then
    C_Timer.After(1.5, autodetect); C_Timer.After(4, autodetect)
  end
  if event == "PLAYER_LOGIN" then
    local n = 0; for _ in pairs(SmartBiS_DB or {}) do n = n + 1 end
    print(("|cff00ccffSmartBiS|r %d specs. |cff00ff00/sbis|r"):format(n))
  end
end)
