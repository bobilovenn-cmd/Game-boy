---
name: godot-rgb30-test
description: Godot 4.6.3 ARM64 export test results on PowKiddy RGB30 / ROCKNIX
metadata:
  type: project
  date: 2026-06-09
---

Godot 4.6.3 ARM64 export was built and copied to RGB30:

```text
/storage/handheld_terminal_godot/rgb30_diag_terminal_arm64
```

The binary runs on RGB30 and `--version` succeeds:

```text
4.6.3.stable.official.7d41c59c4
```

SHA256 matched between Mac and RGB30:

```text
7618bea1ac7c511c4908228f34d2beb0987d3e25c2c57071e63d22d456b220a7
```

Display tests:

- Initial Wayland + `gl_compatibility` test ran for 15 seconds but screen stayed black.
- Vulkan Mobile test identified Mali-G52 and created a Wayland window, but logged:
  `swap_chain_resize ERR_CANT_CREATE`.
- Sway `DSI-1` output was initially inactive/power false after the Python SDL2 service had been using DRM/KMS.
- Restarting `sway.service` after stopping `diag-terminal.service` made `DSI-1` active/power true.
- Even with active `DSI-1`, Godot 4 Vulkan Mobile still logged swapchain creation failures.
- `gl_compatibility` on active `DSI-1` falls back from OpenGL to OpenGLES.
- After stopping `diag-terminal.service`, restarting `sway.service`, and running
  Godot with `gl_compatibility`, the user observed the Godot UI with the
  waveform panel and "Waiting for motor_status packets..." text.

Conclusion:

Godot 4.6.3 Linux ARM64 can execute and render on RGB30, but it requires the
correct display handoff:

1. Stop the Python SDL2/KMSDRM service.
2. Restart `sway.service` so `DSI-1` becomes active/power true.
3. Run the Godot export through Wayland with `gl_compatibility`.

Vulkan Mobile is not currently reliable because swapchain creation fails.

Recommended next steps:

1. Keep Python/SDL2 KMSDRM implementation as the working production fallback.
2. Continue Godot 4.6.3 testing using Wayland + `gl_compatibility`.
3. Verify RGB30 input mapping in Godot.
4. Verify UDP `motor_status` packets from ESP32 CAN Dongle.
5. Avoid replacing the SDL2 service until the Godot build accepts RGB30 input,
   receives UDP data, and survives repeated service restarts.

2026-06-09 RGB30 UI readability pass:

- User compared the Mac Godot preview with the physical RGB30 screen and found
  that many small or dim labels were visible on Mac but missing on RGB30.
- Affected areas included telemetry values/units, HOTKEYS, INPUT/LAST values,
  the header subtitle, Config status values, SDO result, and OTA metadata.
- Selection styling also failed on RGB30: selected rows became black/invisible.
- `godot_terminal/scripts/main.gd` was adjusted for RGB30 readability:
  larger small-text sizes, brighter dim text, smaller telemetry value digits,
  taller metric cards, and high-contrast selected rows using dark fill,
  cyan border/left bar, and white text instead of cyan fill with black text.
- The fixed export was rebuilt and deployed to:
  `/storage/handheld_terminal_godot/rgb30_diag_terminal_arm64`
- The new RGB30 process started successfully as PID 34589. Logs only showed the
  known Wayland/OpenGL fallback warnings, with no immediate crash.

2026-06-09 second RGB30 readability pass:

- The first pass did not fix the physical RGB30 display. User still saw missing
  telemetry values/units, missing header subtitle, missing Config help/status
  text, missing SDO result, missing OTA metadata/log text, and invisible
  selected rows.
- The UI was changed to prioritize physical RGB30 visibility over the Mac
  preview style:
  - Critical text now uses larger 18-26 px sizes.
  - Missing secondary text was changed to pure white or high-contrast yellow.
  - Selected command/config rows no longer use cyan fill or dark selected fill.
    They now use a black base, thick white border, yellow left marker, and
    white text.
  - Telemetry labels, values, and units were enlarged and forced to
    high-contrast white/yellow.
  - OTA firmware metadata, transfer state, target address, and OTA log entries
    were enlarged and forced to high-contrast colors.
- Rebuilt and redeployed the export to RGB30.
- The new RGB30 process started successfully as PID 38619. Logs only showed the
  known Wayland/OpenGL fallback warnings, with no immediate crash.
