-- SmartBiS_Engine.lua — in-game BiS solver. Recomputes best-in-slot live for CUSTOM stat weights,
-- using the bundled candidate pool (SmartBiS_Items/_Cands) + tables (SmartBiS_Affix/_Styles/_Prof/
-- _SetBonus). Public: SmartBiS_Solve(specKey, weights, phase, mode) -> { [gearSlot] = item }.

local Items, Affix, Styles, Prof, SetBonus  -- resolved lazily (load order safe)

-- weight lookup with hit/crit rating name-aliasing
local function weightFor(w, stat)
  if stat == "meleeHitRating" or stat == "rangedHitRating" or stat == "spellHitRating" then return w.hitRating or 0 end
  if stat == "meleeCritRating" or stat == "rangedCritRating" or stat == "spellCritRating" then return w.critRating or 0 end
  return w[stat] or 0
end

-- score a bare stat block — reused for items and set bonuses
local function scoreStats(st, w)
  local s = 0
  if st then for k, v in pairs(st) do if v ~= 0 then s = s + v * weightFor(w, k) end end end
  return s
end

-- weapon dps: (min+max)/2/speed, else 0
local function weaponDps(it)
  local d = it.dmg
  if d and d[3] and d[3] > 0 then return (d[1] + d[2]) / 2 / d[3] end
  return 0
end

-- per-item score. scoresWeapon adds weapon dps. Affix stats scored with the CoA rules:
-- spellDamage -> amt*spellPower, healingPower -> 0 (no CoA healer spec), else amt*weightFor.
local function scoreItem(it, w, scoresWeapon)
  local s = scoreStats(it.st, w)
  if it.afx and Affix[it.afx] then
    for k, v in pairs(Affix[it.afx]) do
      if v ~= 0 then
        if k == "spellDamage" then s = s + v * (w.spellPower or 0)
        elseif k == "healingPower" then -- 0 for CoA
        else s = s + v * weightFor(w, k) end
      end
    end
  end
  if scoresWeapon then
    local dps = weaponDps(it)
    if dps > 0 then
      local ww = (type(w.weaponDps) == "number" and w.weaponDps) or (type(w.attackPower) == "number" and 14 * w.attackPower) or 0
      s = s + dps * ww
    end
  end
  return s
end
SmartBiS_ScoreItem = scoreItem

-- set-bonus multiplier. gear = {slot=item}. base = sum of scores (passed in).
local function setBonusMult(gear, w, base)
  local counts = {}
  for _, it in pairs(gear) do if it and it.sk then counts[it.sk] = (counts[it.sk] or 0) + 1 end end
  local l, c = 0, 0
  for sk, n in pairs(counts) do
    local sb = SetBonus[sk]
    if sb and sb.thr then
      for _, t in ipairs(sb.thr) do
        if n >= t then
          local b = sb[t]
          if type(b) == "table" then l = l + scoreStats(b, w)
          elseif b == true then c = c + 0.04 end
        end
      end
    end
  end
  return (base > 0) and (c + l / base) or c
end

local ARMOR = { "Head", "Neck", "Shoulders", "Back", "Chest", "Wrists", "Hands", "Waist", "Legs", "Feet" }

-- resolve a candidate uid list to item tables, gated by phase (item.ph <= selectedPhase); on
-- Pre-Raid (phase 0) also exclude raid drops (it.rd) — pre-raid = dungeon/rep/craft/etc, no raids.
local CUR_PHASE = 5
local CUR_PRERAID = false
local CUR_LEVELING = false   -- leveling mode: gate by required level instead of phase
local CUR_MAXLEVEL = 60
local function itemsOf(uids)
  local out = {}
  if uids then for _, uid in ipairs(uids) do
    local it = Items[uid]
    if it then
      if CUR_LEVELING then
        if (it.rl or 0) <= CUR_MAXLEVEL then out[#out + 1] = it end
      elseif (it.ph or 0) <= CUR_PHASE and not (CUR_PRERAID and it.rd) then
        out[#out + 1] = it
      end
    end
  end end
  return out
end

local function sortByScore(list, w, sw)
  table.sort(list, function(a, b) return scoreItem(a, w, sw) > scoreItem(b, w, sw) end)
  return list
end

-- pick best 2 distinct-by-name from a ranked list
local function top2(ranked)
  local out, seen = {}, {}
  for _, it in ipairs(ranked) do
    if not seen[it.n] then seen[it.n] = true; out[#out + 1] = it; if #out == 2 then break end end
  end
  return out
end

-- total score of a full gear config (armor/accessory slots) incl set-bonus multiplier
local function totalScore(gear, w)
  local base = 0
  for _, it in pairs(gear) do if it then base = base + scoreItem(it, w, false) end end
  return base * (1 + setBonusMult(gear, w, base))
end

function SmartBiS_Solve(specKey, w, phase, mode, maxLevel)
  Items = SmartBiS_Items; Affix = SmartBiS_Affix; Styles = SmartBiS_Styles; Prof = SmartBiS_Prof; SetBonus = SmartBiS_SetBonus
  CUR_LEVELING = maxLevel ~= nil           -- leveling: use the level pool, gate by required level
  CUR_MAXLEVEL = maxLevel or 60
  CUR_PRERAID = (not CUR_LEVELING) and (phase or 5) == 0   -- Pre-Raid: phase-1 gear minus raid drops
  CUR_PHASE = phase or 5
  if CUR_PHASE < 1 then CUR_PHASE = 1 end   -- items are phase 1..5; Pre-Raid maps to phase 1 (+ no raid)
  local perSpec = SmartBiS_Cands[specKey]
  local cands = perSpec and (CUR_LEVELING and perSpec.lvl or (perSpec[mode or "pve"] or perSpec.pve or perSpec))
  if not cands then return nil end
  local ranked = {}
  for _, slot in ipairs(ARMOR) do ranked[slot] = sortByScore(itemsOf(cands[slot]), w, false) end
  local fingers = sortByScore(itemsOf(cands["Finger"]), w, false)
  local trinkets = sortByScore(itemsOf(cands["Trinket"]), w, false)

  -- baseline best-in-slot
  local base = {}
  for _, slot in ipairs(ARMOR) do base[slot] = ranked[slot][1] end
  local f2 = top2(fingers); base["Finger 1"] = f2[1]; base["Finger 2"] = f2[2]
  local t2 = top2(trinkets); base["Trinket 1"] = t2[1]; base["Trinket 2"] = t2[2]

  -- map tier sets -> best piece per gear slot (from candidates)
  local sets = {}
  local function consider(gslot, list)
    for _, it in ipairs(list) do
      if it.sk and SetBonus[it.sk] then
        sets[it.sk] = sets[it.sk] or {}
        if not sets[it.sk][gslot] or scoreItem(it, w, false) > scoreItem(sets[it.sk][gslot], w, false) then sets[it.sk][gslot] = it end
      end
    end
  end
  for _, slot in ipairs(ARMOR) do consider(slot, ranked[slot]) end
  consider("Finger 1", fingers); consider("Trinket 1", trinkets)

  local bestGear, bestScore = base, totalScore(base, w)
  -- complete a set of {sk=targetCount} jointly (cheapest slots first, one set per slot)
  local function complete(targets)
    local out, assigned, need = {}, {}, {}
    for s, it in pairs(base) do out[s] = it end
    for sk, t in pairs(targets) do need[sk] = t end
    local opts = {}
    for sk in pairs(targets) do
      for gslot, piece in pairs(sets[sk] or {}) do
        if base[gslot] then opts[#opts + 1] = { sk = sk, s = gslot, item = piece, cost = scoreItem(base[gslot], w, false) - scoreItem(piece, w, false) } end
      end
    end
    table.sort(opts, function(a, b) return a.cost < b.cost end)
    for _, o in ipairs(opts) do
      if need[o.sk] > 0 and not assigned[o.s] then out[o.s] = o.item; assigned[o.s] = true; need[o.sk] = need[o.sk] - 1 end
    end
    for _, t in pairs(need) do if t > 0 then return nil end end
    return out
  end
  local function try(targets)
    local g = complete(targets); if g then local v = totalScore(g, w); if v > bestScore then bestScore = v; bestGear = g end end
  end

  -- candidate sets (enough pieces), ranked by piece count
  local keys = {}
  for sk, pieces in pairs(sets) do
    local n = 0; for _ in pairs(pieces) do n = n + 1 end
    local thr = SetBonus[sk] and SetBonus[sk].thr
    if thr and n >= thr[1] then keys[#keys + 1] = { sk = sk, n = n } end
  end
  table.sort(keys, function(a, b) return a.n > b.n end)
  local function TH(sk) return SetBonus[sk].thr end
  for _, a in ipairs(keys) do for _, ta in ipairs(TH(a.sk)) do try({ [a.sk] = ta }) end end
  for i = 1, #keys do for j = i + 1, #keys do
    for _, ta in ipairs(TH(keys[i].sk)) do for _, tb in ipairs(TH(keys[j].sk)) do
      try({ [keys[i].sk] = ta, [keys[j].sk] = tb })
    end end
  end end

  -- repair duplicate unique in a pair
  local function repair(g, s1, s2, rk)
    if g[s1] and g[s2] and g[s1].n == g[s2].n then
      for _, it in ipairs(rk) do if it.n ~= g[s1].n then g[s2] = it; break end end
    end
  end
  repair(bestGear, "Finger 1", "Finger 2", fingers)
  repair(bestGear, "Trinket 1", "Trinket 2", trinkets)

  -- Ranged + weapons by baked style + proficiency
  local g = {}
  for s, it in pairs(bestGear) do g[s] = it end
  local ranged = sortByScore(itemsOf(cands["Ranged"]), w, true); if ranged[1] then g["Ranged"] = ranged[1] end
  local sw = true
  local allowed = Prof[specKey]
  local function typeOK(it) if not allowed or #allowed == 0 then return true end for _, ty in ipairs(allowed) do if it.ty == ty then return true end end return false end
  local function filt(list) local o = {}; for _, it in ipairs(list) do if typeOK(it) then o[#o + 1] = it end end; return o end
  local oneH = sortByScore(filt(itemsOf(cands["Main Hand"])), w, sw)
  do local more = sortByScore(filt(itemsOf(cands["One-Hand"])), w, sw); for _, it in ipairs(more) do oneH[#oneH + 1] = it end; sortByScore(oneH, w, sw) end
  local twoH = sortByScore(filt(itemsOf(cands["Two-Hand"])), w, sw)
  local shields = sortByScore(itemsOf(cands["Shield"]), w, sw)
  local offh = sortByScore(itemsOf(cands["Off Hand"]), w, sw)
  do local h = sortByScore(itemsOf(cands["Held In Off-hand"]), w, sw); for _, it in ipairs(h) do offh[#offh + 1] = it end; sortByScore(offh, w, sw) end
  local style = Styles[specKey] or { mh = "2H", oh = "2H" }
  if style.mh == "2H" then
    if twoH[1] then g["Main Hand"] = twoH[1]; g["Off Hand"] = twoH[1] end
  else
    if oneH[1] then g["Main Hand"] = oneH[1] end
    if style.oh == "shield" then if shields[1] then g["Off Hand"] = shields[1] end
    elseif style.oh == "offhand" then if offh[1] then g["Off Hand"] = offh[1] end
    elseif style.oh == "1H" then
      local mh = oneH[1]
      if mh and not mh.uq then g["Off Hand"] = mh
      else for _, it in ipairs(oneH) do if not mh or it.n ~= mh.n then g["Off Hand"] = it; break end end end
    end
  end
  return g
end
