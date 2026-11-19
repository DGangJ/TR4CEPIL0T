-- ---------------------------------------------------------------- page 1: gimbal trails
-- at most 5 options: EdgeTX up to 2.10 (e.g. some PA01) only keeps the first 5.
-- Colours come first so they are never lost. The trail length is now fixed (TRAIL_N).
local TRAIL_N = 24
local options = {
  { "Accent", COLOR, ACCENT_DEFAULT },   -- accent colour (date, headings, etc.)
  { "TrailCol", COLOR, TRAIL_DEFAULT },  -- stick trail colour
  { "StickMode", VALUE, 2, 1, 4 },       -- radio stick mode (1 to 4)
  { "Grid", BOOL, 1 },
  { "Alerts", BOOL, 1 },                 -- blinking alerts + LOST warning with the last values
}

local function setup(widget, options)
  widget.options = options
  local n = math.floor(clamp(options.Trail or TRAIL_N, 6, 48))
  widget.n = n
  local r, g, b = rgbOf(options.TrailCol or TRAIL_DEFAULT)
  widget.shades = makeShades(n, r, g, b)
  widget.headCol = headOf(r, g, b)
  widget.hx, widget.hy = {}, {}
  widget.head, widget.count, widget.last = 0, 0, 0
  widget.mem = widget.mem or {}
end

local function create(zone, options)
  local w = { zone = zone }
  setup(w, options)
  return w
end

local function update(widget, options)
  setup(widget, options)
end

local SAMPLE = 3   -- 10 ms ticks between trail samples
local function sample(widget)
  local now = getTime()
  if now - widget.last < SAMPLE then return end
  widget.last = now
  local m = MODES[clamp(math.floor(widget.options.StickMode or 2), 1, 4)]
  local h = widget.head % widget.n + 1
  widget.head = h
  widget.hx[h] = { stick(m[1]), stick(m[3]) }
  widget.hy[h] = { stick(m[2]), stick(m[4]) }
  if widget.count < widget.n then widget.count = widget.count + 1 end
end

-- faint grid: one dot every 4 cells inside the gimbal area
local function drawGrid(cx, cy, R, g)
  local step = 4
  local r = R - R % step
  for gy = -r, r, step do
    local py = cy + gy * g
    for gx = -r, r, step do lcd.drawFilledRectangle(cx + gx * g, py, 2, 2, GRID) end
  end
end

-- faint crosshair: dotted axes with ticks at the ends and halfway
local CROSS = lcd.RGB(36, 44, 48)
local function drawCross(cx, cy, R, g)
  local L = R * g
  lcd.drawLine(cx - L, cy, cx + L, cy, DOTTED, CROSS)
  lcd.drawLine(cx, cy - L, cx, cy + L, DOTTED, CROSS)
  local m = math.floor(R / 2) * g
  for _, t in ipairs({ -L, -m, m, L }) do
    lcd.drawFilledRectangle(cx + t - 1, cy - 3, 2, 7, CROSS)
    lcd.drawFilledRectangle(cx - 3, cy + t - 1, 7, 2, CROSS)
  end
end

-- d = trail dot, hd = current position dot
local function drawTrail(widget, gi, cx, cy, R, g, d, hd)
  local n, sh = widget.n, widget.shades
  drawCross(cx, cy, R, g)
  lcd.drawFilledRectangle(cx - 1, cy - 1, 3, 3, CENTER)
  for age = widget.count, 1, -1 do
    local idx = (widget.head - age) % n + 1
    local px = cx + math.floor(widget.hx[idx][gi] * R + 0.5) * g
    local py = cy - math.floor(widget.hy[idx][gi] * R + 0.5) * g
    if age == 1 then
      lcd.drawFilledRectangle(px - math.floor(hd / 2), py - math.floor(hd / 2), hd, hd, widget.headCol or HEAD)
    else
      lcd.drawFilledRectangle(px - math.floor(d / 2), py - math.floor(d / 2), d, d, sh[age])
    end
  end
end

-- ---------------------------------------------------------------- GPS: live position + last known position
-- The last valid fix is kept in memory and saved to the SD card (every 10 s while it changes, and at once
-- when telemetry is lost), so it survives a radio restart. File: <widget folder>/lastgps.txt
local GPS_FILE = "/WIDGETS/SQTRAIL/lastgps.txt"
local GPS_SAVE_TICKS = 1000          -- 10 s

local function gpsLoad(widget)
  widget.gps = { saved = false, lostSaved = false, t = -GPS_SAVE_TICKS }
  local ok, f = pcall(io.open, GPS_FILE, "r")
  if not ok or not f then return end
  local txt = io.read(f, 120) or ""
  io.close(f)
  local lat, lon = string.match(txt, "([%-%d%.]+),([%-%d%.]+)")
  lat, lon = tonumber(lat), tonumber(lon)
  if lat and lon and (lat ~= 0 or lon ~= 0) then
    widget.gps.lat, widget.gps.lon, widget.gps.fromFile = lat, lon, true
  end
end

local function gpsSave(widget)
  local p = widget.gps
  if not p.lat then return end
  local ok, f = pcall(io.open, GPS_FILE, "w")
  if not ok or not f then return end
  local dt = getDateTime and getDateTime()
  local stamp = dt and string.format("%04d-%02d-%02d %02d:%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min) or ""
  io.write(f, string.format("%.6f,%.6f,%s\n", p.lat, p.lon, stamp))
  io.close(f)
  p.saved = true
end

-- updates the stored position; returns live fix (table or nil) and satellite count (or nil)
local function gpsUpdate(widget, live)
  local p = widget.gps
  local g = readTel("GPS")
  local sats = readTel("Sats")
  if type(sats) ~= "number" then sats = nil end
  local fix = nil
  if live and type(g) == "table" and g.lat and g.lon and (g.lat ~= 0 or g.lon ~= 0) then fix = g end
  local now = getTime()
  if fix then
    if fix.lat ~= p.lat or fix.lon ~= p.lon then p.lat, p.lon, p.saved, p.fromFile = fix.lat, fix.lon, false, false end
    p.lostSaved = false
    if not p.saved and now - p.t >= GPS_SAVE_TICKS then p.t = now; gpsSave(widget) end
  elseif not live and p.lat and not p.fromFile and not p.lostSaved then
    gpsSave(widget)                   -- telemetry just dropped: save the last position immediately
    p.lostSaved = true
  end
  p.hasSensor = p.hasSensor or type(g) == "table" or sats ~= nil
  return fix, sats
end

-- centre block. States: no GPS sensor / flying (satellites only) / disarmed (coordinates) /
-- crash or telemetry lost (last coordinates in the accent colour) / radio just started (saved position)
local function drawGps(widget, z, ly, vy, g, lh, live, lostNow, disarmed, compact, blinkOff)
  local fix, sats = gpsUpdate(widget, live)
  local p = widget.gps
  local cx = z.x + math.floor(z.w / 2)
  local cp = compact and 2 or 3                      -- dot pitch of the coordinates
  local function coords(label, lcol, col, lat, lon)
    local a, b = string.format("%.6f", lat), string.format("%.6f", lon)
    local w = math.max(dotWidth(a, cp), dotWidth(b, cp))
    local x = cx - math.floor(w / 2)
    lcd.drawText(x, ly, label, SMLSIZE + lcol)
    dotText(a, x, vy - 3, cp, math.max(1, cp - 1), col)
    dotText(b, x, vy + 5 * cp + 3, cp, math.max(1, cp - 1), col)
  end
  if lostNow and p.lat then
    coords("GPS  LAST", ORANGE, ORANGE, p.lat, p.lon)
  elseif fix and disarmed then
    coords(sats and string.format("GPS  %d SATS", math.floor(sats)) or "GPS", LABEL, VALUE, fix.lat, fix.lon)
  elseif live and p.hasSensor then
    local n = string.format("%d", math.floor(sats or 0))
    local nw = dotWidth(n, g)
    local sw = lcd.sizeText("SATS", SMLSIZE) or 24
    local x = cx - math.floor((nw + 8 + sw) / 2)
    lcd.drawText(x, ly, "GPS", SMLSIZE + LABEL)
    dotText(n, x, vy, g, math.max(2, g - 1), ORANGE)
    lcd.drawText(x + nw + 8, vy + 5 * g - lh, "SATS", SMLSIZE + LABEL)
  elseif not live and p.lat then
    coords(p.fromFile and "GPS  SAVED" or "GPS  LAST", LABEL, DIMVAL, p.lat, p.lon)
  elseif lostNow then
    local t = "LOST"
    local x = cx - math.floor(dotWidth(t, g) / 2)
    lcd.drawText(x, ly, "TELEMETRY", SMLSIZE + LABEL)
    if not blinkOff then dotText(t, x, vy, g, math.max(2, g - 1), RED) end
  else
    local t = "NO GPS"
    local x = cx - math.floor(dotWidth(t, 4) / 2)
    lcd.drawText(x, ly, "GPS", SMLSIZE + LABEL)
    dotText(t, x, vy + 6, 4, 3, DIMVAL)
  end
end

-- ---------------------------------------------------------------- clock / timers (bottom right)
-- Auto: shows timer 1 while it is counting, otherwise date and time.
-- Full screen mode (double tap the widget): each tap on the bottom right cycles time -> T1 -> T2 -> time.
local function timerText(v)
  local neg = v < 0
  v = math.abs(math.floor(v))
  local m = math.floor(v / 60)
  if m > 99 then m = 99 end
  return (neg and "-" or "") .. string.format("%02d:%02d", m, v % 60)
end

local function timerState(widget, i)
  local t = model.getTimer and model.getTimer(i)
  if not t then return nil end
  widget.tm = widget.tm or {}
  local s = widget.tm[i] or { v = t.value, at = 0 }
  local now = getTime()
  if t.value ~= s.v then s.v, s.at = t.value, now end
  widget.tm[i] = s
  return t, (now - s.at) < 150          -- running = value changed in the last 1.5 s
end

local function drawClock(widget, z, ly, vy, g, bd)
  local t1, run1 = timerState(widget, 0)
  local mode = widget.clockMode                      -- nil = auto, 0 = time, 1 = T1, 2 = T2
  local show = mode or ((t1 and run1) and 1 or 0)
  widget.clockShown = show
  local right = z.x + z.w - 18
  if show == 0 then
    local clk = clockText()
    local x = right - dotWidth(clk, g)
    lcd.drawText(x, ly, "TIME", SMLSIZE + LABEL)
    local dte = dateText()
    dotText(dte, right - dotWidth(dte, 3), ly + 1, 3, 2, ORANGE)
    dotText(clk, x, vy, g, bd, VALUE)
  else
    local t = (show == 1) and t1 or model.getTimer(1)
    local val = t and t.value or 0
    local txt = timerText(val)
    local x = right - dotWidth(txt, g)
    local name = (t and t.name and t.name ~= "") and string.upper(t.name) or ((show == 1) and "FLIGHT" or "PACK")
    lcd.drawText(x, ly, name, SMLSIZE + LABEL)
    local tag = (show == 1) and "T1" or "T2"
    dotText(tag, right - dotWidth(tag, 3), ly + 1, 3, 2, ORANGE)
    dotText(txt, x, vy, g, bd, HEAD)
  end
end

-- tap on the bottom right (full screen mode) or ENTER: next clock state
local function clockTap(widget)
  local nxt = ((widget.clockShown or 0) + 1) % 3
  widget.clockMode = (nxt == 0) and nil or nxt
end

local function refresh(widget, event, touchState)
  local z = widget.zone
  if event ~= nil then z = { x = 0, y = 0, w = LCD_W, h = LCD_H } end
  sample(widget)
  if widget.gps == nil then gpsLoad(widget) end   -- last known GPS position from the SD card
  local o = widget.options
  ORANGE = (type(o.Accent) == "number") and o.Accent or ACCENT_DEFAULT   -- chosen accent colour
  lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, BG)
  local g, d, lh, blinkOff = frameSetup(z, o)

  local sepY, live, hadTel = drawTop(widget, z, o, blinkOff, g, lh)

  -- ---------- bottom: flight mode, GPS, date/time or timers
  local bg = g
  local bd = math.max(2, bg - 1)
  local vy = z.y + z.h - 5 * bg - 10
  local ly = vy - lh - 3

  local fm, disarmed = flightMode()
  local fcol = disarmed and LABEL or HEAD
  local fsafe = string.find(fm, "!", 1, true) ~= nil or fm == "FS" or fm == "RTH"
  if fsafe then fcol = RED end
  while #fm > 1 and dotWidth(fm, bg) > math.floor(z.w * 0.30) do fm = string.sub(fm, 1, #fm - 1) end
  lcd.drawText(z.x + 18, ly, disarmed and "MODE  DISARMED" or "MODE", SMLSIZE + LABEL)
  if not (fsafe and blinkOff) then dotText(fm, z.x + 18, vy, bg, bd, fcol) end

  -- centre: GPS (or the telemetry lost warning when there is no GPS)
  local lostNow = (o.Lost or o.Alerts) == 1 and (not live) and hadTel
  drawGps(widget, z, ly, vy, bg, lh, live, lostNow, disarmed, z.w < 400, blinkOff)

  -- right: date + time, or the timers
  if event ~= nil and event ~= 0 then
    if touchState and EVT_TOUCH_TAP and event == EVT_TOUCH_TAP then
      if touchState.x and touchState.x > z.x + z.w * 0.6 and touchState.y and touchState.y > ly - 20 then clockTap(widget) end
    elseif EVT_VIRTUAL_ENTER and event == EVT_VIRTUAL_ENTER then
      clockTap(widget)
    end
  end
  drawClock(widget, z, ly, vy, bg, bd)

  -- ---------- middle: grid and trails
  local bandTop = sepY + 2 * g
  local bandBot = ly - 2 * g
  local half = math.min(math.floor((bandBot - bandTop) / 2), math.floor(z.w / 4) - g * 2)
  local R = math.max(2, math.floor(half / g))
  local cy = bandTop + math.floor((bandBot - bandTop) / 2)
  local c1, c2 = z.x + math.floor(z.w * 0.27), z.x + math.floor(z.w * 0.73)
  if o.Grid == 1 then
    drawGrid(c1, cy, R, g)
    drawGrid(c2, cy, R, g)
  end
  local td, hd = g - 1, g + 4          -- bigger dots: ~5 px on the trail, ~10 px at the current position
  drawTrail(widget, 1, c1, cy, R, g, td, hd)
  drawTrail(widget, 2, c2, cy, R, g, td, hd)
end

local function background(widget)
  sample(widget)
end

return { name = "SQTrails", options = options, create = create, update = update,
         refresh = refresh, background = background }
