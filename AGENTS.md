# GameBoy Project Guidance

## Project Location

All source files, project documents, and memory files for this project must stay
under:

```text
/Users/guoweifeng/GameBoy
```

Do not use `/Users/guoweifeng/Documents/GameBoy` for this project.

## Project Context

This project builds a handheld AGV/AMR motor diagnostic and debugging terminal.
The target handheld host is a PowKiddy RGB30 running ROCKNIX. It communicates
with an ESP32 CAN Dongle over JSON/UDP, and the dongle talks to the CANopen
motor side.

Before making project decisions, read:

- `memory/MEMORY.md`
- `memory/project_rgb30_host.md`
- `memory/feedback_sync_memory.md`

## Runtime Implementations

- `handheld_terminal/` is the current Python/SDL2 implementation and remains
  the fallback runtime until the Godot port is verified on RGB30.
- `godot_terminal/` is the Godot 4.6.3 migration. It should track the same
  protocol, controls, and UI workflows first, then grow new features later.

## RGB30 Notes

Verified raw button IDs from `/dev/input/js0`:

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

## Git

This repository is connected to:

```text
https://github.com/bobilovenn-cmd/Game-boy
```

Ignore generated files such as `.DS_Store`, `__pycache__/`, and Godot `.godot/`
cache directories. Source code, documents, and `memory/*.md` should be tracked.

