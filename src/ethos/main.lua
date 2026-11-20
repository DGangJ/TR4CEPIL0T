-- TR4CEPIL0T for FrSky Ethos  (/scripts/tr4ce/main.lua)
-- Two widgets for a full screen layout:
--   TPTrails (key "tptrail"): gimbal trails, telemetry top bar, flight mode, GPS, time and timers
--   TPInputs (key "tpinput"): sticks, pots/sliders, switches, function switches, extra telemetry
-- Designed for 800x480 (X18RS / X20 family); the layout scales to the widget size.
-- Sticks, switches and their names are read from the radio, so it adapts to other Ethos radios.
--@CREDITS@

local DIR      = "SCRIPTS:/tr4ce/"
local GPS_FILE = DIR .. "lastgps.txt"
local TRAIL_N  = 24          -- samples per trail
local SAMPLE_S = 0.035       -- seconds between trail samples
local FRAME_S  = 0.05        -- minimum seconds between repaints while something moves

-- ---------------------------------------------------------------- helpers
local function K(...)        -- first defined global constant among the given names
  for _, n in ipairs({ ... }) do
    local v = _G[n]
    if v ~= nil then return v end
  end
  return nil
end
local T_RIGHT = K("TEXT_RIGHT", "RIGHT")
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function int(v) return math.floor(v + 0.5) end
local function fmtInt(v) return string.format("%d", int(v)) end
local function now() return os.clock() end

-- ---------------------------------------------------------------- colours (built on first use)
local C
local function colours()
  if C then return C end
  C = {
    BG = lcd.RGB(0, 0, 0), ACCENT = lcd.RGB(255, 84, 40), AMBER = lcd.RGB(255, 176, 0),
    RED = lcd.RGB(255, 50, 50), LABEL = lcd.RGB(120, 140, 150), VALUE = lcd.RGB(170, 200, 210),
    DIM = lcd.RGB(70, 80, 85), HEAD = lcd.RGB(210, 240, 245), GRID = lcd.RGB(24, 30, 33),
    SEP = lcd.RGB(35, 42, 46), CROSS = lcd.RGB(36, 44, 48), TRAIL = lcd.RGB(130, 200, 210),
    TRAILHEAD = lcd.RGB(203, 236, 240),
  }
  return C
end

-- Ethos colours are packed integers; the packing is found by probing lcd.RGB,
-- so the trail gradient can be built from any colour picked in the settings.
local PROBE
local function rgbOf(c)
  local ok, r, g, b = pcall(function()
    if not PROBE then
      local z = lcd.RGB(0, 0, 0)
      PROBE = {}
      for i, m in ipairs({ lcd.RGB(255, 0, 0), lcd.RGB(0, 255, 0), lcd.RGB(0, 0, 255) }) do
        local mask = m & ~z
        local shift, bits = 0, 0
        while mask ~= 0 and (mask >> shift) & 1 == 0 do shift = shift + 1 end
        while (mask >> (shift + bits)) & 1 == 1 do bits = bits + 1 end
        PROBE[i] = { mask = mask, shift = shift, max = (1 << bits) - 1 }
      end
    end
    local out = {}
    for i = 1, 3 do
      local p = PROBE[i]
      out[i] = p.max > 0 and int(((c & p.mask) >> p.shift) * 255 / p.max) or 0
    end
    return out[1], out[2], out[3]
  end)
  if ok and r then return r, g, b end
  return 130, 200, 210
end

local function makeShades(col)
  local r, g, b = rgbOf(col)
  local t = {}
  for i = 1, TRAIL_N do
    local k = 1 - (i - 1) / (TRAIL_N - 1)
    k = k * k
    t[i] = lcd.RGB(int(14 + (r - 14) * k), int(16 + (g - 16) * k), int(18 + (b - 18) * k))
  end
  local head = lcd.RGB(int(r + (255 - r) * 0.55), int(g + (255 - g) * 0.55), int(b + (255 - b) * 0.55))
  return t, head
end

-- ---------------------------------------------------------------- dot-matrix font (3x5)
--@RAW@
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
  lcd.color(col)
  local cx = x
  for i = 1, #s do
    local c = GLYPH[string.sub(s, i, i)] or SPACE
    local p = c.pts
    for k = 1, #p, 2 do lcd.drawFilledRectangle(cx + p[k] * g, y + p[k + 1] * g, d, d) end
    cx = cx + (c.w + 1) * g
  end
end

local function label(x, y, s, col, right)
  lcd.color(col)
  if right then lcd.drawText(x, y, s, T_RIGHT) else lcd.drawText(x, y, s) end
end

-- ---------------------------------------------------------------- sources
local function src(t)
  local ok, s = pcall(system.getSource, t)
  if ok then return s end
  return nil
end

local function val(s, opt)
  if not s then return nil end
  local ok, v
  if opt then ok, v = pcall(s.value, s, opt) else ok, v = pcall(s.value, s) end
  if ok then return v end
  return nil
end

-- value scaled to -1..1: uses the source's own maximum when available,
-- otherwise the largest value seen so far (Ethos ranges differ between source types)
local function norm(s, ref)
  local v = val(s)
  if type(v) == "number" then
    if not ref.max then
      local ok, m = pcall(s.maximum, s)
      if ok and type(m) == "number" and m > 0 then ref.max, ref.fixed = m, true else ref.max = 1 end
    end
    if not ref.fixed and math.abs(v) > ref.max then ref.max = math.abs(v) end
    return clamp(v / ref.max, -1, 1)
  end
  if s then                                       -- some switch sources only expose a state
    local ok, st = pcall(s.state, s)
    if ok and st ~= nil then return st and 1 or -1 end
  end
  return 0
end

-- candidate sensor names (Ethos CRSF/ELRS names first, EdgeTX-style names as fallback)
local SENSORS = {
  lq   = { "Rx Quality", "LQ", "Link Quality", "RQly" },
  rssi = { "Rx RSSI1", "RSSI 1", "Rx RSSI", "1RSS", "RSSI" },
  rssi2 = { "Rx RSSI2", "RSSI 2", "2RSS" },
  batt = { "Rx Batt", "Rx Battery", "RxBt", "Battery", "VFAS", "Voltage" },
  fm   = { "Flight mode", "Flight Mode", "FM", "Mode" },
  gps  = { "GPS" },
  sats = { "Satellites", "GPS Sats", "Sats", "GPS Satellites" },
  tpwr = { "Tx Power", "TPWR", "Power" },
  rsnr = { "Rx SNR", "RSNR", "SNR" },
  tqly = { "Tx Quality", "TQly" },
  curr = { "Current", "Curr" },
  capa = { "Consumption", "Capacity", "Capa", "Used" },
}

local TEL_CAT = K("CATEGORY_TELEMETRY_SENSOR")
local function findSensor(key)
  for _, n in ipairs(SENSORS[key]) do
    local s = src({ category = TEL_CAT, name = n })
    if s then return s end
  end
  return nil
end

-- shared telemetry state (one per script, used by both widgets)
local TEL = { s = {}, lastTry = -10, user = {} }
local function sensor(key)
  return TEL.user[key] or TEL.s[key]
end
local function gpsSources()
  local g = TEL.user.gps or TEL.s.gps
  TEL.lat, TEL.lon = nil, nil
  if g then
    local ok, nm = pcall(g.name, g)
    if ok and nm then
      TEL.lat = src({ category = TEL_CAT, name = nm, options = K("OPTION_LATITUDE") })
      TEL.lon = src({ category = TEL_CAT, name = nm, options = K("OPTION_LONGITUDE") })
    end
  end
end

local function refreshSensors()
  if now() - TEL.lastTry < 2 then return end
  TEL.lastTry = now()
  for key in pairs(SENSORS) do
    if not TEL.s[key] then TEL.s[key] = findSensor(key) end
  end
  if not TEL.lat then gpsSources() end
  if not TEL.active then
    TEL.active = src({ category = K("CATEGORY_SYSTEM_EVENT"),
                       member = K("SYSTEM_EVENT_TELEMETRY_ACTIVE", "TELEMETRY_ACTIVE") })
  end
  if not TEL.radio then
    TEL.radio = src({ category = K("CATEGORY_SYSTEM"), member = K("SYSTEM_MAIN_VOLTAGE", "MAIN_VOLTAGE") })
  end
end

local function telActive()
  if TEL.active then
    local ok, st = pcall(TEL.active.state, TEL.active)
    if ok and st ~= nil then return st end
  end
  return val(sensor("lq")) ~= nil
end

local vMin, vMax
local function radioPct()
  if not vMin then
    vMin, vMax = 6.6, 8.4
    if system.voltageRange then
      local ok, a, b = pcall(system.voltageRange)
      if ok and a and b and a < b then vMin, vMax = a, b end
    end
  end
  local v = val(TEL.radio)
  if type(v) ~= "number" or v <= 0 then return nil end
  return clamp(int((v - vMin) / (vMax - vMin) * 100), 0, 100)
end

local function flightMode()
  local s = sensor("fm")
  if s then
    local ok, v = pcall(s.stringValue, s)
    if not ok or type(v) ~= "string" or v == "" then v = val(s) end
    if type(v) == "string" and v ~= "" then
      local disarmed = string.find(v, "*", 1, true) ~= nil
      return string.upper((string.gsub(v, "%*", ""))), disarmed, true
    end
  end
  return "--", false, false
end

-- ---------------------------------------------------------------- alert colours
local function lqCol(v)
  if v < 50 then return C.RED elseif v < 70 then return C.AMBER end
  return C.VALUE
end
local function rssiCol(v)
  if v < 0 then
    if v < -105 then return C.RED elseif v < -95 then return C.AMBER end
  else
    if v < 45 then return C.RED elseif v < 55 then return C.AMBER end
  end
  return C.VALUE
end
local function battCol(cell)
  if cell < 3.3 then return C.RED elseif cell < 3.5 then return C.AMBER end
  return C.VALUE
end

-- ---------------------------------------------------------------- layout (scaled from 800x480)
local function layout(w)
  local s = math.min(w / 800, 1.4)
  local L = { w = w, s = s }
  L.tg = math.max(3, int(6 * s)); L.td = math.max(2, L.tg - 2)       -- top bar dots
  L.bg = math.max(4, int(8 * s)); L.bd = math.max(3, L.bg - 2)       -- big values
  L.sg = math.max(2, int(4 * s)); L.sd = math.max(2, L.sg - 1)       -- small (date, tags)
  L.font = (w >= 600) and FONT_S or FONT_XS
  L.lh = int(22 * s)                                                  -- label height
  L.pad = int(16 * s)
  return L
end

-- keeps the last telemetry values (shown dimmed when the link is lost); called from wakeup
local function updateMem(wd)
  local live = telActive()
  wd.live = live
  if not live then return end
  local m = wd.mem
  local lq, rssi, bt = val(sensor("lq")), val(sensor("rssi")), val(sensor("batt"))
  if type(rssi) == "number" and rssi == 0 then rssi = val(sensor("rssi2")) or rssi end
  if type(lq) == "number" then m.lq = lq end
  if type(rssi) == "number" then m.rssi = rssi end
  if type(bt) == "number" and bt > 0 then m.bt = bt end
  if m.lq or m.rssi or m.bt then m.has = true end
  local fm, dis, fromFC = flightMode()
  if fromFC then m.fm, m.dis = fm, dis end
end

-- ---------------------------------------------------------------- top bar (shared)
-- returns the y of the separator line
local function drawTop(wd, L)
  local o = wd.cfg
  local g, d, ty = L.tg, L.td, int(10 * L.s)
  local vy = ty + L.lh
  local live = wd.live
  local blinkOff = o.alerts and (math.floor(now() * 2) % 2 == 1)
  local lostCol = C.DIM
  local function item(x, lab, v, col, right, crit)
    label(x, ty, lab, C.LABEL, right)
    if crit and blinkOff then return end
    dotText(v, right and (x - dotWidth(v, g)) or x, vy, g, d, col)
  end
  local W = L.w
  lcd.font(L.font)
  local x1 = int(W * 0.375)
  local mname = string.upper(wd.model or "MODEL")
  while #mname > 1 and dotWidth(mname, g) > x1 - L.pad - 3 * g do mname = string.sub(mname, 1, -2) end
  item(L.pad, "MODEL", mname, C.HEAD)

  local m = wd.mem
  local x2, x3 = int(W * 0.525), int(W * 0.70)
  if m.lq then
    local c = live and lqCol(m.lq) or lostCol
    item(x1, "LQ %", fmtInt(m.lq), c, false, live and m.lq < 50)
  else item(x1, "LQ %", "--", C.DIM) end
  if m.rssi then
    local c = live and rssiCol(m.rssi) or lostCol
    item(x2, (m.rssi < 0) and "RSSI DBM" or "RSSI", fmtInt(m.rssi), c, false, live and c == C.RED)
  else item(x2, "RSSI", "--", C.DIM) end
  if m.bt then
    local cells = math.max(1, math.ceil(m.bt / 4.35))
    local cell = m.bt / cells
    local c = live and battCol(cell) or lostCol
    item(x3, "DRONE " .. cells .. "S", string.format("%.1fV", m.bt), c, false, live and cell < 3.3)
  else item(x3, "DRONE", "--", C.DIM) end
  local rp = radioPct()
  item(W - L.pad, "RADIO %", rp and fmtInt(rp) or "--", C.VALUE, true)

  local sep = vy + 5 * g + int(12 * L.s)
  lcd.color(C.SEP)
  for x = L.pad, W - L.pad, 3 do lcd.drawFilledRectangle(x, sep, 1, 1) end
  return sep, live, m.has
end

-- ---------------------------------------------------------------- settings (shared form helpers)
local MODE_CHOICES = { { "Auto", 0 }, { "Mode 1", 1 }, { "Mode 2", 2 }, { "Mode 3", 3 }, { "Mode 4", 4 } }

local function cfgDefaults(wd)
  colours()
  wd.cfg = wd.cfg or {}
  local o = wd.cfg
  if o.accent == nil then o.accent = C.ACCENT end
  if o.trail == nil then o.trail = C.TRAIL end
  if o.mode == nil then o.mode = 0 end
  if o.grid == nil then o.grid = true end
  if o.alerts == nil then o.alerts = true end
end

local USER_KEYS = { "lq", "rssi", "batt", "fm", "gps", "sats" }
local USER_LABELS = { lq = "Link quality sensor", rssi = "RSSI sensor", batt = "Drone battery sensor",
                      fm = "Flight mode sensor", gps = "GPS sensor", sats = "Satellites sensor" }

local function addSensorLines(wd)
  for _, k in ipairs(USER_KEYS) do
    local line = form.addLine(USER_LABELS[k] .. " (empty = auto)")
    form.addSourceField(line, nil, function() return wd.cfg["src_" .. k] end,
      function(v) wd.cfg["src_" .. k] = v end)
  end
end

local function applyUser(wd)
  for _, k in ipairs(USER_KEYS) do
    local s = wd.cfg["src_" .. k]
    local ok, nm = false, nil
    if s then ok, nm = pcall(s.name, s) end
    if ok and nm and nm ~= "" and nm ~= "---" then TEL.user[k] = s else TEL.user[k] = nil end
  end
  gpsSources()
end

local function readCfg(wd, keys)
  cfgDefaults(wd)
  for _, k in ipairs(keys) do
    local ok, v = pcall(storage.read, k)
    if ok and v ~= nil then wd.cfg[k] = v end
  end
end
local function writeCfg(wd, keys)
  for _, k in ipairs(keys) do pcall(storage.write, k, wd.cfg[k]) end
end

local function newWidget()
  colours()
  local wd = { mem = {}, last = 0, cfg = nil }
  cfgDefaults(wd)
  local ok, n = pcall(model.name)
  wd.model = ok and n or "MODEL"
  return wd
end

-- ================================================================ page 1: TPTrails
local MODES = {
  { "rud", "ele", "ail", "thr" },
  { "rud", "thr", "ail", "ele" },
  { "ail", "ele", "rud", "thr" },
  { "ail", "thr", "rud", "ele" },
}

-- sticks are found by name in the analog sources; fallback order Rud, Ele, Thr, Ail
local STICK_KEYS = { rud = { "rud", "yaw" }, ele = { "ele", "pitch" }, thr = { "thr" }, ail = { "ail", "roll" } }
local STICKS, ANALOGS
local function scanAnalogs()
  if STICKS then return end
  STICKS, ANALOGS = {}, {}
  local cat = K("CATEGORY_ANALOG")
  for i = 0, 31 do
    local s = src({ category = cat, member = i })
    if not s then break end
    local ok, nm = pcall(s.name, s)
    nm = ok and nm or ("A" .. i)
    local low, hit = string.lower(nm), nil
    for key, pats in pairs(STICK_KEYS) do
      for _, p in ipairs(pats) do
        if not STICKS[key] and string.find(low, p, 1, true) then hit = key end
      end
    end
    if hit then STICKS[hit] = s else ANALOGS[#ANALOGS + 1] = { s = s, name = nm } end
  end
  local order = { "rud", "ele", "thr", "ail" }
  local n = 0
  for _, k in ipairs(order) do if STICKS[k] then n = n + 1 end end
  if n == 0 and #ANALOGS >= 4 then
    for i, k in ipairs(order) do STICKS[k] = ANALOGS[1].s; table.remove(ANALOGS, 1) end
  end
end

local STICK_REF = { rud = {}, ele = {}, thr = {}, ail = {} }
local function stickVal(key)          -- -1 .. 1
  local s = STICKS[key]
  if not s then return 0 end
  local ref = STICK_REF[key]
  if not ref.max then                 -- sticks: source maximum, or the usual Ethos range
    local ok, m = pcall(s.maximum, s)
    ref.max, ref.fixed = (ok and type(m) == "number" and m > 0) and m or 1024, true
  end
  return norm(s, ref)
end

local function stickMode(wd)
  local m = wd.cfg.mode
  if m and m >= 1 and m <= 4 then return m end
  if system.getStickMode then
    local ok, v = pcall(system.getStickMode)
    if ok and type(v) == "number" and v >= 1 and v <= 4 then return int(v) end
  end
  return 2
end

local function trailSample(wd)
  local md = MODES[stickMode(wd)]
  local t = wd.trail
  t.i = t.i % TRAIL_N + 1
  local lx, ly, rx, ry = stickVal(md[1]), stickVal(md[2]), stickVal(md[3]), stickVal(md[4])
  t[1][t.i], t[2][t.i], t[3][t.i], t[4][t.i] = lx, ly, rx, ry
  -- still moving while the oldest sample differs from the newest
  local o = t.i % TRAIL_N + 1
  local moving = false
  for k = 1, 4 do
    local a = t[k][o]
    if a == nil or math.abs(a - t[k][t.i]) > 0.004 then moving = true end
  end
  return moving
end

-- GPS: last known position, saved to the SD card
local function gpsLoad(wd)
  wd.gps = { live = false }
  local f = io.open(GPS_FILE, "r")
  if not f then return end
  local s = f:read("a") or ""
  f:close()
  local la, lo, ts = string.match(s, "([%-%d%.]+),([%-%d%.]+),?([^\n]*)")
  if la then wd.gps.lat, wd.gps.lon, wd.gps.ts, wd.gps.saved = tonumber(la), tonumber(lo), ts, true end
end

local function gpsSave(wd)
  local g = wd.gps
  if not g.lat then return end
  local f = io.open(GPS_FILE, "w")
  if not f then return end
  f:write(string.format("%.6f,%.6f,%s", g.lat, g.lon, os.date("%Y-%m-%d %H:%M")))
  f:close()
  g.lastSave = now()
end

local function gpsUpdate(wd, live)
  local g = wd.gps
  local la, lo = val(TEL.lat), val(TEL.lon)
  if live and type(la) == "number" and type(lo) == "number" and (la ~= 0 or lo ~= 0) then
    local changed = la ~= g.lat or lo ~= g.lon
    g.lat, g.lon, g.live, g.saved, g.fix = la, lo, true, false, true
    if changed and now() - (g.lastSave or -100) > 10 then gpsSave(wd) end
  else
    if g.live and g.fix then gpsSave(wd) end
    g.live, g.fix = false, false
  end
end

local function timerText(v)
  local neg = v < 0
  v = math.abs(int(v))
  local s
  if v >= 3600 then s = string.format("%d:%02d:%02d", v // 3600, (v % 3600) // 60, v % 60)
  else s = string.format("%02d:%02d", v // 60, v % 60) end
  return neg and ("-" .. s) or s
end

local function getTimer(i)
  local ok, t = pcall(model.getTimer, i)
  if ok then return t end
  return nil
end
local function timerInfo(i)
  local t = getTimer(i)
  if not t then return nil end
  local okv, v = pcall(t.value, t)
  local okr, r = pcall(t.running, t)
  local okn, n = pcall(t.name, t)
  return (okv and type(v) == "number") and v or 0, okr and r, okn and n or nil
end

local function trailPaint(wd)
  local W, H = lcd.getWindowSize()
  if not wd.L or wd.L.w ~= W then wd.L = layout(W) end
  local L = wd.L
  local o = wd.cfg
  local accent = o.accent
  if wd.shadeFor ~= o.trail then wd.shades, wd.head = makeShades(o.trail); wd.shadeFor = o.trail end

  lcd.color(C.BG)
  lcd.drawFilledRectangle(0, 0, W, H)
  local sep, live, has = drawTop(wd, L)
  lcd.font(L.font)

  -- bottom line
  local g, d = L.bg, L.bd
  local vy = H - 5 * g - int(16 * L.s)
  local ly = vy - L.lh - int(2 * L.s)
  wd.clockZone = { x = int(W * 0.62), y = ly - 10 }

  local fm, disarmed = flightMode()
  local fmCol = disarmed and C.LABEL or C.HEAD
  if not live then
    if wd.mem.fm then fm, disarmed, fmCol = wd.mem.fm, wd.mem.dis, C.DIM else fm, fmCol = "----", C.DIM end
  end
  label(L.pad + int(8 * L.s), ly, disarmed and "MODE  DISARMED" or "MODE", C.LABEL)
  dotText(fm, L.pad + int(8 * L.s), vy, g, d + 1, fmCol)

  -- GPS (centre)
  local gp = wd.gps
  local lostNow = has and not live
  local sats = val(sensor("sats"))
  local hasGps = TEL.lat ~= nil
  if lostNow and gp.lat then
    local la, lo = string.format("%.6f", gp.lat), string.format("%.6f", gp.lon)
    local gx = int((W - math.max(dotWidth(la, L.sg), dotWidth(lo, L.sg))) / 2)
    label(gx, ly, "GPS  LAST", accent)
    dotText(la, gx, vy - int(4 * L.s), L.sg, L.sd, accent)
    dotText(lo, gx, vy + 5 * L.sg + int(4 * L.s), L.sg, L.sd, accent)
  elseif gp.fix and disarmed then
    local la, lo = string.format("%.6f", gp.lat), string.format("%.6f", gp.lon)
    local gx = int((W - math.max(dotWidth(la, L.sg), dotWidth(lo, L.sg))) / 2)
    label(gx, ly, type(sats) == "number" and ("GPS  " .. fmtInt(sats) .. " SATS") or "GPS", C.LABEL)
    dotText(la, gx, vy - int(4 * L.s), L.sg, L.sd, C.VALUE)
    dotText(lo, gx, vy + 5 * L.sg + int(4 * L.s), L.sg, L.sd, C.VALUE)
  elseif live and (hasGps or type(sats) == "number") then
    local n = type(sats) == "number" and fmtInt(sats) or "0"
    lcd.font(L.font)
    local sw = lcd.getTextSize("SATS")
    local gx = int((W - (dotWidth(n, g) + int(10 * L.s) + sw)) / 2)
    label(gx, ly, "GPS", C.LABEL)
    dotText(n, gx, vy, g, d + 1, accent)
    label(gx + dotWidth(n, g) + int(10 * L.s), vy + 5 * g - L.lh + int(4 * L.s), "SATS", C.LABEL)
  elseif gp.lat then
    local la, lo = string.format("%.6f", gp.lat), string.format("%.6f", gp.lon)
    local gx = int((W - math.max(dotWidth(la, L.sg), dotWidth(lo, L.sg))) / 2)
    label(gx, ly, gp.saved and "GPS  SAVED" or "GPS  LAST", C.LABEL)
    dotText(la, gx, vy - int(4 * L.s), L.sg, L.sd, C.DIM)
    dotText(lo, gx, vy + 5 * L.sg + int(4 * L.s), L.sg, L.sd, C.DIM)
  else
    local s = "NO GPS"
    local gx = int((W - dotWidth(s, L.tg)) / 2)
    label(gx, ly, "GPS", C.LABEL)
    dotText(s, gx, vy + int(8 * L.s), L.tg, L.td, C.DIM)
  end

  -- time / timers (right)
  local show = wd.clockMode
  if show == nil then
    local _, running = timerInfo(0)
    if running then show = 1 end
  end
  local rx = W - L.pad - int(8 * L.s)
  if show == 1 or show == 2 then
    local v, _, name = timerInfo(show - 1)
    local txt = timerText(v or 0)
    local kx = rx - dotWidth(txt, g)
    local nm = string.upper(name and name ~= "" and name or (show == 1 and "FLIGHT" or "PACK"))
    label(kx, ly, nm, C.LABEL)
    local tag = "T" .. show
    dotText(tag, rx - dotWidth(tag, L.sg), ly + int(3 * L.s), L.sg, L.sd, accent)
    dotText(txt, kx, vy, g, d + 1, C.HEAD)
  else
    local t = os.date("*t")
    local clk = string.format("%02d:%02d", t.hour, t.min)
    local kx = rx - dotWidth(clk, g)
    label(kx, ly, "TIME", C.LABEL)
    if lostNow and o.alerts then
      if math.floor(now() * 2) % 2 == 0 then
        dotText("LOST", rx - dotWidth("LOST", L.sg), ly + int(3 * L.s), L.sg, L.sd, C.RED)
      end
    else
      local date = string.format("%02d.%02d", t.month, t.day)
      dotText(date, rx - dotWidth(date, L.sg), ly + int(3 * L.s), L.sg, L.sd, accent)
    end
    dotText(clk, kx, vy, g, d + 1, C.VALUE)
  end

  -- trails
  local top, bot = sep + int(12 * L.s), ly - int(14 * L.s)
  local band = bot - top
  local tgp = math.max(3, int(8 * L.s))
  local R = math.max(4, (band // 2 - tgp) // tgp)
  local cy = top + band // 2
  local sh, hd = wd.shades, wd.head
  local dotS, headS = math.max(3, tgp - 1), tgp + 6
  local t = wd.trail
  for side = 1, 2 do
    local cx = int(W * (side == 1 and 0.27 or 0.73))
    local Lx = R * tgp
    if o.grid then
      local r = R - R % 4
      lcd.color(C.GRID)
      for gy = -r, r, 4 do
        for gx = -r, r, 4 do lcd.drawFilledRectangle(cx + gx * tgp, cy + gy * tgp, 3, 3) end
      end
    end
    lcd.color(C.CROSS)
    if lcd.pen and K("PEN_DOTTED") then lcd.pen(PEN_DOTTED) end
    lcd.drawLine(cx - Lx, cy, cx + Lx, cy)
    lcd.drawLine(cx, cy - Lx, cx, cy + Lx)
    if lcd.pen and K("PEN_SOLID") then lcd.pen(PEN_SOLID) end
    local xs, ys = t[side * 2 - 1], t[side * 2]
    for a = TRAIL_N, 1, -1 do                       -- a = age (1 = newest)
      local idx = (t.i - a) % TRAIL_N + 1
      local sx, sy = xs[idx], ys[idx]
      if sx then
        local px = cx + int(sx * R) * tgp
        local py = cy - int(sy * R) * tgp
        if a == 1 then
          lcd.color(hd)
          lcd.drawFilledRectangle(px - headS // 2, py - headS // 2, headS, headS)
        else
          lcd.color(sh[a])
          lcd.drawFilledRectangle(px - dotS // 2, py - dotS // 2, dotS, dotS)
        end
      end
    end
  end
end

local function trailWakeup(wd)
  refreshSensors()
  local t = now()
  local dirty = false
  if t - wd.lastSample >= SAMPLE_S then
    wd.lastSample = t
    if trailSample(wd) then dirty = true end
  end
  updateMem(wd)
  local live = wd.live
  gpsUpdate(wd, live)
  -- slow state (telemetry, clock, timers, blink): checked 4 times per second
  if t - wd.slow >= 0.25 then
    wd.slow = t
    local tm = os.date("*t")
    local v0 = timerInfo(0)
    local v1 = (wd.clockMode == 2) and timerInfo(1) or 0
    local fm = flightMode()
    local key = table.concat({ tostring(val(sensor("lq"))), tostring(val(sensor("rssi"))),
      tostring(val(sensor("batt"))), tostring(val(sensor("sats"))), fm, tostring(live),
      tm.min, tostring(v0), tostring(v1), tostring(radioPct()),
      tostring(wd.gps.lat), wd.cfg.alerts and (math.floor(t * 2) % 2) or 0 }, "|")
    if key ~= wd.slowKey then wd.slowKey = key; dirty = true end
  end
  if dirty and t - wd.last >= FRAME_S then
    wd.last = t
    lcd.invalidate()
  end
end

local function clockTap(wd)
  if wd.clockMode == nil then wd.clockMode = 0
  else wd.clockMode = wd.clockMode + 1 end
  if wd.clockMode > 2 then wd.clockMode = nil end
  wd.slowKey = nil
  lcd.invalidate()
end

local function trailEvent(wd, category, value, x, y)
  if category == EVT_TOUCH and value == K("TOUCH_END") and x and y and wd.clockZone then
    if x >= wd.clockZone.x and y >= wd.clockZone.y then clockTap(wd); return true end
  elseif category == EVT_KEY and value == K("KEY_ENTER_BREAK") then
    clockTap(wd); return true
  end
  return false
end

local TRAIL_KEYS = { "accent", "trail", "mode", "grid", "alerts",
                     "src_lq", "src_rssi", "src_batt", "src_fm", "src_gps", "src_sats" }

local function trailCreate()
  local wd = newWidget()
  wd.trail = { i = 0, {}, {}, {}, {} }
  wd.lastSample, wd.slow = 0, 0
  scanAnalogs()
  refreshSensors()
  gpsLoad(wd)
  applyUser(wd)
  return wd
end

local function trailConfigure(wd)
  local line = form.addLine("Accent colour")
  form.addColorField(line, nil, function() return wd.cfg.accent end, function(v) wd.cfg.accent = v end)
  line = form.addLine("Trail colour")
  form.addColorField(line, nil, function() return wd.cfg.trail end, function(v) wd.cfg.trail = v end)
  line = form.addLine("Stick mode")
  form.addChoiceField(line, nil, MODE_CHOICES, function() return wd.cfg.mode end, function(v) wd.cfg.mode = v end)
  line = form.addLine("Grid")
  form.addBooleanField(line, nil, function() return wd.cfg.grid end, function(v) wd.cfg.grid = v end)
  line = form.addLine("Alerts (blink critical values)")
  form.addBooleanField(line, nil, function() return wd.cfg.alerts end, function(v) wd.cfg.alerts = v end)
  addSensorLines(wd)
end

local function trailRead(wd) readCfg(wd, TRAIL_KEYS); applyUser(wd); wd.shadeFor = nil end
local function trailWrite(wd) writeCfg(wd, TRAIL_KEYS); applyUser(wd); wd.shadeFor = nil end

-- ================================================================ page 2: TPInputs
local SW, FSW
local function scanSwitches()
  if SW then return end
  SW, FSW = {}, {}
  local cat, pcat = K("CATEGORY_SWITCH"), K("CATEGORY_SWITCH_POSITION")
  -- positions per switch, counted from the switch position sources ("SA" + arrow / dash)
  local count = {}
  if pcat then
    for i = 0, 127 do
      local s = src({ category = pcat, member = i })
      if not s then break end
      local ok, nm = pcall(s.name, s)
      if ok and nm then
        local base = string.match(nm, "^([%w]+)")
        if base then count[base] = (count[base] or 0) + 1 end
      end
    end
  end
  for i = 0, 63 do
    local s = src({ category = cat, member = i })
    if not s then break end
    local ok, nm = pcall(s.name, s)
    nm = (ok and nm) or ("S" .. i)
    local n = count[nm]
    SW[#SW + 1] = { s = s, name = nm, pos = (n and n >= 3) and 3 or 2, known = n ~= nil }
  end
  local fcat = K("CATEGORY_FUNCTION_SWITCH")
  if fcat then
    for i = 0, 15 do
      local s = src({ category = fcat, member = i })
      if not s then break end
      local ok, nm = pcall(s.name, s)
      FSW[#FSW + 1] = { s = s, name = (ok and nm) or ("FS" .. (i + 1)) }
    end
  end
end

local function short(s, n)
  if #s > n then return string.sub(s, 1, n) end
  return s
end

local STICK_ROWS = { { "ail", "ROLL" }, { "ele", "PITCH" }, { "thr", "THR" }, { "rud", "YAW" } }
local TEL_ROWS = {
  { "tpwr", "TX PWR MW", "%d" }, { "rsnr", "SNR DB", "%d" }, { "tqly", "DOWNLINK %", "%d" },
  { "curr", "CURRENT A", "%.1f" }, { "capa", "USED MAH", "%d" }, { "cell", "CELL V", "%.2f" },
}

local function inputPaint(wd)
  local W, H = lcd.getWindowSize()
  if not wd.L or wd.L.w ~= W then wd.L = layout(W) end
  local L = wd.L
  local accent = wd.cfg.accent
  lcd.color(C.BG)
  lcd.drawFilledRectangle(0, 0, W, H)
  local sep = drawTop(wd, L)
  lcd.font(L.font)

  local s = L.s
  local x1, x2 = L.pad, int(W * 0.525)
  local y0 = sep + int(16 * s)
  local rowH = int(32 * s)
  local lbw, bw = int(90 * s), int(170 * s)
  local valX = x1 + lbw + bw + int(60 * s)

  local function bar(y, name, v)                 -- v in -1..1
    label(x1, y, short(name, 8), C.LABEL)
    local bx = x1 + lbw
    local mid = bx + bw // 2
    lcd.color(C.SEP)
    for i = 0, bw, 6 do lcd.drawFilledRectangle(bx + i, y + int(8 * s), 2, 2) end
    lcd.color(C.DIM)
    lcd.drawFilledRectangle(mid, y + int(3 * s), 2, int(12 * s))
    local n = int(math.abs(v) * bw / 2)
    lcd.color(C.VALUE)
    for i = 0, n - 4, 6 do
      local xx = (v > 0) and (mid + i + 3) or (mid - i - 5)
      lcd.drawFilledRectangle(xx, y + int(7 * s), 4, 4)
    end
    lcd.color(C.HEAD)
    lcd.drawFilledRectangle(((v > 0) and (mid + n) or (mid - n)) - 2, y + int(4 * s), 5, int(10 * s))
    label(valX, y, fmtInt(v * 100), C.VALUE, true)
  end

  -- left column: sticks, then pots / sliders
  local y = y0
  label(x1, y, "STICKS", accent); y = y + int(26 * s)
  for _, r in ipairs(STICK_ROWS) do bar(y, r[2], stickVal(r[1])); y = y + rowH end
  if #ANALOGS > 0 then
    y = y + int(14 * s)
    label(x1, y, "POTS / SLIDERS", accent); y = y + int(26 * s)
    for _, a in ipairs(ANALOGS) do
      if y + rowH > H then break end
      if not a.ref then
        a.ref = {}
        local ok, m = pcall(a.s.maximum, a.s)
        a.ref.max, a.ref.fixed = (ok and type(m) == "number" and m > 0) and m or 1024, true
      end
      bar(y, string.upper(a.name), norm(a.s, a.ref))
      y = y + rowH
    end
  end

  -- right column: switches
  y = y0
  label(x2, y, "SWITCHES", accent); y = y + int(26 * s)
  local cols = 4
  local cw = (W - L.pad - x2) // cols
  local sh = int(40 * s)
  local dot = math.max(4, int(6 * s))
  for i, sw in ipairs(SW) do
    local cx = x2 + ((i - 1) % cols) * cw
    local yy = y + ((i - 1) // cols) * sh
    sw.ref = sw.ref or {}
    local v = norm(sw.s, sw.ref)                                                -- -1 .. 1
    local p                                                                     -- 0 up, 1 mid, 2 down
    if v < -0.3 then p = 0 elseif v > 0.3 then p = 2 else p = 1 end
    if not sw.known and sw.pos == 2 and p == 1 and (sw.ref.max or 1) > 1 then sw.pos = 3 end   -- seen in the middle
    label(cx, yy + int(2 * s), short(string.upper(sw.name), 4), C.LABEL)
    local bx = cx + int(40 * s)
    if sw.pos == 3 then
      for k = 0, 2 do
        lcd.color(k == p and C.HEAD or C.SEP)
        lcd.drawFilledRectangle(bx, yy + k * (dot + 2), dot, dot)
      end
    else
      local on = (p == 2) and 1 or 0
      for k = 0, 1 do
        lcd.color(k == on and C.HEAD or C.SEP)
        lcd.drawFilledRectangle(bx, yy + int(2 * s) + k * (dot + 4), dot, dot)
      end
    end
  end
  y = y + ((#SW + cols - 1) // cols) * sh + int(8 * s)

  -- function switches
  if #FSW > 0 then
    local n = #FSW
    local fw = (W - L.pad - x2) // math.max(1, math.min(n, 6))
    for i, f in ipairs(FSW) do
      local cx = x2 + ((i - 1) % 6) * fw
      local yy = y + ((i - 1) // 6) * int(30 * s)
      local okst, st = pcall(f.s.state, f.s)
      local on = okst and st
      if not okst then local v = val(f.s); on = type(v) == "number" and v > 0 end
      label(cx, yy, short(string.upper(f.name), 4), C.LABEL)
      lcd.color(on and accent or C.SEP)
      lcd.drawFilledRectangle(cx + int(40 * s), yy + int(4 * s), int(10 * s), int(10 * s))
    end
    y = y + ((n + 5) // 6) * int(30 * s) + int(14 * s)
  end

  -- telemetry grid
  if y + int(26 * s) < H then
    label(x2, y, "TELEMETRY", accent); y = y + int(26 * s)
    local tc = (W >= 600) and 3 or 2
    local tw = (W - L.pad - x2) // tc
    local bt = val(sensor("batt"))
    for i, r in ipairs(TEL_ROWS) do
      local cx = x2 + ((i - 1) % tc) * tw
      local yy = y + ((i - 1) // tc) * int(80 * s)
      if yy + int(60 * s) > H then break end
      local v
      if r[1] == "cell" then
        if type(bt) == "number" and bt > 0 then v = bt / math.max(1, math.ceil(bt / 4.35)) end
      else v = val(sensor(r[1])) end
      label(cx, yy, r[2], C.LABEL)
      local txt = "--"
      if type(v) == "number" then
        txt = (r[3] == "%d") and fmtInt(v) or string.format(r[3], v)
      end
      dotText(txt, cx, yy + int(24 * s), L.tg + 1, L.td + 1, type(v) == "number" and C.VALUE or C.DIM)
    end
  end
end

local function inputWakeup(wd)
  refreshSensors()
  updateMem(wd)
  local t = now()
  if t - wd.last < 0.08 then return end
  local parts = {}
  for _, r in ipairs(STICK_ROWS) do parts[#parts + 1] = int(stickVal(r[1]) * 100) end
  for _, a in ipairs(ANALOGS) do parts[#parts + 1] = tostring(val(a.s)) end
  for _, sw in ipairs(SW) do
    local v = val(sw.s)
    if v == nil then local ok, st = pcall(sw.s.state, sw.s); v = ok and tostring(st) or "" end
    parts[#parts + 1] = tostring(v)
  end
  for _, f in ipairs(FSW) do parts[#parts + 1] = tostring(val(f.s)) end
  for _, r in ipairs(TEL_ROWS) do if r[1] ~= "cell" then parts[#parts + 1] = tostring(val(sensor(r[1]))) end end
  parts[#parts + 1] = tostring(val(sensor("lq"))); parts[#parts + 1] = tostring(val(sensor("rssi")))
  parts[#parts + 1] = tostring(val(sensor("batt"))); parts[#parts + 1] = tostring(telActive())
  parts[#parts + 1] = tostring(radioPct())
  if wd.cfg.alerts then parts[#parts + 1] = math.floor(t * 2) % 2 end
  local key = table.concat(parts, "|")
  if key ~= wd.key then
    wd.key = key
    wd.last = t
    lcd.invalidate()
  end
end

local INPUT_KEYS = { "accent", "alerts", "src_lq", "src_rssi", "src_batt", "src_fm", "src_gps", "src_sats" }

local function inputCreate()
  local wd = newWidget()
  scanAnalogs()
  scanSwitches()
  refreshSensors()
  applyUser(wd)
  return wd
end

local function inputConfigure(wd)
  local line = form.addLine("Accent colour")
  form.addColorField(line, nil, function() return wd.cfg.accent end, function(v) wd.cfg.accent = v end)
  line = form.addLine("Alerts (blink critical values)")
  form.addBooleanField(line, nil, function() return wd.cfg.alerts end, function(v) wd.cfg.alerts = v end)
  addSensorLines(wd)
end

local function inputRead(wd) readCfg(wd, INPUT_KEYS); applyUser(wd) end
local function inputWrite(wd) writeCfg(wd, INPUT_KEYS); applyUser(wd) end

-- ================================================================ registration
local function init()
  system.registerWidget({ key = "tptrail", name = "TPTrails", title = false,
    create = trailCreate, paint = trailPaint, wakeup = trailWakeup, event = trailEvent,
    configure = trailConfigure, read = trailRead, write = trailWrite })
  system.registerWidget({ key = "tpinput", name = "TPInputs", title = false,
    create = inputCreate, paint = inputPaint, wakeup = inputWakeup,
    configure = inputConfigure, read = inputRead, write = inputWrite })
end

return { init = init }
