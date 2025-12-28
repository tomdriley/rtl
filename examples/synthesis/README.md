# Synthesis Example

This example runs Yosys synthesis using the toolkit containers.

## Supported commands

- `make synth` — Run Yosys with `synth.ys`
- `make clean` — Remove generated artifacts (including `scratch/`)

## Notes

- Synthesis outputs are written under `scratch/`.

## Variables

- `SYNTH_SCRIPT` — Yosys script to run (defaults to `synth.ys`)
