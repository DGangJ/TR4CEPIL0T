local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

-- ---------------------------------------------------------------- colours
local BG       = lcd.RGB(0, 0, 0)
local ORANGE   = lcd.RGB(255, 28, 40)    -- main colour
local AMBER    = lcd.RGB(255, 210, 0)    -- warning colour
local RED      = lcd.RGB(255, 50, 50)
local ACCENT_DEFAULT = ORANGE   -- default accent colour (change it in Widget Settings > Accent)
local LABEL    = lcd.RGB(120, 140, 150)
local VALUE    = lcd.RGB(170, 200, 210)
local DIMVAL   = lcd.RGB(70, 80, 85)
local HEAD     = lcd.RGB(210, 240, 245)
local CENTER   = lcd.RGB(45, 55, 60)
local GRID     = lcd.RGB(24, 30, 33)
local SEP      = lcd.RGB(35, 42, 46)

-- default trail colour (cyan) and conversion of an EdgeTX colour to R, G, B
local TRAIL_DEFAULT = lcd.RGB(130, 200, 210)
-- EdgeTX stores colours as RGB565 in the upper half of the value (bits 17-32)
local function rgbOf(c)
  if type(c) ~= "number" then return 130, 200, 210 end
  local v = math.floor(c / 65536) % 65536
  if v == 0 and c > 0 and c < 65536 then v = c end    -- safety: value already in RGB565
  local r = math.floor(v / 2048) % 32
  local g = math.floor(v / 32) % 64
  local b = v % 32
  return math.floor(r * 255 / 31 + 0.5), math.floor(g * 255 / 63 + 0.5), math.floor(b * 255 / 31 + 0.5)
end

-- trail shades, from newest (1) to oldest (n), based on colour r, g, b
local function makeShades(n, r, g, b)
  r, g, b = r or 130, g or 200, b or 210
  local t = {}
  for i = 1, n do
    local k = 1 - (i - 1) / math.max(1, n - 1)
    k = k * k
    t[i] = lcd.RGB(math.floor(14 + (r - 14) * k), math.floor(16 + (g - 16) * k), math.floor(18 + (b - 18) * k))
  end
  return t
end

-- current position colour: the trail colour lightened towards white
local function headOf(r, g, b)
  return lcd.RGB(math.floor(r + (255 - r) * 0.55), math.floor(g + (255 - g) * 0.55), math.floor(b + (255 - b) * 0.55))
end

-- ---------------------------------------------------------------- 3x5 dot-matrix font
local RAW = {
  ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "001", "001", "001" },
  ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
  A = { "010", "101", "111", "101", "101" }, B = { "110", "101", "110", "101", "110" },
  C = { "011", "100", "100", "100", "011" }, D = { "110", "101", "101", "101", "110" },
  E = { "111", "100", "110", "100", "111" }, F = { "111", "100", "110", "100", "100" },
  G = { "011", "100", "101", "101", "011" }, H = { "101", "101", "111", "101", "101" },
  I = { "111", "010", "010", "010", "111" }, J = { "001", "001", "001", "101", "010" },
  K = { "101", "101", "110", "101", "101" }, L = { "100", "100", "100", "100", "111" },
  M = { "101", "111", "111", "101", "101" }, N = { "110", "101", "101", "101", "101" },
  O = { "010", "101", "101", "101", "010" }, P = { "110", "101", "110", "100", "100" },
  Q = { "010", "101", "101", "110", "011" }, R = { "110", "101", "110", "101", "101" },
  S = { "011", "100", "010", "001", "110" }, T = { "111", "010", "010", "010", "010" },
  U = { "101", "101", "101", "101", "111" }, V = { "101", "101", "101", "101", "010" },
  W = { "101", "101", "111", "111", "101" }, X = { "101", "101", "010", "101", "101" },
  Y = { "101", "101", "010", "010", "010" }, Z = { "111", "001", "010", "100", "111" },
  ["-"] = { "000", "000", "111", "000", "000" }, ["%"] = { "101", "001", "010", "100", "101" },
  ["*"] = { "000", "101", "010", "101", "000" }, ['"'] = { "101", "101", "000", "000", "000" },
  ["/"] = { "001", "001", "010", "100", "100" }, ["+"] = { "000", "010", "111", "010", "000" },
  [" "] = { "00", "00", "00", "00", "00" },
  [":"] = { "0", "1", "0", "1", "0" }, ["."] = { "0", "0", "0", "0", "1" },
  ["#"] = { "011", "110", "111", "011", "110" },   -- lightning bolt (charging)
  ["!"] = { "1", "1", "1", "0", "1" }, ["'"] = { "1", "1", "0", "0", "0" },
}
local GLYPH = {}
for ch, rows in pairs(RAW) do
  local pts = {}
  for y = 1, 5 do
    local r = rows[y]
    for x = 1, #r do
      if string.sub(r, x, x) == "1" then pts[#pts + 1] = x - 1; pts[#pts + 1] = y - 1 end
    end
  end
  GLYPH[ch] = { w = #rows[1], pts = pts }
end
local SPACE = GLYPH[" "]

local function dotWidth(s, g)
  local w = 0
  for i = 1, #s do w = w + ((GLYPH[string.sub(s, i, i)] or SPACE).w + 1) * g end
  return math.max(0, w - g)
end

local function dotText(s, x, y, g, d, col)
  local cx = x
  for i = 1, #s do
    local c = GLYPH[string.sub(s, i, i)] or SPACE
    local p = c.pts
    for k = 1, #p, 2 do lcd.drawFilledRectangle(cx + p[k] * g, y + p[k + 1] * g, d, d, col) end
    cx = cx + (c.w + 1) * g
  end
end

-- ---------------------------------------------------------------- data reading
local MODES = {
  { "rud", "ele", "ail", "thr" },
  { "rud", "thr", "ail", "ele" },
  { "ail", "ele", "rud", "thr" },
  { "ail", "thr", "rud", "ele" },
}

local function stick(name)
  local v = getValue(name)
  if type(v) ~= "number" then return 0 end
  return clamp(v / 1024, -1, 1)
end

-- telemetry value + whether it is still arriving
local function readTel(name)
  if getSourceValue then
    local v, cur = getSourceValue(name)
    if v == nil then return nil, false end
    return v, cur ~= false
  end
  local v = getValue(name)
  if v == nil or v == 0 then return nil, false end
  return v, true
end

local battMin, battMax
local function txBattPct()
  if battMin == nil then
    local g = getGeneralSettings and getGeneralSettings()
    battMin = (g and g.battMin) or 6.6
    battMax = (g and g.battMax) or 8.4
    if battMax <= battMin then battMax = battMin + 1 end
  end
  local v = getValue("tx-voltage")
  if type(v) ~= "number" or v <= 0 then return nil end
  return clamp(math.floor((v - battMin) / (battMax - battMin) * 100 + 0.5), 0, 100), v
end

-- USB charging: EdgeTX does not expose this to Lua, so it is inferred from the battery voltage.
-- Samples every 5 s over 2 min: turns on when the voltage keeps rising,
-- turns off when it drops again (cable removed).
local CHG = { buf = {}, n = 0, last = -1000, on = false }
local CHG_N = 24
local function charging(v)
  local now = getTime()
  if now - CHG.last >= 500 then
    CHG.last = now
    CHG.n = CHG.n % CHG_N + 1
    CHG.buf[CHG.n] = v
    local mn, mx = v, v
    for i = 1, CHG_N do
      local b = CHG.buf[i]
      if b then
        if b < mn then mn = b end
        if b > mx then mx = b end
      end
    end
    local prev = CHG.buf[(CHG.n - 7) % CHG_N + 1]   -- ~30 s earlier
    if not CHG.on then
      if v - mn >= 0.06 and prev and v >= prev + 0.02 then CHG.on = true end
    elseif v < mx - 0.03 then
      CHG.on = false
      CHG.buf, CHG.n = { v }, 1
    end
  end
  return CHG.on
end

local function modelName()
  local info = model.getInfo and model.getInfo()
  local n = (info and info.name) or ""
  if n == "" then n = "MODEL" end
  return string.upper(n)
end

local function clockText()
  local dt = getDateTime and getDateTime()
  if not dt then return "--:--" end
  return string.format("%02d:%02d", dt.hour, dt.min)
end

local function dateText()
  local dt = getDateTime and getDateTime()
  if not dt then return "--.--" end
  return string.format("%02d.%02d", dt.mon, dt.day)
end

-- flight mode: FM sensor (Betaflight/INAV via CRSF) or, without it, the radio flight mode
-- Betaflight appends "*" while disarmed
local function flightMode()
  local v = readTel("FM")
  if type(v) == "string" and v ~= "" then
    local disarmed = string.find(v, "*", 1, true) ~= nil
    return string.upper((string.gsub(v, "%*", ""))), disarmed, true
  end
  local n, name = getFlightMode()
  if name and name ~= "" then return string.upper(name), false, false end
  return "FM" .. tostring(n or 0), false, false
end

-- ---------------------------------------------------------------- alert colours
local function lqCol(v)
  if v < 50 then return RED elseif v < 70 then return AMBER end
  return VALUE
end

local function rssiCol(v)
  if v < 0 then
    if v < -105 then return RED elseif v < -95 then return AMBER end
  else
    if v < 45 then return RED elseif v < 55 then return AMBER end
  end
  return VALUE
end

local function battCol(cell)
  if cell < 3.3 then return RED elseif cell < 3.5 then return AMBER end
  return VALUE
end

-- label + dot value; right = right-align at x. blinkOff = do not draw the value
local function item(x, y, lh, label, val, g, d, col, right, blinkOff)
  local w = dotWidth(val, g)
  local lw = lcd.sizeText(label, SMLSIZE) or 0
  local vx, lx = x, x
  if right then vx, lx = x - w, x - lw end
  lcd.drawText(lx, y, label, SMLSIZE + LABEL)
  if not blinkOff then dotText(val, vx, y + lh + 3, g, d, col) end
end

-- ---------------------------------------------------------------- top bar (shared)
-- model, LQ, RSSI, drone battery, radio battery. Returns: separator y, telemetry alive,
-- and whether telemetry was ever received (for the LOST warning)
local function drawTop(widget, z, o, blinkOff, g, lh)
  local useLost = (o.Lost or o.Alerts) == 1
  local compact = z.w < 400   -- small screens (PA01: 320x240): short labels
  local tg = math.max(3, g - 2)
  local td = math.max(2, tg - 1)

  -- ---------- telemetry
  local lq, lqCur = readTel("RQly")
  local live = type(lq) == "number" and lqCur and lq > 0
  local rssi = readTel("1RSS")
  if type(rssi) ~= "number" or rssi == 0 then rssi = readTel("RSSI") end
  local bat = readTel("RxBt")
  if type(bat) ~= "number" then bat = nil end
  local mem = widget.mem
  if not live then
    -- 10 s without telemetry (battery swap): detect the cell count again
    mem.lostAt = mem.lostAt or getTime()
    if getTime() - mem.lostAt > 1000 then mem.cells = nil end
  else
    mem.lostAt = nil
    mem.lq, mem.rssi, mem.bat, mem.has = lq, rssi, bat, true
    if bat and bat > 0 then
      local guess = math.max(1, math.ceil(bat / 4.35))
      if mem.cells == nil or guess > mem.cells then mem.cells = guess end
    end
  end
  -- no telemetry: with "Lost" on, show the last values in grey; otherwise dashes
  local showMem = (not live) and useLost and mem.has

  -- ---------- top
  local ty = z.y + 6
  local x = z.x + 12
  -- model: shrink the dots if the name is long
  local name = modelName()
  local P = compact and { 0.34, 0.49, 0.64 } or { 0.36, 0.525, 0.68 }   -- LQ, RSSI and battery columns
  local maxW = math.floor(z.w * P[1]) - (compact and 22 or 24)
  local mg = tg
  while mg > 2 and dotWidth(name, mg) > maxW do mg = mg - 1 end
  while #name > 1 and dotWidth(name, mg) > maxW do name = string.sub(name, 1, #name - 1) end
  item(x, ty, lh, "MODEL", name, mg, math.max(1, mg - 1), HEAD)

  -- LQ
  local v, col, alert
  if live then v, col = string.format("%d", math.floor(lq)), lqCol(lq)
  elseif showMem then v, col = string.format("%d", math.floor(mem.lq or 0)), DIMVAL
  else v, col = "--", DIMVAL end
  alert = live and col == RED
  item(z.x + math.floor(z.w * P[1]), ty, lh, compact and "LQ" or "LQ %", v, tg, td, col, false, alert and blinkOff)

  -- RSSI
  local r = live and rssi or (showMem and mem.rssi) or nil
  if type(r) == "number" and r ~= 0 then
    v = string.format("%d", math.floor(r))
    col = live and rssiCol(r) or DIMVAL
  else v, col = "--", DIMVAL end
  alert = live and col == RED
  item(z.x + math.floor(z.w * P[2]), ty, lh, compact and "RSSI" or "RSSI DBM", v, tg, td, col, false, alert and blinkOff)

  -- drone battery (volts; colour from the per-cell voltage)
  local b = live and bat or (showMem and mem.bat) or nil
  if type(b) == "number" and b > 0 then
    v = string.format("%.1fV", b)
    col = DIMVAL
    if live and mem.cells then col = battCol(b / mem.cells) end
  else v, col = "--", DIMVAL end
  alert = live and col == RED
  local blbl = mem.cells and string.format(compact and "%dS" or "DRONE %dS", mem.cells) or (compact and "QUAD" or "DRONE")
  item(z.x + math.floor(z.w * P[3]), ty, lh, blbl, v, tg, td, col, false, alert and blinkOff)

  -- radio battery
  local pct, tv = txBattPct()
  if pct then
    local chg = charging(tv)
    col = (pct < 30 and not chg) and RED or VALUE
    local ptxt = string.format("%d", pct)
    item(z.x + z.w - 12, ty, lh, chg and (compact and "CHG" or "USB CHG %") or (compact and "TX" or "RADIO %"), ptxt, tg, td, col, true,
         pct < 30 and not chg and blinkOff)
    -- pulsing accent bolt to the left of the percentage
    if chg and (getTime() % 100) < 70 then
      dotText("#", z.x + z.w - 12 - dotWidth(ptxt, tg) - 5 * tg, ty + lh + 3, tg, td, ORANGE)
    end
  end

  local sepY = ty + lh + 3 + 5 * tg + 8
  lcd.drawLine(z.x + 12, sepY, z.x + z.w - 13, sepY, DOTTED, SEP)


  return sepY, live, mem.has
end

-- per-frame values: grid, dot, small font height and alert blinking
local function frameSetup(z, o)
  -- dot pitch from the screen size: 480x320 -> 6, 480x272 -> 5, 320x240 -> 5, 800x480 -> 8 (capped)
  local g = math.min(8, math.max(3, math.floor(math.min(z.w, z.h) / 48)))
  local d = math.max(2, g - 2)
  local _, lh = lcd.sizeText("0", SMLSIZE)
  lh = lh or 12
  local blinkOff = (o.Alerts == 1) and (getTime() % 100) >= 60
  return g, d, lh, blinkOff
end

