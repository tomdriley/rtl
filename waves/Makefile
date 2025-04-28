# Makefile for building and running a simple Verilator designa

FILE_LIST := waves.v
WAVE_FILE := waves.vcd
VERILATOR_BUILD_ARGS := --main --timing --build --exe -Wall -j 0 -o run_sim --trace

# Docker image containing Verilator
VERILATOR_IMAGE := verilator/verilator:latest
VERILATOR_DOCKER := docker run --rm -ti \
	-v "$(PWD)":/work \
	-e HOME=/work \
	-w /work \
	--user $(shell id -u):$(shell id -g) \
	$(VERILATOR_IMAGE)

# Docker image containing GTKWave
GTK_WAVES_IMAGE := gtk-wave:latest
GTKWAVES_DOCKER := docker run --rm -it \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v /mnt/wslg:/mnt/wslg \
	-e DISPLAY -e WAYLAND_DISPLAY -e XDG_RUNTIME_DIR \
	-v "$(PWD)":/work \
	-e HOME=/work \
	-w /work \
	--user $(shell id -u):$(shell id -g) \
	$(GTK_WAVES_IMAGE) gtkwave

.PHONY: build run clean

# 'build' is simply an alias that ensures the binary exists
build: obj_dir/run_sim

# Generate the Verilator binary only if $(FILE_LIST) changed or missing
obj_dir/run_sim: $(FILE_LIST)
	$(VERILATOR_DOCKER) $(VERILATOR_BUILD_ARGS) $(FILE_LIST)

# Run the generated simulation (won't rebuild if up-to-date)
run: obj_dir/run_sim
	obj_dir/run_sim

waves: $(WAVE_FILE)
	$(GTKWAVES_DOCKER) $(WAVE_FILE)

# Clean generated files
clean:
	rm -rf obj_dir .cache *.vcd
