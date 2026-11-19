# TR4CEPIL0T v1.0.0

First public release of TR4CEPIL0T, a black dot-matrix, TRON-style layout for EdgeTX on the
RadioMaster TX15 / TX15 Max.

## Highlights
- **TPTrails** (page 1): fading trails of both gimbals; top bar with model, LQ, RSSI, drone battery and radio
  battery (with USB charging indicator); flight mode; GPS satellites, coordinates and last known position saved
  to the SD card; time and date; automatic flight timer and tap cycle time > T1 > T2.
- **TPInputs** (page 2): sticks, pots, gyro, switches and extra telemetry.
- **TPSim**: page for a simulator model with RF state, session time, flights and a virtual pack timer.
- Matching **theme**, boot/shutdown **splash** and two alternative splashes.
- **LED ring effects**: 10 effects, 9 of them in 10 colours.
- **TRON-style sounds** for arming, flight modes and alerts.

## Install
Download `TR4CEPIL0T_TX15.zip` below, copy its folders to the root of the SD card and follow the
[setup steps](../README.md#set-up).

Requires EdgeTX 2.10 or newer. Use at your own risk and check your setup before flying.

## Known limitations
- The USB charging indicator is inferred from the radio voltage (no EdgeTX API); it appears about a minute after
  plugging in and may not appear with a full battery.
- Touch actions (timer cycle) only work in widget full screen mode (double tap; long press RTN to exit).

If you enjoy it, you can support the project on [Ko-fi](https://ko-fi.com/tr4cepil0t). ☕
