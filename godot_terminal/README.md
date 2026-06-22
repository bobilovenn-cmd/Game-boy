# AGV Diagnostic Terminal Godot Port

Godot 4.6.3 migration of the RGB30 handheld diagnostic terminal.

This is the production RGB30 UI source:

- 720x720 handheld UI for PowKiddy RGB30
- Monitor / Config / OTA tabs
- JSON over UDP protocol to ESP32 CAN Dongle
- 150 ms heartbeat
- Stable Linux event-code input through `rgb30-input-bridge.service`
- Six-field motor telemetry and speed waveform

The current ESP32 firmware remains compatible with this UI. Features requiring
new firmware protocol support are documented in
`docs/ESP32_UI_CONTRACT.md`.

## Local Development

Open this folder in Godot 4.6.3:

```text
/Users/guoweifeng/GameBoy/godot_terminal
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

The input bridge normalizes verified Linux event codes to these IDs:

- B: 0 -> back
- A: 1 -> confirm
- X: 2 -> enable
- Y: 3 -> disable
- L1: 4 -> jog CCW
- R1: 5 -> jog CW
- L2: 6 -> emergency stop
- Select: 8 -> language selection
- Start: 9 -> menu
- D-pad: 13/14/15/16 -> up/down/left/right

L2 remains the dedicated E-STOP input. Select must never be mapped to E-STOP.
Godot/SDL input is only an emergency fallback when the event bridge is absent.

Dangerous-action confirmation uses a dedicated `CanvasLayer` instead of
switching pages. The current page remains visible and keeps its selection
state; the decorative background grid is hidden while the opaque confirmation
panel is open. Do not replace this with a full-screen translucent CanvasItem:
the RGB30 Mali/Wayland GL compatibility path does not blend that overlay
reliably.

## Verification

Run all headless tests:

```sh
./tests/run_all.sh
```

Then export the `RGB30 Linux ARM64` preset and verify launch and controls on the
physical RGB30.

For production boot persistence, copy the exported binary and all files from
`deploy/` to `/storage/handheld_terminal_godot/`, then run:

```sh
/storage/handheld_terminal_godot/install_rgb30_services.sh
```

This enables `rgb30-input-bridge.service` and `rgb30-godot.timer`. The timer
starts `rgb30-godot.service` 20 seconds after boot so the ROCKNIX graphics stack
is initialized before Godot restarts Sway. The legacy Python terminal service
remains disabled.

## Known Protocol Limits

- Legacy `motor_status` packets do not carry per-field timestamps. The UI can
  display all six values but cannot independently prove that every field was
  refreshed in the same acquisition cycle.
- OTA data currently uses unacknowledged UDP chunks. The UI labels it
  experimental and requires confirmation before flash.
- Future ESP32 work must follow `docs/ESP32_UI_CONTRACT.md`.

## Deployment Direction

Export as Linux ARM64 from Godot on Mac, then copy the output to RGB30, for
example:

```text
/storage/handheld_terminal_godot/
```

Device regression must verify launch, input bridge readiness, Select/L2
separation, heartbeat, UDP receive, complete six-field telemetry, and safe
handling of dangerous actions.
