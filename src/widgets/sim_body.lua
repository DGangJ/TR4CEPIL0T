-- ---------------------------------------------------------------- simulator page (for a "Sim Mode" model)
-- No telemetry or GPS needed. Top: model, RF state, session time, flights (arm count), radio battery.
-- Middle: gimbal trails with the value of each axis. Bottom: arm state, virtual pack timer, date and time.
-- At most 5 options (EdgeTX up to 2.10 only keeps the first 5); colours come first.
local TRAIL_N = 24
local options = {
  { "Accent", COLOR, ACCENT_DEFAULT },                                   -- accent colour
  { "TrailCol", COLOR, TRAIL_DEFAULT },                                  -- stick trail colour
  { "StickMode", VALUE, 2, 1, 4 },                                       -- radio stick mode (1 to 4)
  SWITCH and { "ArmSw", SWITCH, 0 } or { "ArmSw", SOURCE, 0 },           -- arming switch position (default: SA > 0)
  { "PackTime", VALUE, 4, 1, 15 },                                       -- virtual pack length in minutes
}

local AXIS_LABEL = { rud = "YAW", thr = "THR", ail = "ROLL", ele = "PITCH" }
local GREEN = lcd.RGB(80, 220, 120)

local function setup(widget, options)
  widget.options = options
  widget.n = TRAIL_N
  local r, g, b = rgbOf(options.TrailCol or TRAIL_DEFAULT)
  widget.shades = makeShades(TRAIL_N, r, g, b)
  widget.headCol = headOf(r, g, b)
  widget.hx, widget.hy = {}, {}
  widget.head, widget.count, widget.last = 0, 0, 0
  widget.t0 = widget.t0 or getTime()          -- session start
  widget.flights = widget.flights or 0
  widget.pack = widget.pack or (options.PackTime or 4) * 6000   -- remaining pack time in 10 ms ticks
end

local function create(zone, options)
  local w = { zone = zone }
  setup(w, options)
  return w
end

local function update(widget, options)
  local oldLen = widget.options and widget.options.PackTime
  setup(widget, options)
  if oldLen ~= options.PackTime then widget.pack = (options.PackTime or 4) * 6000 end
end

-- ---------------------------------------------------------------- trails (same as page 1)
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

local function drawGrid(cx, cy, R, g)
  local step = 4
  local r = R - R % step
  for gy = -r, r, step do
    local py = cy + gy * g
    for gx = -r, r, step do lcd.drawFilledRectangle(cx + gx * g, py, 2, 2, GRID) end
  end
end

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

-- ---------------------------------------------------------------- state helpers
-- RF is "off" when neither the internal nor the external module has a type set
local function rfOn()
  if not model.getModule then return nil end
  for i = 0, 1 do
    local m = model.getModule(i)
    if m and m.Type and m.Type ~= 0 then return true end
  end
  return false
end

local function isArmed(o)
  local sw = o.ArmSw
  if SWITCH and type(sw) == "number" and sw ~= 0 and getSwitchValue then return getSwitchValue(sw) == true end
  if not SWITCH and type(sw) == "number" and sw ~= 0 then
    local v = getValue(sw)
    return type(v) == "number" and v > 0
  end
  local v = getValue("sa")
  return type(v) == "number" and v > 0
end

local function mmss(sec)
  sec = math.max(0, math.floor(sec))
  local m = math.floor(sec / 60)
  if m > 99 then m = 99 end
  return string.format("%02d:%02d", m, sec % 60)
end

-- ---------------------------------------------------------------- refresh
local function refresh(widget, event, touchState)
  local z = widget.zone
  if event ~= nil then z = { x = 0, y = 0, w = LCD_W, h = LCD_H } end
  sample(widget)
  local o = widget.options
  ORANGE = (type(o.Accent) == "number") and o.Accent or ACCENT_DEFAULT
  lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, BG)
  local g, d, lh, blinkOff = frameSetup(z, { Alerts = 1 })
  local compact = z.w < 400
  local tg = math.max(3, g - 2)
  local td = math.max(2, tg - 1)
  local now = getTime()

  -- arming, flights and the virtual pack
  local armed = isArmed(o)
  local packLen = (o.PackTime or 4) * 6000
  if armed and not widget.wasArmed then
    widget.flights = widget.flights + 1
    if widget.packDone or widget.pack < packLen then widget.pack = packLen end   -- new arm = fresh pack
    widget.packDone, widget.warned = false, false
  end
  local dt = now - (widget.lastT or now)
  widget.lastT = now
  if armed and dt > 0 and dt < 100 then
    widget.pack = math.max(0, widget.pack - dt)
    if not widget.warned and widget.pack <= 3000 then widget.warned = true; if playTone then playTone(1500, 150, 0) end end
    if not widget.packDone and widget.pack == 0 then
      widget.packDone = true
      if playTone then playTone(2200, 200, 100); playTone(2200, 200, 0) end
    end
  end
  widget.wasArmed = armed

  -- ---------- top
  local ty = z.y + 6
  local name = modelName()
  local P = compact and { 0.36, 0.50, 0.70 } or { 0.40, 0.55, 0.75 }
  local maxW = math.floor(z.w * P[1]) - 24
  local mg = tg
  while mg > 2 and dotWidth(name, mg) > maxW do mg = mg - 1 end
  while #name > 1 and dotWidth(name, mg) > maxW do name = string.sub(name, 1, #name - 1) end
  item(z.x + 12, ty, lh, "MODEL", name, mg, math.max(1, mg - 1), HEAD)

  local rf = rfOn()
  if rf == nil then
    item(z.x + math.floor(z.w * P[1]), ty, lh, "RF", "--", tg, td, DIMVAL)
  elseif rf then
    item(z.x + math.floor(z.w * P[1]), ty, lh, "RF", "ON", tg, td, RED, false, blinkOff)   -- transmitting in sim mode
  else
    item(z.x + math.floor(z.w * P[1]), ty, lh, "RF", "OFF", tg, td, GREEN)
  end
  item(z.x + math.floor(z.w * P[2]), ty, lh, compact and "SESS" or "SESSION", mmss((now - widget.t0) / 100), tg, td, VALUE)
  item(z.x + math.floor(z.w * P[3]), ty, lh, compact and "FLT" or "FLIGHTS", string.format("%d", widget.flights), tg, td, ORANGE)

  local pct, tv = txBattPct()
  if pct then
    local chg = charging(tv)
    local col = (pct < 30 and not chg) and RED or VALUE
    local ptxt = string.format("%d", pct)
    item(z.x + z.w - 12, ty, lh, chg and (compact and "CHG" or "USB CHG %") or (compact and "TX" or "RADIO %"), ptxt, tg, td, col, true,
         pct < 30 and not chg and blinkOff)
    if chg and (now % 100) < 70 then
      dotText("#", z.x + z.w - 12 - dotWidth(ptxt, tg) - 5 * tg, ty + lh + 3, tg, td, ORANGE)
    end
  end
  local sepY = ty + lh + 3 + 5 * tg + 8
  lcd.drawLine(z.x + 12, sepY, z.x + z.w - 13, sepY, DOTTED, SEP)

  -- ---------- bottom: arm state, virtual pack, date and time
  local bg = g
  local bd = math.max(2, bg - 1)
  local vy = z.y + z.h - 5 * bg - 10
  local ly = vy - lh - 3

  local armTxt = armed and "ARMED" or "SAFE"
  lcd.drawText(z.x + 18, ly, "ARM", SMLSIZE + LABEL)
  dotText(armTxt, z.x + 18, vy, bg, bd, armed and ORANGE or DIMVAL)

  local pk = mmss(widget.pack / 100)
  local px = z.x + math.floor((z.w - dotWidth(pk, bg)) / 2)
  lcd.drawText(px, ly, string.format("PACK  %d:00", o.PackTime or 4), SMLSIZE + LABEL)
  local pcol = HEAD
  if widget.pack <= 3000 then pcol = AMBER end
  if widget.pack == 0 then pcol = RED end
  if not (widget.pack == 0 and blinkOff) then dotText(pk, px, vy, bg, bd, pcol) end

  local right = z.x + z.w - 18
  local clk = clockText()
  local kx = right - dotWidth(clk, bg)
  lcd.drawText(kx, ly, "TIME", SMLSIZE + LABEL)
  local dte = dateText()
  dotText(dte, right - dotWidth(dte, 3), ly + 1, 3, 2, ORANGE)
  dotText(clk, kx, vy, bg, bd, VALUE)

  -- ---------- middle: trails + axis values
  local bandTop = sepY + 2 * g
  local bandBot = ly - 2 * g - lh - 4
  local half = math.min(math.floor((bandBot - bandTop) / 2), math.floor(z.w / 4) - g * 2)
  local R = math.max(2, math.floor(half / g))
  local cy = bandTop + math.floor((bandBot - bandTop) / 2)
  local c1, c2 = z.x + math.floor(z.w * 0.27), z.x + math.floor(z.w * 0.73)
  drawGrid(c1, cy, R, g)
  drawGrid(c2, cy, R, g)
  local tdd, hd = g - 1, g + 4
  drawTrail(widget, 1, c1, cy, R, g, tdd, hd)
  drawTrail(widget, 2, c2, cy, R, g, tdd, hd)

  local m = MODES[clamp(math.floor(o.StickMode or 2), 1, 4)]
  local L = R * g
  local vyy = cy + L + 8
  for gi, cx in ipairs({ c1, c2 }) do
    local ax = { m[gi * 2 - 1], m[gi * 2] }
    for k = 1, 2 do
      local nm = ax[k]
      local x = cx - L + (k - 1) * (L + 6)
      local lab = AXIS_LABEL[nm] or string.upper(nm)
      lcd.drawText(x, vyy, lab, SMLSIZE + LABEL)
      lcd.drawText(x + (lcd.sizeText(lab, SMLSIZE) or 24) + 6, vyy, string.format("%d", math.floor(stick(nm) * 100 + 0.5)), SMLSIZE + VALUE)
    end
  end
end

local function background(widget)
  sample(widget)
end

return { name = "TPSim", options = options, create = create, update = update,
         refresh = refresh, background = background }
