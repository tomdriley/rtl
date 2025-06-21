# RTL Experiments

## Setup

Ensure that you have `make` installed (e.g. `sudo apt install make`), and have Docker installed and running.

```bash
make setup # Sets up docker and other dependencies
```

## Hello world example

```bash
cd hello
make build # Generates obj_dir build files
make run # Runs simulator
```

## Waves example

```bash
cd waves
make build # Generates obj_dir build files
make run # Runs simulator
make waves # Opens waves in GTK waves
```
