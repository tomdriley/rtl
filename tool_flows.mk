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
OSS_CAD_IMAGE := oss-cad-suite-test:latest

# SBY Docker command
SBY_DOCKER := docker run --rm -ti \
	-v "$(PWD)":/work \
	-w /work \
	--user $(shell id -u):$(shell id -g) \
	$(OSS_CAD_IMAGE) sby

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
.PHONY: clean rebuild build run waves formal formal-cover formal-waves waves-list waves-cover waves-bmc

clean:
	@# Clean Verilator artifacts
	rm -rf obj_dir .cache *.vcd
	@# Clean formal verification artifacts
	rm -rf *_bmc *_cover *_prove *_live
	rm -rf sby-* *.xml *.sqlite *.smtc *.yw *_tb.v
	rm -rf status status.* PASS FAIL UNKNOWN logfile.txt config.sby
	@# Remove any directories that match .sby basenames (SBY output directories)
	@for f in *.sby; do [ -f "$$f" ] && rm -rf "$$(basename "$$f" .sby)" || true; done 2>/dev/null || true

rebuild:
	$(MAKE) clean
	$(MAKE) build

build: obj_dir/run_sim

obj_dir/run_sim: $(FILE_LIST)
	$(VERILATOR_DOCKER) $(VERILATOR_BUILD_ARGS) $(VERILATOR_INCLUDE_ARGS) $(FILE_LIST)

run: obj_dir/run_sim
	obj_dir/run_sim

# Formal verification rules
formal: $(SBY_FILE)
	$(SBY_DOCKER) -f $(SBY_FILE)

formal-cover: $(SBY_FILE)
	$(SBY_DOCKER) -f $(SBY_FILE) cover

formal-waves: $(SBY_FILE)
	@# List and select VCD files from formal verification
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	if [ -n "$(WAVE)" ]; then \
		if [ -f "$(WAVE)" ]; then \
			echo "Opening specified trace: $(WAVE)"; \
			$(GTKWAVES_DOCKER) $(WAVE); \
		else \
			echo "Error: Specified wave file '$(WAVE)' not found."; \
			exit 1; \
		fi \
	else \
		TRACE_FILES=$$(find "$${SBY_BASE}_"* -name "*.vcd" 2>/dev/null | sort); \
		if [ -n "$$TRACE_FILES" ]; then \
			TRACE_COUNT=$$(echo "$$TRACE_FILES" | wc -l); \
			if [ $$TRACE_COUNT -eq 1 ]; then \
				TRACE_FILE=$$TRACE_FILES; \
				echo "Opening formal trace: $$TRACE_FILE"; \
				$(GTKWAVES_DOCKER) $$TRACE_FILE; \
			else \
				echo "Multiple VCD files found:"; \
				echo "$$TRACE_FILES" | nl -w2 -s': '; \
				echo ""; \
				echo "Usage options:"; \
				echo "  make waves WAVE=<filename>     # Open specific file"; \
				echo "  make waves-list                # List all available traces"; \
				echo "  make waves-cover               # Open cover traces"; \
				echo "  make waves-bmc                 # Open BMC traces"; \
				echo ""; \
				echo "Opening first trace: $$(echo "$$TRACE_FILES" | head -1)"; \
				$(GTKWAVES_DOCKER) $$(echo "$$TRACE_FILES" | head -1); \
			fi \
		else \
			echo "No VCD trace files found. Run 'make formal' or 'make cover' first."; \
		fi \
	fi

# Additional wave viewing targets
waves-list: $(SBY_FILE)
	@# List all available VCD files from formal verification
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	TRACE_FILES=$$(find "$${SBY_BASE}_"* -name "*.vcd" 2>/dev/null | sort); \
	if [ -n "$$TRACE_FILES" ]; then \
		echo "Available VCD trace files:"; \
		echo "$$TRACE_FILES" | nl -w2 -s': '; \
		echo ""; \
		echo "Usage: make waves WAVE=<filename>"; \
	else \
		echo "No VCD trace files found. Run 'make formal' or 'make cover' first."; \
	fi

waves-cover: $(SBY_FILE)
	@# Open cover traces specifically
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	TRACE_FILE=$$(find "$${SBY_BASE}_cover" -name "*.vcd" 2>/dev/null | head -1); \
	if [ -n "$$TRACE_FILE" ]; then \
		echo "Opening cover trace: $$TRACE_FILE"; \
		$(GTKWAVES_DOCKER) $$TRACE_FILE; \
	else \
		echo "No cover trace files found. Run 'make cover' first."; \
	fi

waves-bmc: $(SBY_FILE)
	@# Open BMC traces specifically  
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	TRACE_FILE=$$(find "$${SBY_BASE}_bmc" -name "*.vcd" 2>/dev/null | head -1); \
	if [ -n "$$TRACE_FILE" ]; then \
		echo "Opening BMC trace: $$TRACE_FILE"; \
		$(GTKWAVES_DOCKER) $$TRACE_FILE; \
	else \
		echo "No BMC trace files found. Run 'make formal' first."; \
	fi

waves:
	@# Auto-detect whether to use regular waves or formal waves
	@if [ -n "$(WAVE_FILE)" ] && [ -f "$(WAVE_FILE)" ]; then \
		echo "Opening simulation trace: $(WAVE_FILE)"; \
		$(GTKWAVES_DOCKER) $(WAVE_FILE); \
	elif [ -n "$(WAVE)" ] && [ -f "$(WAVE)" ]; then \
		echo "Opening specified trace: $(WAVE)"; \
		$(GTKWAVES_DOCKER) $(WAVE); \
	elif [ -n "$(SBY_FILE)" ]; then \
		$(MAKE) formal-waves; \
	else \
		echo "No wave file specified. Set WAVE_FILE or WAVE variable, or run from formal verification directory."; \
		exit 1; \
	fi
