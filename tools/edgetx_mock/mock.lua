-- Minimal EdgeTX colour-radio API mock: runs the TR4CEPIL0T widgets on a PC (liblua5.4 via tools/lua54.py)
-- and records draw calls to OUT_FILE; tools/edgetx_mock/render.py renders them to PNG.
-- Globals from the caller: SCRIPT, OUT_FILE, LCD_W, LCD_H, RADIO (table), S (scenario)
local TICK = 0
function getTime() return TICK end
local function rgb565(r, g, b) return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3) end
SMLSIZE, MIDSIZE, RIGHT, CENTER_FLAG, DOTTED, SOLID, BOLD = 0x0100, 0x0200, 0x0004, 0x0008, 0x55, 0, 0x0010
COLOR, BOOL, VALUE, SOURCE, SWITCH, STRING = 1, 2, 3, 4, 5, 6
EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP = 100, 101
local OPS = {}
local function col(f) return (f >> 16) & 0xFFFF end
lcd = {
  RGB = function(r, g, b) return rgb565(r, g, b) << 16 end,
  drawFilledRectangle = function(x, y, w, h, f) OPS[#OPS + 1] = string.format("R %d %d %d %d %d", x, y, w, h, col(f or 0)) end,
  drawRectangle = function(x, y, w, h, f) OPS[#OPS + 1] = string.format("B %d %d %d %d %d", x, y, w, h, col(f or 0)) end,
  drawLine = function(x1, y1, x2, y2, p, f) OPS[#OPS + 1] = string.format("L %d %d %d %d %d", x1, y1, x2, y2, col(f or 0)) end,
  drawText = function(x, y, t, f)
    f = f or 0
    OPS[#OPS + 1] = string.format("T %d %d %d %d %d %s", x, y, col(f), (f & RIGHT) ~= 0 and 1 or 0, (f & MIDSIZE) ~= 0 and 1 or 0, tostring(t))
  end,
  sizeText = function(t, f) return #tostring(t) * 7, 13 end,
  exitFullScreen = function() end,
}

-- radio inputs
local SRC = {}       -- name -> { id, name, value }
local NEXT = 1
local function addSrc(key, label, v) SRC[key] = { id = NEXT, name = label, v = v }; NEXT = NEXT + 1 end
for k, v in pairs({ rud = 0, ele = 0, thr = 0, ail = 0 }) do addSrc(k, k, v) end
for _, p in ipairs(RADIO.pots) do addSrc(p[1], p[2], p[3]) end
for _, s in ipairs(RADIO.switches) do addSrc(s[1], string.upper(s[1]), s[3]) end
local BYID = {}
for k, s in pairs(SRC) do BYID[s.id] = s end

-- telemetry
local TEL = {
  RQly = 100, ["1RSS"] = -62, RxBt = 16.4, FM = S.fm or "ACRO", Sats = 9,
  GPS = { lat = 38.736946, lon = -9.142685 }, TPWR = 250, RSNR = 9, TQly = 100, Curr = 12.4, Capa = 356,
}
local function telLive() return S.live ~= false end

function getFieldInfo(n)
  local s = SRC[n]
  if s then return { id = s.id, name = s.name, desc = s.name } end
  if TEL[n] ~= nil then return { id = 1000 + #n, name = n } end
  return nil
end
function getValue(n)
  if type(n) == "number" then local s = BYID[n]; return s and s.v or 0 end
  if n == "tx-voltage" then return 7.9 end
  local s = SRC[n]; if s then return s.v end
  if TEL[n] ~= nil and telLive() then return TEL[n] end
  return 0
end
function getSourceValue(n)
  if TEL[n] == nil then return nil end
  if n == "GPS" and not S.gps then return nil end
  if n == "Sats" and not S.gps then return nil end
  return TEL[n], telLive()
end
function getSourceName(i) local s = BYID[i]; return s and s.name or nil end
function getDateTime() return { year = 2026, mon = 11, day = 20, hour = 14, min = 51, sec = 0 } end
function getGeneralSettings() return { battMin = 6.6, battMax = 8.4 } end
function getFlightMode() return 0, "" end
function getSwitchValue() return false end
function playTone() end
model = {
  getInfo = function() return { name = 'Drone 5"' } end,
  getTimer = function(i) return { value = (i == 0) and 157 or 312, name = "" } end,
  getModule = function() return { Type = 0 } end,
}

-- switch position list (switches() iterator): only available positions, like the radio menus
local POS = {}
for _, s in ipairs(RADIO.switches) do
  local n = string.upper(s[1])
  if s[2] == 3 then
    POS[#POS + 1] = n .. "\226\134\145"; POS[#POS + 1] = n .. "-"; POS[#POS + 1] = n .. "\226\134\147"
  elseif s[2] == 2 then
    POS[#POS + 1] = n .. "\226\134\145"; POS[#POS + 1] = n .. "\226\134\147"
  end
end
for i = 1, 8 do POS[#POS + 1] = string.format("L%02d", i) end
POS[#POS + 1] = "ON"
if not RADIO.noIterator then
  function switches()
    local i = 0
    return function() i = i + 1; if POS[i] then return i, POS[i] end end
  end
  function getSwitchName(i) return POS[i] end
end

-- load and run
local chunk = assert(loadfile(SCRIPT))
local W = chunk()
local opts = {}
for _, o in ipairs(W.options) do opts[o[1]] = o[3] end
local zone = { x = 0, y = 0, w = LCD_W, h = LCD_H }
local wd = W.create(zone, opts)
local function setStick(rx, ry, lx, ly) SRC.ail.v, SRC.ele.v, SRC.rud.v, SRC.thr.v = rx * 1024, ry * 1024, lx * 1024, ly * 1024 end
for step = 0, 24 do
  TICK = step * 3
  local t = step / 24
  setStick(0.6 - 0.3 * t, -0.9 + 1.6 * t * t, -0.9 + 1.4 * t, -0.2 + 0.9 * math.sin(t * 2.5))
  W.refresh(wd)
  for i = #OPS, 1, -1 do OPS[i] = nil end
end
-- move each switch once through the middle when the iterator is missing (observation fallback)
TICK = TICK + 3
W.refresh(wd, S.fullscreen and 0 or nil)
local f = assert(io.open(OUT_FILE, "w"))
f:write(table.concat(OPS, "\n"))
f:close()
