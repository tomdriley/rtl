# Static Timing Analysis (STA) Example

This example demonstrates a simple RTL → standard-cell mapping → OpenSTA timing report flow using Sky130.

## Supported commands

- `make pdk-sky130` — Fetch the Sky130 PDK into the shared cache (`rtl-toolkit/.pdk`)
- `make synth` — Run Yosys mapping (writes a structural netlist under `scratch/`)
- `make sta` — Run OpenSTA and write `scratch/sta.rpt`
- `make clean` — Remove generated artifacts (including `scratch/`)

## Files

- `tiny.v` — Tiny RTL design
- `synth.ys` — Yosys mapping script
- `tiny.sdc` — Timing constraints (clock + simple IO delays)
- `sta.tcl` — OpenSTA script (reads Liberty + netlist + SDC and reports)

## Variables

- `STA_OUT` — Output report path (defaults to `scratch/sta.rpt`)
- `SKY130_CIEL_VERSION` — Optional pin for the PDK version used by `ciel`
