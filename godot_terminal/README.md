# AGV Diagnostic Terminal Godot Port

Godot 4.6.3 migration of the RGB30 handheld diagnostic terminal.

This project mirrors the current Python/SDL2 workflow:

- 720x720 handheld UI for PowKiddy RGB30
- Monitor / Config / OTA tabs
- JSON over UDP protocol to ESP32 CAN Dongle
- 150 ms heartbeat
- RGB30 button mapping from the verified `/dev/input/js0` IDs
- Motor status display and current waveform

The existing Python/SDL2 implementation remains in `../handheld_terminal/` as
the fallback runtime until this Godot port is verified on device.

## Local Development

Open this folder in Godot 4.6.3:

```text
/Users/guoweifeng/Game Boy/godot_terminal
```

Run the main scene. Keyboard fallback controls are available on Mac:

- Arrow keys: navigate
- Enter or Space: confirm
- Tab: switch tab
- Escape: back / jog stop
- X: enable
- Y: disable
- Q: jog CCW
- E: jog CW
- S: emergency stop

## RGB30 Notes

The default input profile is `rgb30_raw`, matching the verified button IDs:

- B: 0 -> back
- A: 1 -> confirm
- X: 2 -> enable
- Y: 3 -> disable
- L1: 4 -> jog CCW
- R1: 5 -> jog CW
- L2: 6 -> emergency stop
- Select: 8 -> emergency stop
- Start: 9 -> menu
- D-pad: 13/14/15/16 -> up/down/left/right

If Godot normalizes the controller through SDL mappings on RGB30, set
`INPUT_PROFILE` in `scripts/settings.gd` to `godot_standard`.

## Deployment Direction

Export as Linux ARM64 from Godot on Mac, then copy the output to RGB30, for
example:

```text
/storage/handheld_terminal_godot/
```

The first device test should only verify launch, fullscreen rendering, input,
heartbeat, and UDP receive. Keep the Python/SDL2 service available until this
port is proven stable.

