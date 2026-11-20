-- Minimal FrSky Ethos API mock to run the TR4CEPIL0T widgets on a PC (liblua5.4 via tools/lua54.py).
-- Records every draw call to OUT_FILE; tools/ethos_mock/render.py turns it into a PNG.
-- Globals set by the caller: SCRIPT, OUT_FILE, WIN_W, WIN_H, SCENARIO, WIDGET
local CLOCK = 0
os.clock = function() return CLOCK end
local realDate = os.date
os.date = function(f, t) if f == "*t" then return { year = 2026, month = 11, day = 20, hour = 14, min = 51, sec = 0 } end return realDate(f, t) end

-- constants
local n = 0
local function c() n = n + 1 return n end
for _, k in ipairs({ "CATEGORY_ANALOG", "CATEGORY_SWITCH", "CATEGORY_SWITCH_POSITION", "CATEGORY_FUNCTION_SWITCH",
  "CATEGORY_TELEMETRY_SENSOR", "CATEGORY_SYSTEM", "CATEGORY_SYSTEM_EVENT", "SYSTEM_MAIN_VOLTAGE",
  "SYSTEM_EVENT_TELEMETRY_ACTIVE", "OPTION_LATITUDE", "OPTION_LONGITUDE", "EVT_KEY", "EVT_TOUCH",
  "TOUCH_END", "KEY_ENTER_BREAK", "PEN_DOTTED", "PEN_SOLID", "TEXT_RIGHT",
  "FONT_XS", "FONT_S", "FONT_M" }) do _G[k] = c() end

local S = SCENARIO
local live = S.live
local STICK = { 0, 0, 0, 0 }      -- rud, ele, thr, ail (-1024..1024)

local function source(t)
  return {
    name = function() return t.name end,
    value = function(self, opt)
      if t.fn then return t.fn(opt) end
      return t.v
    end,
    state = function() if t.state ~= nil then return t.state end return (t.v or 0) > 0 end,
    stringValue = function() local v = t.fn and t.fn() or t.v; return v ~= nil and tostring(v) or "" end,
  }
end

local ANALOG = { "Rudder", "Elevator", "Throttle", "Aileron", "P1", "P2", "SL", "SR" }
local AVAL = { 0, 0, 0, 0, 410, -820, 0, 256 }
local SWN = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" }
local SWV = { -100, 0, 100, -100, -100, 100, 0, -100 }
local SW3 = { SA = 3, SB = 3, SC = 3, SD = 3, SE = 2, SF = 2, SG = 3, SH = 2 }
local POS = {}
for _, nm in ipairs(SWN) do for k = 1, SW3[nm] do POS[#POS + 1] = nm .. ({ "\226\134\145", "-", "\226\134\147" })[k] end end
local TELE = {
  ["Rx Quality"] = function() return live and S.lq or nil end,
  ["Rx RSSI1"] = function() return live and -62 or nil end,
  ["Rx Batt"] = function() return live and 16.4 or nil end,
  ["Flight mode"] = function() return live and S.fm or nil end,
  ["Satellites"] = function() return S.gps and live and 9 or nil end,
  ["Tx Power"] = function() return 250 end, ["Rx SNR"] = function() return 9 end,
  ["Tx Quality"] = function() return 100 end, ["Current"] = function() return 12.4 end,
  ["Consumption"] = function() return 356 end,
}

system = {
  getSource = function(t)
    if type(t) == "string" then t = { name = t } end
    if t.category == CATEGORY_ANALOG then
      local m = t.member + 1
      if not ANALOG[m] then return nil end
      return source({ name = ANALOG[m], fn = function() return m <= 4 and STICK[m] or AVAL[m] end })
    elseif t.category == CATEGORY_SWITCH then
      local m = t.member + 1
      if not SWN[m] then return nil end
      return source({ name = SWN[m], v = SWV[m] })
    elseif t.category == CATEGORY_SWITCH_POSITION then
      local nm = POS[t.member + 1]
      if not nm then return nil end
      return source({ name = nm, v = 0 })
    elseif t.category == CATEGORY_FUNCTION_SWITCH then
      if t.member > 5 then return nil end
      return source({ name = "FS" .. (t.member + 1), state = (t.member == 0 or t.member == 3) })
    elseif t.category == CATEGORY_SYSTEM then
      return source({ name = "Main voltage", v = 8.0 })
    elseif t.category == CATEGORY_SYSTEM_EVENT then
      return { name = function() return "Telemetry" end, state = function() return live end, value = function() return live and 1 or 0 end }
    elseif t.category == CATEGORY_TELEMETRY_SENSOR then
      if t.name == "GPS" and S.gps then
        return source({ name = "GPS", fn = function(opt)
          if not live then return nil end
          local o = t.options or opt
          if o == OPTION_LATITUDE then return 38.736946 elseif o == OPTION_LONGITUDE then return -9.142685 end
          return 0 end })
      end
      local f = TELE[t.name]
      if not f then return nil end
      return source({ name = t.name, fn = f })
    end
    return nil
  end,
  getStickMode = function() return 2 end,
  voltageRange = function() return 7.2, 8.4 end,
  registerWidget = function(t) WIDGETS = WIDGETS or {}; WIDGETS[t.key] = t end,
}
model = {
  name = function() return 'Drone 5"' end,
  getTimer = function(i)
    if i > 1 then return nil end
    return { value = function() return i == 0 and 157 or 312 end,
             running = function() return i == 0 and S.timer end,
             name = function() return i == 0 and "Flight" or "Pack" end }
  end,
}
storage = { read = function() return nil end, write = function() end }
form = {}

local OPS = {}
local CUR, FONT = 0, FONT_S
local INV = 0
lcd = {
  RGB = function(r, g, b) return 0xFF000000 | (r << 16) | (g << 8) | b end,
  color = function(x) CUR = x end,
  font = function(f) FONT = f end,
  pen = function() end,
  getWindowSize = function() return WIN_W, WIN_H end,
  getTextSize = function(s) return #s * 9, 16 end,
  invalidate = function() INV = INV + 1 end,
  drawFilledRectangle = function(x, y, w, h) OPS[#OPS + 1] = string.format("R %d %d %d %d %d", x, y, w, h, CUR) end,
  drawLine = function(x1, y1, x2, y2) OPS[#OPS + 1] = string.format("L %d %d %d %d %d", x1, y1, x2, y2, CUR) end,
  drawText = function(x, y, s, f) OPS[#OPS + 1] = string.format("T %d %d %d %d %d %s", x, y, CUR, (f == TEXT_RIGHT) and 1 or 0, FONT, s) end,
}

local chunk = assert(loadfile(SCRIPT))
chunk().init()
local W = WIDGETS[WIDGET]
local wd = W.create()
-- trail path like the mockups: left stick arc, right stick drop
for step = 0, 60 do
  CLOCK = step * 0.04
  local t = math.min(1, step / 24)
  local lx, ly = -0.9 + 1.4 * t, -0.2 + 0.9 * math.sin(t * 2.5)
  local rx, ry = 0.6 - 0.3 * t, -0.9 + 1.6 * t * t
  if step > 24 then t = 1 end
  STICK[1], STICK[3], STICK[4], STICK[2] = lx * 1024, ly * 1024, rx * 1024, ry * 1024
  W.wakeup(wd)
  if step == 24 then break end
end
if S.disarmLater then W.paint(wd); live = false; CLOCK = CLOCK + 1; W.wakeup(wd) end
if S.tap then W.event(wd, EVT_KEY, KEY_ENTER_BREAK) end
CLOCK = CLOCK + 0.3
W.wakeup(wd)
for i = #OPS, 1, -1 do OPS[i] = nil end
W.paint(wd)
local f = assert(io.open(OUT_FILE, "w"))
f:write(table.concat(OPS, "\n"))
f:close()
print("ops", #OPS, "invalidations", INV)
