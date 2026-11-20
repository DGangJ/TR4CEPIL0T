-- ---------------------------------------------------------------- page 2: radio inputs and telemetry
local options = {
  { "Accent", COLOR, ACCENT_DEFAULT },   -- accent colour
  { "Alerts", BOOL, 1 },
  { "Lost", BOOL, 1 },
}

-- find a source by internal name; returns { id, label } or nil if the radio does not have it
local function find(name, label)
  local info = getFieldInfo and getFieldInfo(name)
  if info == nil or info.id == nil then return nil end
  return { id = info.id, key = name, label = label or string.upper(info.name or name) }
end

local function collect(list)
  local out, seen = {}, {}
  for _, n in ipairs(list) do
    local s = find(n[1], n[2])
    if s and not seen[s.id] then seen[s.id] = true; out[#out + 1] = s end
  end
  return out
end

local STICKS = { { "ail", "ROLL" }, { "ele", "PITCH" }, { "thr", "THR" }, { "rud", "YAW" } }
-- every pot / slider name used by EdgeTX colour radios; only those the radio has are shown
local POTS = { { "s1" }, { "s2" }, { "s3" }, { "s4" }, { "p1" }, { "p2" }, { "p3" }, { "6pos", "6POS" },
               { "ls", "LS" }, { "rs", "RS" }, { "sl1" }, { "sl2" }, { "ext1" }, { "ext2" } }
local GYROS = { { "tltx", "TLT X" }, { "tlty", "TLT Y" }, { "tiltx", "TLT X" }, { "tilty", "TLT Y" },
                { "gyrx", "GYR X" }, { "gyry", "GYR Y" } }
local SWITCHES = {}
for _, c in ipairs({ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p" }) do
  SWITCHES[#SWITCHES + 1] = { "s" .. c }
end
for i = 1, 6 do SWITCHES[#SWITCHES + 1] = { "sw" .. i } end
-- Number of positions: read from the radio's switch list when possible (detectPositions).
-- Fallback: each switch starts as 2-position and becomes 3-position when seen in the middle.
local THREE_POS = {}

-- The radio menus (and the switches() iterator, EdgeTX 2.6+) only list the positions a switch really has:
-- a 2POS switch has no middle position and a switch set to "None" has none. Counting the listed positions
-- of each switch ("SA" + up/middle/down) gives its type; switches with no positions are hidden.
local function detectPositions(list)
  if type(switches) ~= "function" then return list end
  local count = {}
  local ok = pcall(function()
    for _, name in switches() do
      if type(name) == "string" then
        local base = string.match(name, "^(%w+)")
        if base then base = string.upper(base); count[base] = (count[base] or 0) + 1 end
      end
    end
  end)
  if not ok then return list end
  local matched = 0
  for _, s in ipairs(list) do
    if count[string.upper(s.label)] or count[string.upper(s.key)] then matched = matched + 1 end
  end
  if matched == 0 then return list end          -- names not recognised: keep the fallback
  local out = {}
  for _, s in ipairs(list) do
    local n = count[string.upper(s.label)] or count[string.upper(s.key)] or 0
    if n >= 3 then THREE_POS[s.id] = true end
    if n >= 2 then s.fixed = true; out[#out + 1] = s end
  end
  return out
end

-- extra telemetry (ELRS / Crossfire + Betaflight): { sensor, label, format, short label }
local TELEM = {
  { "TPWR", "TX PWR MW", "%d", "PWR" },
  { "RSNR", "SNR DB", "%d", "SNR" },
  { "TQly", "DOWNLINK %", "%d", "DL %" },
  { "Curr", "CURRENT A", "%.1f", "AMP" },
  { "Capa", "USED MAH", "%d", "MAH" },
  { "CELL", "CELL V", "%.2f", "CELL" },   -- calculated: RxBt / cells
}

local function setup(widget, options)
  widget.options = options
  widget.mem = widget.mem or {}
  if widget.sticks == nil then
    widget.sticks = collect(STICKS)
    widget.pots = collect(POTS)
    widget.gyro = collect(GYROS)
    widget.sw = detectPositions(collect(SWITCHES))
    widget.scan = (#widget.gyro == 0) and 1 or nil   -- gyro: search by name if not found
  end
end

local function create(zone, options)
  local w = { zone = zone }
  setup(w, options)
  return w
end

local function update(widget, options)
  setup(widget, options)
end

-- search the source list for the gyro, 20 at a time to keep the load low
local function scanGyro(widget)
  if not widget.scan or not getSourceName then widget.scan = nil; return end
  local i = widget.scan
  for k = i, i + 19 do
    local ok, n = pcall(getSourceName, k)
    if ok and type(n) == "string" then
      local l = string.lower(n)
      if string.find(l, "tilt", 1, true) or string.find(l, "tlt", 1, true) or string.find(l, "gyr", 1, true) then
        if #widget.gyro < 2 then
          local lab = string.upper(string.gsub(n, "[^%w ]", ""))
          widget.gyro[#widget.gyro + 1] = { id = k, label = lab }
        end
      end
    end
  end
  widget.scan = i + 20
  if widget.scan > 400 or #widget.gyro >= 2 then widget.scan = nil end
end

local HALF = 10   -- cells on each side of the centre

-- centred dot bar: v from -1 to 1
local function bar(x, y, v, cp, cd, col)
  local mid = x + HALF * cp
  lcd.drawLine(x, y + math.floor(cd / 2), x + 2 * HALF * cp + cd, y + math.floor(cd / 2), DOTTED, SEP)
  lcd.drawFilledRectangle(mid, y - 2, cd, cd + 4, CENTER)
  local k = math.floor(clamp(v, -1, 1) * HALF + 0.5)
  if k == 0 then
    lcd.drawFilledRectangle(mid, y, cd, cd, HEAD)
    return
  end
  local s = (k > 0) and 1 or -1
  for i = s, k, s do
    lcd.drawFilledRectangle(mid + i * cp, y, cd, cd, (i == k) and HEAD or col)
  end
end

local function norm(id)
  local v = getValue(id)
  if type(v) ~= "number" then return 0 end
  return v / 1024
end

-- row: label, bar and percentage. Returns the next y
local function row(x, y, w, lh, label, v, cp, cd, col)
  lcd.drawText(x, y, label, SMLSIZE + LABEL)
  bar(x + 46, y + math.floor((lh - cd) / 2), v, cp, cd, col)
  lcd.drawText(x + w, y, string.format("%d", math.floor(v * 100 + 0.5)), SMLSIZE + RIGHT + VALUE)
  return y + lh + 4
end

local function header(x, y, lh, text)
  lcd.drawText(x, y, text, SMLSIZE + ORANGE)
  return y + lh + 4
end

local function refresh(widget, event, touchState)
  local z = widget.zone
  if event ~= nil then z = { x = 0, y = 0, w = LCD_W, h = LCD_H } end
  local o = widget.options
  ORANGE = (type(o.Accent) == "number") and o.Accent or ACCENT_DEFAULT   -- chosen accent colour
  lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, BG)
  local g, d, lh, blinkOff = frameSetup(z, o)
  if widget.scan then scanGyro(widget) end

  local sepY, live = drawTop(widget, z, o, blinkOff, g, lh)

  local compact = z.w < 400
  local sc = math.max(1, z.w / 480)                 -- extra scale on big screens (800x480)
  local cp = compact and 3 or math.max(3, g - 1)   -- bar cell pitch
  local cd = math.max(2, cp - 2)      -- size of each cell (~3 px)
  local yMax = z.y + z.h - lh - 2

  -- ---------- left column: sticks, pots, gyro
  local x0 = z.x + 12
  local w0 = math.floor(z.w * 0.48) - 16
  local y = sepY + 8
  local groups = { { "STICKS", widget.sticks, VALUE }, { "POTS", widget.pots, VALUE }, { "GYRO", widget.gyro, ORANGE } }
  for _, grp in ipairs(groups) do
    local list = grp[2]
    if #list > 0 and y <= yMax then
      y = header(x0, y, lh, grp[1])
      for _, s in ipairs(list) do
        if y > yMax then break end
        y = row(x0, y, w0, lh, s.label, norm(s.id), cp, cd, grp[3])
      end
      y = y + 2
    end
  end

  -- ---------- right column: switches and telemetry
  local x1 = z.x + math.floor(z.w * 0.52)
  local w1 = z.x + z.w - 12 - x1
  y = sepY + 8
  if #widget.sw > 0 then
    y = header(x1, y, lh, "SWITCHES")
    local perRow0 = (#widget.sw > 8 and not compact) and 4 or (compact and 3 or 4)
    local tileW = math.max(compact and 44 or 46, math.floor(w1 / perRow0))
    local perRow = math.max(1, math.floor(w1 / tileW))
    local dp = math.max(3, math.floor((lh + 2) / 3 * sc))   -- position dot pitch
    for i, s in ipairs(widget.sw) do
      local c = (i - 1) % perRow
      local tx = x1 + c * tileW
      local v = getValue(s.id)
      if type(v) ~= "number" then v = 0 end
      lcd.drawText(tx, y, s.label, SMLSIZE + LABEL)
      local dx = tx + math.floor(30 * sc)
      if not s.fixed and v > -300 and v < 300 then THREE_POS[s.id] = true end
      if not THREE_POS[s.id] then
        -- 2 positions: only the top and bottom dots
        local pos = (v < 0) and 1 or 3
        for _, p in ipairs({ 1, 3 }) do
          lcd.drawFilledRectangle(dx, y + (p - 1) * dp, dp - 1, dp - 1, (p == pos) and HEAD or SEP)
        end
      else
        local pos = 2
        if v < -300 then pos = 1 elseif v > 300 then pos = 3 end
        for p = 1, 3 do
          lcd.drawFilledRectangle(dx, y + (p - 1) * dp, dp - 1, dp - 1, (p == pos) and HEAD or SEP)
        end
      end
      if c == perRow - 1 or i == #widget.sw then y = y + 3 * dp + 6 end
    end
    y = y + 2
  end

  -- ---------- extra telemetry, in a 2 (or 3) column grid
  if y <= yMax then
    y = header(x1, y, lh, "TELEMETRY")
    local tg = math.max(3, g - 2)
    local td = math.max(2, tg - 1)
    local cols = compact and 3 or 2
    local colW = math.floor(w1 / cols)
    local rowH = lh + 3 + 5 * tg + 8
    local mem = widget.mem
    for i, t in ipairs(TELEM) do
      local c = (i - 1) % cols
      local tx = x1 + c * colW
      if y + rowH - 8 > z.y + z.h then break end
      local v
      if t[1] == "CELL" then
        local b = readTel("RxBt")
        if type(b) == "number" and b > 0 and mem.cells then v = b / mem.cells end
      else
        v = readTel(t[1])
        if type(v) ~= "number" then v = nil end
      end
      local txt, col = "--", DIMVAL
      if v then
        txt = string.format(t[3], (t[3] == "%d") and math.floor(v + 0.5) or v)
        col = live and VALUE or DIMVAL
        if live and t[1] == "CELL" then col = battCol(v) end
      end
      lcd.drawText(tx, y, compact and t[4] or t[2], SMLSIZE + LABEL)
      dotText(txt, tx, y + lh + 3, tg, td, col)
      if c == cols - 1 then y = y + rowH end
    end
  end
end

local function background(widget) end

return { name = "SQInputs", options = options, create = create, update = update,
         refresh = refresh, background = background }
