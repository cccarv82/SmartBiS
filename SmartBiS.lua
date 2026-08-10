-- SmartBiS.lua — optimized BiS loadout in-game as a two-column card grid.
-- UI only; data in SmartBiS_DB.

-- explicit column layout (user-defined)
local COL1 = { "Head", "Neck", "Shoulders", "Back", "Chest", "Wrists", "Main Hand", "Off Hand" }
local COL2 = { "Hands", "Waist", "Legs", "Feet", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Ranged" }

-- CoA phase → content: raids are cumulative.
local PHASE_LABEL = { [0] = "Pre-Raid", [1] = "P1: Zul'Gurub", [2] = "P2: Molten Core", [3] = "P3: Blackwing Lair", [4] = "P4: Ahn'Qiraj", [5] = "P5: Naxxramas", [6] = "Leveling" }
local LEVELING_PHASE = 6
local INV_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local Q = {
  Poor = "ff9d9d9d", Common = "ffffffff", Uncommon = "ff1eff00", Rare = "ff0070dd",
  Epic = "ffa335ee", Legendary = "ffff8000", Artifact = "ffe6cc80", Heirloom = "ff00ccff",
}
local QRGB = {
  Poor = { .61, .61, .61 }, Common = { .9, .9, .9 }, Uncommon = { .12, 1, 0 }, Rare = { 0, .44, .87 },
  Epic = { .64, .21, .93 }, Legendary = { 1, .5, 0 }, Artifact = { .9, .8, .5 }, Heirloom = { 0, .8, 1 },
}

-- SmartPVP theme
local T = {
  bg = { 0.055, 0.055, 0.070, 0.96 },
  card = { 0.10, 0.10, 0.13, 1 },
  cardHi = { 0.15, 0.15, 0.19, 1 },
  border = { 0.22, 0.22, 0.28, 1 },
  gold = { 1.00, 0.82, 0.00 },
  grey = { 0.55, 0.55, 0.60 },
}
local DARK_BD = { bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
local FLAT_BD = { bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } }

local function itemLink(id, name) return ("|Hitem:%d:0:0:0:0:0:0:0:0|h[%s]|h"):format(id, name) end
local function trunc(s, n) s = s or ""; if #s > n then return s:sub(1, n - 1) .. "…" end return s end
local function normIcon(s)
  if not s or s == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  if s:find("\\") then return s end
  return "Interface\\Icons\\" .. s
end

local function specsForClass(className)
  local out, cl = {}, className and className:lower()
  for key in pairs(SmartBiS_DB or {}) do
    local class = key:match("^(.-)|")
    if class and (not cl or class:lower() == cl) then out[#out + 1] = key end
  end
  table.sort(out)
  return out
end

local function detectKey()
  local loc = UnitClass and UnitClass("player")
  if not loc then return nil, false end
  local classSpecs = specsForClass(loc)
  if #classSpecs == 0 then return nil, false end
  local specName
  local ok, spec = pcall(UnitSpecAndIcon, "player")
  if ok and type(spec) == "string" and spec ~= "" and spec ~= loc then specName = spec end
  if specName then
    for _, key in ipairs(classSpecs) do
      if key:lower() == (loc .. "|" .. specName):lower() then return key, true end
    end
  end
  return classSpecs[1], false
end

local function ownedSets()
  local equipped, bags = {}, {}
  for _, s in ipairs(INV_SLOTS) do local id = GetInventoryItemID("player", s); if id then equipped[id] = true end end
  for bag = 0, 4 do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do local id = GetContainerItemID(bag, slot); if id then bags[id] = true end end
  end
  return equipped, bags
end

local function styleButton(b)
  b:SetBackdrop(FLAT_BD); b:SetBackdropColor(0.12, 0.12, 0.15, 1); b:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
  b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.txt:SetPoint("CENTER"); b.txt:SetTextColor(T.gold[1], T.gold[2], T.gold[3])
  b.SetText = function(self, s) self.txt:SetText(s) end
  b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.18, 0.18, 0.22, 1) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.12, 0.12, 0.15, 1) end)
  return b
end

-- Custom-weights recompute (M2): run the in-game engine and map its gear to card tuples.
-- Endgame only (candidate pool is all-phase, PvE). Returns {slot = {id,name,ver,set,source,...}} or nil.
local ENGINE_SLOTS = { "Head", "Neck", "Shoulders", "Back", "Chest", "Wrists", "Hands", "Waist", "Legs", "Feet", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Main Hand", "Off Hand", "Ranged" }
local function recomputeSlots(key, weights, phase, mode, maxLevel)
  if not (SmartBiS_Solve and SmartBiS_Cands and SmartBiS_Cands[key]) then return nil end
  local ok, gear = pcall(SmartBiS_Solve, key, weights, phase, mode, maxLevel)
  if not ok or type(gear) ~= "table" then return nil end
  local out = {}
  for _, slot in ipairs(ENGINE_SLOTS) do
    local it = gear[slot]
    if it then out[slot] = { it.id, it.n, "", it.set or "", it.src or "", "", "", it.q or "", it.ic or "" } end
  end
  return out
end

----------------------------------------------------------------------
-- Card widget (300x52)
----------------------------------------------------------------------
local CW, CH, GAP, TXTW = 330, 52, 6, 272
local function createCard(parent)
  local c = CreateFrame("Button", nil, parent)
  c:SetSize(CW, CH)
  c:SetBackdrop(FLAT_BD); c:SetBackdropColor(T.card[1], T.card[2], T.card[3], 1); c:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
  c.strip = c:CreateTexture(nil, "ARTWORK"); c.strip:SetPoint("TOPLEFT", 3, -3); c.strip:SetPoint("BOTTOMLEFT", 3, 3); c.strip:SetWidth(3)
  c.qb = c:CreateTexture(nil, "BORDER"); c.qb:SetPoint("LEFT", 9, 0); c.qb:SetSize(40, 40)
  c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetPoint("LEFT", 10, 0); c.icon:SetSize(38, 38); c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local function mkfs(font, y) local fs = c:CreateFontString(nil, "OVERLAY", font); fs:SetPoint("TOPLEFT", 54, y); fs:SetWidth(TXTW); fs:SetHeight(14); fs:SetJustifyH("LEFT"); if fs.SetWordWrap then fs:SetWordWrap(false) end return fs end
  c.name = mkfs("GameFontNormal", -6)
  c.sub = mkfs("GameFontNormalSmall", -23)
  c.ench = mkfs("GameFontNormalSmall", -37)
  c:SetScript("OnEnter", function(self)
    if not self.itemId then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.itemId)
    if self.enchName then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("|cff5fc0e8Enchant:|r " .. self.enchName .. ((self.enchDesc and self.enchDesc ~= "") and ("  |cff9fd8e8" .. self.enchDesc .. "|r") or ""))
    end
    GameTooltip:Show()
    self:SetBackdropColor(T.cardHi[1], T.cardHi[2], T.cardHi[3], 1)
  end)
  c:SetScript("OnLeave", function(self) GameTooltip:Hide(); self:SetBackdropColor(T.card[1], T.card[2], T.card[3], 1) end)
  c:SetScript("OnMouseUp", function(self)
    if self.itemId and IsShiftKeyDown() and ChatEdit_GetActiveWindow() then ChatEdit_InsertLink(itemLink(self.itemId, self.itemName)) end
  end)
  return c
end

local function updateCard(c, slot, it, eq, bag)
  if not it then
    c.itemId, c.enchName = nil, nil
    c.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot"); c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.qb:SetTexture(0.2, 0.2, 0.24); c.strip:SetTexture(0.25, 0.25, 0.3)
    c.name:SetText("|cff6a6a6a" .. slot .. "|r"); c.sub:SetText("|cff555555—|r"); c.ench:SetText("")
    c:Show(); return
  end
  c.itemId, c.itemName = it[1], it[2]
  c.enchName, c.enchDesc = (it[6] ~= "" and it[6]) or nil, it[7]
  c.icon:SetTexture(normIcon(it[9]))
  local qc, qr = Q[it[8]] or "ffffffff", QRGB[it[8]] or { .4, .4, .4 }
  c.qb:SetTexture(qr[1], qr[2], qr[3])
  local ver = (it[3] ~= "" and it[3] ~= "Unknown") and ("  |cff777777" .. it[3] .. "|r") or ""
  c.name:SetText("|cffb9a032" .. slot .. ":|r |c" .. qc .. trunc(it[2], 24) .. "|r" .. ver)
  c.sub:SetText(it[5] ~= "" and ("|cff808080" .. trunc(it[5], 40) .. "|r") or "|cff555555world drop|r")
  if it[6] and it[6] ~= "" then
    c.ench:SetText("|cff5fc0e8Ench|r |cff9fd8e8" .. trunc(it[6], 34) .. "|r")   -- name here, full effect on hover
  else
    c.ench:SetText("")
  end
  if eq[it[1]] then c.strip:SetTexture(0.15, 0.9, 0.15)
  elseif bag[it[1]] then c.strip:SetTexture(0.95, 0.75, 0.1)
  else c.strip:SetTexture(0.28, 0.28, 0.34) end
  c:Show()
end

----------------------------------------------------------------------
-- Stat-weights editor (M2): per-spec custom weights, saved in SmartBiSSaved.weights, with reset.
----------------------------------------------------------------------
local editor
-- canonical ordered list of every stat that appears in any spec's default weights (shown in full,
-- even when 0, so the user can weight anything). Computed once from SmartBiS_DefaultWeights.
local ALL_STATS
local function allStats()
  if ALL_STATS then return ALL_STATS end
  local seen = {}
  for _, w in pairs(SmartBiS_DefaultWeights or {}) do
    for k in pairs(w) do if k ~= "role" then seen[k] = true end end
  end
  ALL_STATS = {}
  for k in pairs(seen) do ALL_STATS[#ALL_STATS + 1] = k end
  table.sort(ALL_STATS)
  return ALL_STATS
end

local function populateEditor(key)
  local ed = editor; if not ed or not key then return end
  local def = (SmartBiS_DefaultWeights and SmartBiS_DefaultWeights[key]) or {}
  local cur = (SmartBiSSaved.weights and SmartBiSSaved.weights[key]) or def
  local stats = allStats()
  for _, r in ipairs(ed.rows) do r:Hide() end
  local isCustom = SmartBiSSaved.weights and SmartBiSSaved.weights[key] ~= nil
  ed.sub:SetText(key:gsub("^.-|", "") .. (isCustom and "  |cff00ff88(custom)|r" or "  |cff888888(default)|r"))
  local y = -56
  for i, stat in ipairs(stats) do
    local r = ed.rows[i]
    if not r then
      r = CreateFrame("Frame", nil, ed); r:SetSize(204, 20)
      r.lbl = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.lbl:SetPoint("LEFT", 6, 0); r.lbl:SetJustifyH("LEFT")
      local eb = CreateFrame("EditBox", nil, r)   -- themed (no default InputBoxTemplate look)
      eb:SetSize(58, 18); eb:SetPoint("RIGHT", -6, 0); eb:SetAutoFocus(false); eb:SetMaxLetters(8)
      eb:SetFontObject("GameFontHighlightSmall"); eb:SetJustifyH("CENTER"); eb:SetTextInsets(4, 4, 0, 0)
      eb:SetBackdrop(FLAT_BD); eb:SetBackdropColor(0.05, 0.05, 0.07, 1); eb:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
      eb:SetTextColor(T.gold[1], T.gold[2], T.gold[3])
      eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
      eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
      eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 1); self:HighlightText() end)
      eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1); self:HighlightText(0, 0) end)
      r.eb = eb; ed.rows[i] = r
    end
    r.stat = stat
    r.lbl:SetText("|cffcfcfcf" .. stat .. "|r")
    r.eb:SetText(tostring(cur[stat] or 0))
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", ed, "TOPLEFT", 14, y); r:Show()
    y = y - 21
  end
end

local function buildEditor(parent)
  if editor then return editor end
  local ed = CreateFrame("Frame", nil, parent)
  ed:SetSize(232, 634); ed:SetPoint("TOPLEFT", parent, "TOPRIGHT", 8, 0); ed:SetFrameStrata("DIALOG")
  ed:SetBackdrop(DARK_BD); ed:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], T.bg[4]); ed:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
  local h = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); h:SetPoint("TOP", 0, -14); h:SetText("Stat Weights"); h:SetTextColor(T.gold[1], T.gold[2], T.gold[3])
  ed.sub = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); ed.sub:SetPoint("TOP", 0, -36)
  ed.rows = {}
  local apply = styleButton(CreateFrame("Button", nil, ed)); apply:SetSize(100, 24); apply:SetPoint("BOTTOMLEFT", 12, 12); apply:SetText("Apply")
  apply:SetScript("OnClick", function()
    local key = SmartBiSSaved.spec; if not key then return end
    local w = {}
    for _, r in ipairs(ed.rows) do if r:IsShown() then w[r.stat] = tonumber(r.eb:GetText()) or 0 end end
    local def = (SmartBiS_DefaultWeights and SmartBiS_DefaultWeights[key]) or {}
    for k, v in pairs(def) do if k ~= "role" and w[k] == nil then w[k] = v end end
    SmartBiSSaved.weights = SmartBiSSaved.weights or {}; SmartBiSSaved.weights[key] = w
    populateEditor(key); SmartBiS_Refresh()
  end)
  local reset = styleButton(CreateFrame("Button", nil, ed)); reset:SetSize(100, 24); reset:SetPoint("BOTTOMRIGHT", -12, 12); reset:SetText("Default")
  reset:SetScript("OnClick", function()
    local key = SmartBiSSaved.spec; if not key then return end
    if SmartBiSSaved.weights then SmartBiSSaved.weights[key] = nil end
    populateEditor(key); SmartBiS_Refresh()
  end)
  ed:Hide()   -- start hidden; the Weights button toggles it (otherwise the first click just closes it)
  editor = ed
  return ed
end

----------------------------------------------------------------------
local win
local manualSpec = false
local function ensureWindow()
  if win then return win end
  local f = CreateFrame("Frame", "SmartBiSFrame", UIParent)
  f:SetSize(2 * CW + 3 * 14, 634); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
  f:SetBackdrop(DARK_BD); f:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], T.bg[4]); f:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "SmartBiSFrame")

  local brand = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  brand:SetPoint("TOPLEFT", 16, -12); brand:SetText("SmartBiS"); brand:SetTextColor(T.gold[1], T.gold[2], T.gold[3])
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -15); f.title = title

  local close = CreateFrame("Button", nil, f); close:SetSize(20, 20); close:SetPoint("TOPRIGHT", -8, -8)
  styleButton(close); close:SetText("x"); close:SetScript("OnClick", function() f:Hide() end)

  local wbtn = CreateFrame("Button", nil, f); wbtn:SetSize(72, 20); wbtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -6, 0)
  styleButton(wbtn); wbtn:SetText("Weights")
  wbtn:SetScript("OnClick", function()
    local ed = buildEditor(f)
    if ed:IsShown() then ed:Hide() else populateEditor(SmartBiSSaved.spec); ed:Show() end
  end)

  -- button group centered: total width 160+6+70+6+156 = 398, half = 199
  local spec = styleButton(CreateFrame("Button", nil, f)); spec:SetSize(160, 22); spec:SetPoint("TOPLEFT", f, "TOP", -199, -38)
  spec:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  spec:SetScript("OnClick", function(_, button)
    local key = SmartBiSSaved.spec
    local list = specsForClass(key and key:match("^(.-)|"))
    if #list < 2 then return end
    local idx = 1; for i, k in ipairs(list) do if k == key then idx = i break end end
    idx = (button == "RightButton") and (idx - 1) or (idx + 1)
    if idx > #list then idx = 1 elseif idx < 1 then idx = #list end
    SmartBiSSaved.spec = list[idx]; manualSpec = true; SmartBiS_Refresh()
  end)
  f.specBtn = spec

  local mode = styleButton(CreateFrame("Button", nil, f)); mode:SetSize(70, 22); mode:SetPoint("LEFT", spec, "RIGHT", 6, 0)
  mode:SetScript("OnClick", function() SmartBiSSaved.mode = (SmartBiSSaved.mode == "pvp") and "pve" or "pvp"; SmartBiS_Refresh() end)
  f.modeBtn = mode

  local phase = styleButton(CreateFrame("Button", nil, f)); phase:SetSize(156, 22); phase:SetPoint("LEFT", mode, "RIGHT", 6, 0)
  phase.txt:SetFontObject("GameFontNormalSmall")   -- longer phase labels (e.g. "P3: Blackwing Lair")
  phase:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  phase:SetScript("OnClick", function(_, button)
    local p = SmartBiSSaved.phase or 0
    p = (button == "RightButton") and (p - 1) or (p + 1)
    if p > 6 then p = 0 elseif p < 0 then p = 6 end
    SmartBiSSaved.phase = p; SmartBiS_Refresh()
  end)
  f.phaseBtn = phase

  f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.footer:SetPoint("BOTTOM", 0, 14); f.footer:SetTextColor(T.grey[1], T.grey[2], T.grey[3])

  f.cards = {}
  f:Hide(); win = f
  return f
end

----------------------------------------------------------------------
function SmartBiS_Refresh()
  local f = ensureWindow()
  local key = SmartBiSSaved.spec
  local mode = SmartBiSSaved.mode or "pve"
  local phase = SmartBiSSaved.phase or 0
  f.modeBtn:SetText(mode == "pvp" and "PvP" or "PvE")
  f.phaseBtn:SetText(PHASE_LABEL[phase] or "?")
  f.specBtn:SetText(key and key:gsub("^.-|", "") or "Spec")
  if editor and editor:IsShown() then populateEditor(key) end   -- keep the weights editor in sync with the spec

  for _, c in ipairs(f.cards) do c:Hide() end
  local data = key and SmartBiS_DB and SmartBiS_DB[key]
  if not data then f.title:SetText("SmartBiS"); f.footer:SetText("No spec — /sbis <Class>|<Spec>"); return end
  local col = (mode == "pvp") and "|cffff8888" or "|cff88ccff"
  f.title:SetText(key:gsub("|", "  |cffaaaaaa") .. "|r  " .. col .. (mode == "pvp" and "PvP · " or "") .. (PHASE_LABEL[phase] or "") .. "|r")

  local custom = SmartBiSSaved.weights and SmartBiSSaved.weights[key]
  local slots
  if phase == LEVELING_PHASE then
    -- Leveling: recompute the best gear usable at the character's CURRENT level (auto-detected), PvE.
    local lvl = (UnitLevel and UnitLevel("player")) or 60
    local w = custom or (SmartBiS_DefaultWeights and SmartBiS_DefaultWeights[key])
    if w then slots = recomputeSlots(key, w, nil, "pve", lvl) end
    f.title:SetText(key:gsub("|", "  |cffaaaaaa") .. "|r  |cff88ffaaLeveling · Lv " .. lvl .. "|r" .. (custom and "  |cff00ff88custom|r" or ""))
  else
    -- normal phases: baked DB, or a live recompute when custom weights are set
    local tbl = (mode == "pvp") and data.pvp or data.pve
    slots = tbl and tbl[phase]
    if custom then
      local rec = recomputeSlots(key, custom, phase, mode)
      if rec then
        slots = rec
        f.title:SetText(key:gsub("|", "  |cffaaaaaa") .. "|r  " .. col .. (mode == "pvp" and "PvP · " or "") .. (PHASE_LABEL[phase] or "") .. "|r  |cff00ff88custom|r")
      end
    end
  end

  if not slots then f.footer:SetText("No data."); return end

  -- a two-handed weapon fills both hands (Main Hand == Off Hand); show it once, blank the Off Hand
  if slots["Main Hand"] and slots["Off Hand"] and slots["Main Hand"][1] == slots["Off Hand"][1] then
    slots = setmetatable({ ["Off Hand"] = false }, { __index = slots })
  end

  local eq, bag = ownedSets()
  local eqN, ownN, total = 0, 0, 0
  local Y0 = -70
  local function column(list, x)
    for i, slot in ipairs(list) do
      local ci = (x == 14 and i or 8 + i)
      local card = f.cards[ci] or createCard(f); f.cards[ci] = card
      card:ClearAllPoints(); card:SetPoint("TOPLEFT", f, "TOPLEFT", x, Y0 - (i - 1) * (CH + GAP))
      local it = slots[slot]
      if it then
        total = total + 1
        if eq[it[1]] then eqN = eqN + 1; ownN = ownN + 1 elseif bag[it[1]] then ownN = ownN + 1 end
      end
      updateCard(card, slot, it, eq, bag)
    end
  end
  column(COL1, 14)
  column(COL2, 14 + CW + 14)
  f.footer:SetText(("|cffaaaaaaEquipped %d/%d · Owned %d/%d    |r|cff26e626\226\150\160|r|cffaaaaaa equip  |r|cfff2bf1a\226\150\160|r|cffaaaaaa bag  |r|cff474747\226\150\160|r|cffaaaaaa missing|r"):format(eqN, total, ownN, total))
end

----------------------------------------------------------------------
local function toggleWindow()
  local f = ensureWindow()
  if f:IsShown() then f:Hide() else f:Show(); SmartBiS_Refresh() end
end

-- Tooltip: flag any item that is BiS for the player's current spec.
local bislookup, lookupKey = {}, nil
local function buildLookup(key)
  if key == lookupKey then return end
  lookupKey = key; wipe(bislookup)
  local data = key and SmartBiS_DB and SmartBiS_DB[key]
  if not data then return end
  local function add(id, slot, p, pvp)
    local e = bislookup[id]; if not e then e = { slot = slot, ph = {}, pvp = false }; bislookup[id] = e end
    if pvp then e.pvp = true else e.ph[p] = true end
  end
  if data.pve then for p = 0, 5 do local s = data.pve[p]; if s then for slot, it in pairs(s) do add(it[1], slot, p) end end end end
  if data.pvp then for p = 0, 5 do local s = data.pvp[p]; if s then for slot, it in pairs(s) do add(it[1], slot, nil, true) end end end end
end
local function tooltipInfo(e)
  local parts = {}
  for p = 0, 5 do if e.ph[p] then parts[#parts + 1] = PHASE_LABEL[p] end end
  if e.pvp then parts[#parts + 1] = "PvP" end
  return table.concat(parts, ", ")
end
local function onItemTooltip(tt)
  local _, link = tt:GetItem(); if not link then return end
  local id = tonumber(link:match("item:(%d+)")); if not id then return end
  buildLookup(SmartBiSSaved and SmartBiSSaved.spec)
  local e = bislookup[id]
  if e then
    tt:AddLine("|cff00ccff\226\152\133 SmartBiS BiS|r  |cffffd100" .. e.slot .. "|r  |cff888888" .. tooltipInfo(e) .. "|r"); tt:Show()
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
    if not key:find("|") then local a, b = msg:match("^(%S+)%s+(.+)$"); if a and b then key = a .. "|" .. b end end
    if not (SmartBiS_DB and SmartBiS_DB[key]) then
      for k in pairs(SmartBiS_DB or {}) do if k:lower() == key:lower() then key = k break end end
    end
    if SmartBiS_DB and SmartBiS_DB[key] then SmartBiSSaved.spec = key; manualSpec = true
    else print("|cffff4444SmartBiS:|r unknown spec '" .. msg .. "'.") end
    local f = ensureWindow(); f:Show(); SmartBiS_Refresh(); return
  end
  toggleWindow()
end

----------------------------------------------------------------------
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
  icon:SetSize(19, 19); icon:SetPoint("CENTER"); icon:SetTexture("Interface\\Icons\\INV_Chest_Plate06"); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetScript("OnClick", toggleWindow)
  b:SetScript("OnDragStart", function()
    b:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter(); local scale = Minimap:GetEffectiveScale()
      local px, py = GetCursorPosition(); px, py = px / scale, py / scale
      SmartBiSSaved.mbAngle = math.deg(math.atan2(py - my, px - mx)); updateMbtnPos()
    end)
  end)
  b:SetScript("OnDragStop", function() b:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(b, "ANCHOR_LEFT"); GameTooltip:AddLine("|cff00ccffSmartBiS|r"); GameTooltip:AddLine("Click to open  ·  drag to move", 1, 1, 1); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  mbtn = b; updateMbtnPos()
end

----------------------------------------------------------------------
local function autodetect()   -- returns true when the spec is confidently resolved (stop retrying)
  if manualSpec then return true end
  local key, confident = detectKey()
  if not key then return false end
  local savedClass = SmartBiSSaved.spec and SmartBiSSaved.spec:match("^(.-)|")
  local myClass = key:match("^(.-)|")
  if (confident or not SmartBiSSaved.spec or savedClass ~= myClass) and SmartBiSSaved.spec ~= key then
    SmartBiSSaved.spec = key
    if win and win:IsShown() then SmartBiS_Refresh() end
  end
  return confident
end

-- The client often doesn't know the (custom) spec at login; UnitSpecAndIcon returns the class name
-- until it's ready. Retry every ~1.2s until we get a real spec (or give up after ~15s).
local function autodetectDriver(n)
  if autodetect() then return end
  n = (n or 0) + 1
  if n <= 12 and C_Timer and C_Timer.After then C_Timer.After(1.2, function() autodetectDriver(n) end) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("PLAYER_ENTERING_WORLD")
for _, e in ipairs({ "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  SmartBiSSaved = SmartBiSSaved or {}
  SmartBiSSaved.mode = SmartBiSSaved.mode or "pve"
  SmartBiSSaved.phase = SmartBiSSaved.phase or 0
  createMinimapButton()
  autodetectDriver(0)   -- persistent retry until the spec is known
  if event == "PLAYER_LOGIN" then
    local n = 0; for _ in pairs(SmartBiS_DB or {}) do n = n + 1 end
    print(("|cff00ccffSmartBiS|r %d specs. |cff00ff00/sbis|r"):format(n))
  end
end)
