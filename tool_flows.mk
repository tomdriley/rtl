# Common variables
VERILATOR_IMAGE := verilator/verilator:v5.036
VERILATOR_DOCKER := docker run --rm -ti \
	-v "$(PWD)":/work \
	-e HOME=/work \
	-w /work \
	--user $(shell id -u):$(shell id -g) \
	$(VERILATOR_IMAGE)
VERILATOR_BUILD_ARGS := --main --timing --build --exe -Wall -j 0 -o run_sim --trace --assert
VERILATOR_INCLUDE_ARGS = $(addprefix -I, $(INCLUDE_DIRS))

GTK_WAVES_IMAGE := gtk-wave:latest

# Auto-detect X11 environment (VNC vs WSLg)
ifeq ($(shell test -S /tmp/.X11-unix/X$(patsubst :%,%,$(DISPLAY)) && echo wslg),wslg)
    # WSL2/WSLg environment - traditional X11 socket
    GTKWAVES_DOCKER := docker run --rm -it \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v /mnt/wslg:/mnt/wslg \
        -e DISPLAY -e WAYLAND_DISPLAY -e XDG_RUNTIME_DIR \
        -v "$(PWD)":/work \
        -e HOME=/work \
        -w /work \
        --user $(shell id -u):$(shell id -g) \
        $(GTK_WAVES_IMAGE) gtkwave
else
    # Dev container VNC environment
    GTKWAVES_DOCKER := docker run --rm -it \
        --network host \
        -e DISPLAY=$(DISPLAY) \
        $(if $(wildcard $(HOME)/.Xauthority),-v "$(HOME)/.Xauthority:$(HOME)/.Xauthority:ro") \
        -v "$(PWD)":/work \
        -e HOME=/work \
        -w /work \
        --user $(shell id -u):$(shell id -g) \
        $(GTK_WAVES_IMAGE) gtkwave
endif


# Common rules
.PHONY: clean rebuild build run waves

clean:
	rm -rf obj_dir .cache *.vcd

rebuild:
	$(MAKE) clean
	$(MAKE) build

build: obj_dir/run_sim

obj_dir/run_sim: $(FILE_LIST)
	$(VERILATOR_DOCKER) $(VERILATOR_BUILD_ARGS) $(VERILATOR_INCLUDE_ARGS) $(FILE_LIST)

run: obj_dir/run_sim
	obj_dir/run_sim

waves: $(WAVE_FILE)
	$(GTKWAVES_DOCKER) $(WAVE_FILE)
