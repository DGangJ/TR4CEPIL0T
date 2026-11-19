"""
LED ring effects for EdgeTX "RGB leds" special function (RadioMaster TX15 Max geometry).
generate(out_dir, brand, amb, amb_name, pa01=False, variants=True)
  - writes the 10 base scripts (iOrbit, iBrth, iSpark, iDual, iStat, iStick, iScan, iLevel, iArm, iFind)
  - variants=True also writes 9 effects x 10 colours (e.g. OrbitC = Orbit in cyan)
  - pa01=True adds a warning that the PA01 LED layout is unknown and makes iFind scan 0..39
"""
import os, re
HEAD='''-- %(name)s  (/SCRIPTS/RGBLED/%(name)s.lua)  - %(brand)s effects for the gimbal LED rings
-- %(desc)s
-- Use: Model Settings > Special Functions (or Global Functions) > function "RGB leds", value = %(name)s

-- ---------- TX15 Max rings (confirmed): 10 LEDs per gimbal, left 10-19, right 0-9
local N = 10
local RING = { 10, 0 }    -- first LED of each ring: 1 = left, 2 = right
-- position: degrees clockwise (0 = top, 90 = right, 180 = bottom, 270 = left).
-- LED 0 of each ring faces the centre of the radio; the left ring counts anticlockwise.
local BASE = { 90, 270 }
local DIR = { -1, 1 }
local BRIGHT = 0.7        -- overall brightness (0.1 to 1.0)

local AMB = { %(amb)s }   -- main colour: %(ambname)s
local WHT = { 255, 255, 255 }   -- white

local STEPDEG = 360 / N

local function set(i, c, k)
  k = (k or 1) * BRIGHT
  if k < 0 then k = 0 elseif k > 1 then k = 1 end
  setRGBLedColor(i, math.floor(c[1] * k + 0.5), math.floor(c[2] * k + 0.5), math.floor(c[3] * k + 0.5))
end

-- mix of two colours (t = 0 -> a, t = 1 -> b), without creating new tables
local MIX = { 0, 0, 0 }
local function mix(a, b, t)
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  MIX[1] = a[1] + (b[1] - a[1]) * t
  MIX[2] = a[2] + (b[2] - a[2]) * t
  MIX[3] = a[3] + (b[3] - a[3]) * t
  return MIX
end

-- LED i (0..N-1) of ring r (1 = left, 2 = right)
local function led(r, i) return RING[r] + i end
-- physical angle of LED i on ring r
local function ang(r, i) return (BASE[r] + DIR[r] * STEPDEG * i) %% 360 end
-- distance between two angles (0 to 180)
local function adist(a, b)
  local d = math.abs(a - b) %% 360
  if d > 180 then d = 360 - d end
  return d
end

local function axis(name)
  local v = getValue(name)
  if type(v) ~= "number" then return 0 end
  v = v / 1024
  if v > 1 then v = 1 elseif v < -1 then v = -1 end
  return v
end

'''
TAIL='''
local function init() end
local function background() end

return { init = init, run = run, background = background }
'''
UP='''-- LED order from bottom to top (bars that fill upwards on both sides)
local UP = { {}, {} }
for r = 1, 2 do
  for i = 0, N - 1 do
    -- insert sorted by distance to the bottom of the ring (180 degrees)
    local d = adist(ang(r, i), 180)
    local k = #UP[r] + 1
    while k > 1 and adist(ang(r, UP[r][k - 1]), 180) > d do UP[r][k] = UP[r][k - 1]; k = k - 1 end
    UP[r][k] = i
  end
end

'''
FX={}
FX['iOrbit']=('Orbit: white head rotating with a fading amber trail (like the screen trails). Mirrored rings.','''local STEP = 9     -- 10 ms ticks per LED (9 = one turn in ~0.9 s)
local TAIL = 5     -- trail length

local function run()
  local head = math.floor(getTime() / STEP) % N
  for r = 1, 2 do
    for i = 0, N - 1 do
      local age = (head - i) % N
      if age == 0 then
        set(led(r, i), WHT, 1)
      elseif age <= TAIL then
        local k = 1 - age / (TAIL + 1)
        set(led(r, i), AMB, k * k)
      else
        set(led(r, i), AMB, 0.04)
      end
    end
  end
  applyRGBLedColors()
end
''')
FX['iBrth']=('Breathing: slowly pulsing amber, with the peak shifting towards white. The two rings alternate.','''local PERIOD = 320   -- 10 ms ticks per cycle (3.2 s)

local function run()
  local t = getTime()
  for r = 1, 2 do
    local ph = (t / PERIOD + (r - 1) * 0.5) * 2 * math.pi
    local k = 0.5 - 0.5 * math.cos(ph)
    local c = mix(AMB, WHT, k * k * 0.45)
    local b = 0.06 + 0.94 * k
    for i = 0, N - 1 do set(led(r, i), c, b) end
  end
  applyRGBLedColors()
end
''')
FX['iSpark']=('Sparks: soft amber background with random white LEDs slowly fading in and out.','''local LEVEL = {}
local last = 0
local seed = 1234
local function rnd()
  seed = (seed * 75 + 74) % 65537
  return seed / 65537
end

local function run()
  local t = getTime()
  if t - last >= 6 then
    last = t
    for j = 0, 2 * N - 1 do LEVEL[j] = (LEVEL[j] or 0) * 0.82 end
    if rnd() < 0.55 then LEVEL[math.floor(rnd() * 2 * N)] = 1 end
  end
  for r = 1, 2 do
    for i = 0, N - 1 do
      local s = LEVEL[(r - 1) * N + i] or 0
      set(led(r, i), mix(AMB, WHT, s), 0.18 + 0.82 * s)
    end
  end
  applyRGBLedColors()
end
''')
FX['iDual']=('Duo: top half amber and bottom half white, rotating very slowly and mirrored.','''local PERIOD = 600   -- 10 ms ticks per turn (6 s)

local function run()
  local rot = (getTime() % PERIOD) / PERIOD * 360
  for r = 1, 2 do
    for i = 0, N - 1 do
      -- rotated angle, mirrored between the two rings
      local a = (ang(r, i) + ((r == 1) and rot or -rot)) % 360
      if adist(a, 0) < 90 then set(led(r, i), AMB, 0.9) else set(led(r, i), WHT, 0.55) end
    end
  end
  applyRGBLedColors()
end
''')
FX['iStat']=('Flight status: left ring = LQ, right ring = drone battery (per cell); both fill from bottom to top. White = good, amber = warning, blinking amber = critical. No telemetry: pulsing amber.',UP+'''local cells
local lostAt

local function bar(r, n, col, blinkOff)
  for k = 1, N do
    local i = UP[r][k]
    if k <= n and not blinkOff then set(led(r, i), col, 0.9)
    else set(led(r, i), AMB, 0.05) end
  end
end

local function run()
  local t = getTime()
  local lq = getValue("RQly")
  local v = getValue("RxBt")
  if type(lq) ~= "number" or lq <= 0 then
    lostAt = lostAt or t
    if t - lostAt > 1000 then cells = nil end
    local k = 0.5 - 0.5 * math.cos(t / 200 * 2 * math.pi)
    for r = 1, 2 do
      for i = 0, N - 1 do set(led(r, i), AMB, 0.05 + 0.5 * k) end
    end
    applyRGBLedColors()
    return
  end
  lostAt = nil
  local blink = (t % 50) < 25

  local n = math.floor(lq / 100 * N + 0.5)
  if lq < 50 then bar(1, n, AMB, blink)
  elseif lq < 70 then bar(1, n, AMB, false)
  else bar(1, n, WHT, false) end

  if type(v) == "number" and v > 0 then
    local guess = math.max(1, math.ceil(v / 4.35))
    if cells == nil or guess > cells then cells = guess end
    local cell = v / cells
    local pct = (cell - 3.3) / 0.9
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    local m = math.max(1, math.floor(pct * N + 0.5))
    if cell < 3.3 then bar(2, m, AMB, blink)
    elseif cell < 3.5 then bar(2, m, AMB, false)
    else bar(2, m, WHT, false) end
  else
    bar(2, 0, WHT, false)
  end
  applyRGBLedColors()
end
''')
FX['iStick']=('Stick direction: rings in amber, lighting up white in the direction the stick points (stronger the further from centre).','''local MODE = 2            -- stick mode (1 to 4)
local DEAD = 0.08         -- centre dead zone (0 to 1)
local SPREAD = 55         -- glow width in degrees (36 = one LED only, 80 = three LEDs)

local MODES = {
  { { "rud", "ele" }, { "ail", "thr" } },
  { { "rud", "thr" }, { "ail", "ele" } },
  { { "ail", "ele" }, { "rud", "thr" } },
  { { "ail", "thr" }, { "rud", "ele" } },
}
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function run()
  local m = MODES[MODE] or MODES[2]
  for r = 1, 2 do
    local x, y = axis(m[r][1]), axis(m[r][2])
    local mag = math.sqrt(x * x + y * y)
    if mag > 1 then mag = 1 end
    local a = math.deg(atan2(x, y)) % 360
    local k = 0
    if mag > DEAD then k = (mag - DEAD) / (1 - DEAD) end
    for i = 0, N - 1 do
      local w = 1 - adist(ang(r, i), a) / SPREAD
      if w < 0 then w = 0 end
      w = w * k
      set(led(r, i), mix(AMB, WHT, w), 0.55 + 0.45 * w)
    end
  end
  applyRGBLedColors()
end
''')
FX['iScan']=('Scan: a wall of white light sweeps across both rings left to right and back, leaving an amber trail (light cycle style).','''local PERIOD = 240   -- 10 ms ticks per round trip (2.4 s)
local WIDTH = 0.45   -- width of the white head
local LEVEL = {}
local last = getTime()

local X = {}         -- horizontal position of each LED: rings centred at -1.6 and +1.6, radius 1
for r = 1, 2 do
  for i = 0, N - 1 do
    X[(r - 1) * N + i] = ((r == 1) and -1.6 or 1.6) + math.sin(math.rad(ang(r, i)))
  end
end

local function run()
  local t = getTime()
  local dt = t - last
  last = t
  local decay = 0.86 ^ (dt / 3)
  local p = (t % PERIOD) / PERIOD
  local tri = (p < 0.5) and (p * 2) or (2 - p * 2)
  local hx = -2.9 + 5.8 * tri
  for r = 1, 2 do
    for i = 0, N - 1 do
      local j = (r - 1) * N + i
      local h = 1 - math.abs(X[j] - hx) / WIDTH
      if h < 0 then h = 0 end
      local l = (LEVEL[j] or 0) * decay
      if h > l then l = h end
      LEVEL[j] = l
      set(led(r, i), mix(AMB, WHT, h), 0.05 + 0.95 * l)
    end
  end
  applyRGBLedColors()
end
''')
FX['iLevel']=('Meter (VU): the rings fill from bottom to top. Throttle ring = throttle position; the other = how far the stick is from centre. White over amber, with a peak indicator.',UP+'''local MODE = 2            -- stick mode (1 to 4)
-- sticks of each gimbal: { x, y } -> left, right
local MODES = {
  { { "rud", "ele" }, { "ail", "thr" } },
  { { "rud", "thr" }, { "ail", "ele" } },
  { { "ail", "ele" }, { "rud", "thr" } },
  { { "ail", "thr" }, { "rud", "ele" } },
}
local peak = { 0, 0 }
local peakT = { 0, 0 }

local function meter(r, v, t)
  local f = v * N
  if f > peak[r] then peak[r] = f; peakT[r] = t end
  if t - peakT[r] > 60 then peak[r] = math.max(f, peak[r] - 0.15) end   -- the peak falls slowly
  local pk = math.floor(peak[r] + 0.5)
  for k = 1, N do
    local i = UP[r][k]
    if k <= f then
      set(led(r, i), WHT, (k >= f - 1) and 1 or 0.7)
    elseif k - 1 < f then
      set(led(r, i), mix(AMB, WHT, f - (k - 1)), 0.4 + 0.5 * (f - (k - 1)))
    elseif k == pk and pk > 0 then
      set(led(r, i), AMB, 1)
    else
      set(led(r, i), AMB, 0.12)
    end
  end
end

local function run()
  local t = getTime()
  local m = MODES[MODE] or MODES[2]
  for r = 1, 2 do
    local v
    if m[r][2] == "thr" then
      v = (axis("thr") + 1) / 2                 -- throttle ring: throttle position
    else
      local x, y = axis(m[r][1]), axis(m[r][2])
      v = math.sqrt(x * x + y * y)              -- other ring: stick distance from centre
      if v > 1 then v = 1 end
    end
    meter(r, v, t)
  end
  applyRGBLedColors()
end
''')
FX['iArm']=('Armed / disarmed: disarmed = soft amber with a white dot slowly orbiting; on arming, a white flash and then strong amber with a white "heartbeat" at the top, faster with more throttle.',UP+'''local ARM_SW = "sa"       -- arming switch
local ARMED_WHEN = 1      -- 1 = armed with the switch above centre (value > 0); -1 = below
local THR = "thr"         -- throttle axis

local wasArmed = false
local armT = -1000
local beat = 0
local lastT = getTime()

local function run()
  local t = getTime()
  local dt = t - lastT
  lastT = t
  local sw = getValue(ARM_SW)
  local armed = type(sw) == "number" and sw * ARMED_WHEN > 0
  if armed and not wasArmed then armT = t end
  wasArmed = armed

  if not armed then
    local head = math.floor(t / 25) % N
    for r = 1, 2 do
      for i = 0, N - 1 do
        if i == head then set(led(r, i), WHT, 0.6) else set(led(r, i), AMB, 0.15) end
      end
    end
    applyRGBLedColors()
    return
  end

  local flash = 1 - (t - armT) / 40          -- 0.4 s white flash when arming
  if flash > 0 then
    for r = 1, 2 do
      for i = 0, N - 1 do set(led(r, i), mix(AMB, WHT, flash), 1) end
    end
    applyRGBLedColors()
    return
  end

  -- double beat: from 1.2 s (throttle low) to 0.4 s (throttle high)
  local thr = (axis(THR) + 1) / 2
  local period = 120 - 80 * thr
  beat = (beat + dt / period) % 1
  local p = 0
  if beat < 0.12 then p = 1 - beat / 0.12
  elseif beat > 0.22 and beat < 0.34 then p = 0.6 * (1 - (beat - 0.22) / 0.12) end
  for r = 1, 2 do
    for k = 1, N do
      local i = UP[r][k]
      if k > N - 3 then set(led(r, i), mix(AMB, WHT, p), 0.7 + 0.3 * p)   -- the 3 top LEDs
      else set(led(r, i), AMB, 0.7) end
    end
  end
  applyRGBLedColors()
end
''')
FX['iFind']=('LED finder: lights one LED at a time (1 per second), from 0 to 19. LEDs 0 and 10 (first of each ring) light up in amber.','''local MAX = 20

local function run()
  local cur = math.floor(getTime() / 100) % MAX
  for i = 0, MAX - 1 do
    if i == cur then
      if i == 0 or i == 10 then pcall(setRGBLedColor, i, %(amb)s) else pcall(setRGBLedColor, i, 255, 255, 255) end
    else
      pcall(setRGBLedColor, i, 0, 0, 0)
    end
  end
  applyRGBLedColors()
end
''')

COLORS=[('A','amber',(255,20,0)),('R','red',(255,0,0)),('G','green',(0,255,0)),('L','lime green',(120,255,0)),
        ('Y','yellow',(255,170,0)),('B','blue',(0,0,255)),('C','cyan blue',(0,255,255)),('P','pink',(255,0,120)),
        ('U','purple',(140,0,255)),('I','lilac',(200,120,255))]
EFF={'iOrbit':'Orbit','iBrth':'Brth','iSpark':'Spark','iDual':'Dual','iStat':'Stat','iStick':'Stick','iScan':'Scan','iLevel':'Level','iArm':'Arm'}

def _desc(desc, word):
    return re.sub(r'\bamber\b', word, desc)

def generate(out, brand, amb, amb_name, pa01=False, variants=True):
    os.makedirs(out, exist_ok=True)
    amb_s = '%d, %d, %d' % tuple(amb)
    for name,(desc,body) in FX.items():
        d = _desc(desc, amb_name if amb_name != 'reddish amber' else 'amber')
        txt = HEAD % dict(name=name, desc=d, brand=brand, amb=amb_s, ambname=amb_name) + body.replace('%(amb)s', amb_s) + TAIL
        if pa01:
            txt = txt.replace('-- ---------- TX15 Max rings (confirmed): 10 LEDs per gimbal, left 10-19, right 0-9',
                '-- ---------- WARNING PA01: these are TX15 Max values (10 LEDs per gimbal, left 10-19, right 0-9).\n'
                '-- On the PA01 the LED layout is different: run iFind first and adjust N, RING, BASE and DIR.')
            if name == 'iFind':
                txt = txt.replace('local MAX = 20', 'local MAX = 40').replace('if i == 0 or i == 10 then', 'if i % 10 == 0 then')
                txt = txt.replace('from 0 to 19. LEDs 0 and 10 (first of each ring) light up', 'from 0 to 39. LEDs 0, 10, 20 and 30 (reference) light up')
        open(f'{out}/{name}.lua', 'w').write(txt)
    if not variants:
        return
    for src,code in EFF.items():
        s = open(f'{out}/{src}.lua').read()
        for L,cname,(r,g,b) in COLORS:
            new = f'{code}{L}'
            t = re.sub(r'^local AMB = \{[^}]*\}.*$', f'local AMB = {{ {r}, {g}, {b} }}   -- colour: {cname}', s, count=1, flags=re.M)
            t = t.replace(f'-- {src}  (/SCRIPTS/RGBLED/{src}.lua)', f'-- {new}  (/SCRIPTS/RGBLED/{new}.lua)  [{src} in {cname}]', 1)
            t = t.replace(f'value = {src}', f'value = {new}')
            lines = t.split('\n')
            if src == 'iStat':
                t = t.replace('local cells\n', 'local WARN = { 255, 20, 0 }   -- warning colour (fixed)\nlocal cells\n', 1)
                t = t.replace('bar(1, n, AMB,', 'bar(1, n, WARN,').replace('bar(2, m, AMB,', 'bar(2, m, WARN,')
                lines = t.split('\n')
                lines[1] = (f'-- Flight status: left ring = LQ, right ring = drone battery (per cell); both fill from bottom to top '
                            f'over a {cname} background. White = good, amber = warning, blinking amber = critical. No telemetry: pulsing {cname}.')
            else:
                lines[1] = re.sub(r'\b(amber|red)\b', cname, lines[1])
            open(f'{out}/{new}.lua', 'w').write('\n'.join(lines))
