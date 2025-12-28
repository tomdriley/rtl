ifndef TOOL_FLOWS_MK
TOOL_FLOWS_MK := 1

ifndef PROJECT_ROOT
PROJECT_ROOT := $(PWD)
endif # PROJECT_ROOT

ifndef CURRENT_DIR
CURRENT_DIR := /work
endif # CURRENT_DIR

# Common variables
VERILATOR_IMAGE := verilator/verilator:v5.036
VERILATOR_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-e HOME=$(CURRENT_DIR) \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(VERILATOR_IMAGE)
VERILATOR_BUILD_ARGS := --main --timing --build --exe -Wall -j 0 -o run_sim --trace --assert $(DEFINES)
VERILATOR_INCLUDE_ARGS = $(addprefix -I, $(INCLUDE_DIRS))

GTK_WAVES_IMAGE := gtk-wave:latest
OSS_CAD_IMAGE := oss-cad:latest
SV2V_IMAGE := sv2v:latest
OPENSTA_IMAGE := opensta:latest

# rtl-toolkit root (shared cache location across examples)
RTL_TOOLKIT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# PDK cache root on host (shared across examples)
PDK_ROOT_HOST ?= $(RTL_TOOLKIT_ROOT)/.pdk

# Only mount PDK if it exists (avoid Docker creating root-owned dirs)
PDK_MOUNT := $(if $(wildcard $(PDK_ROOT_HOST)),-v "$(PDK_ROOT_HOST)":/pdk -e PDK_ROOT=/pdk,)

# SBY Docker command
SBY_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(OSS_CAD_IMAGE) sby

# EQY Docker command
EQY_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(OSS_CAD_IMAGE) eqy

# SV2V Docker command
SV2V_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(SV2V_IMAGE) sv2v

# Yosys Docker command (for synthesis)
YOSYS_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	$(PDK_MOUNT) \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(OSS_CAD_IMAGE) yosys


# OpenSTA Docker command
# NOTE: use non-interactive execution + -exit so sta never drops to a Tcl prompt.
OPENSTA_DOCKER := docker run --rm \
	-v "$(PROJECT_ROOT)":/work \
	$(PDK_MOUNT) \
	-e HOME=$(CURRENT_DIR) \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(OPENSTA_IMAGE) sta -no_splash -exit

# Auto-detect display environment (X11 socket vs networked/VNC)
ifeq ($(shell test -S /tmp/.X11-unix/X$(patsubst :%,%,$(DISPLAY)) && echo has_x11_socket),has_x11_socket)
    # X11 socket environment (e.g., WSL2/WSLg, native Linux with X11)
    GTKWAVES_DOCKER := docker run --rm -it \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        $(if $(wildcard /mnt/wslg),-v /mnt/wslg:/mnt/wslg) \
        $(if $(WAYLAND_DISPLAY),-v $(XDG_RUNTIME_DIR):$(XDG_RUNTIME_DIR)) \
        -e DISPLAY -e WAYLAND_DISPLAY -e XDG_RUNTIME_DIR \
        -v "$(PROJECT_ROOT)":/work \
        -e HOME=$(CURRENT_DIR) \
        -w $(CURRENT_DIR) \
        --user $(shell id -u):$(shell id -g) \
        $(GTK_WAVES_IMAGE) gtkwave
else
    # Networked display environment (e.g., dev container VNC)
    GTKWAVES_DOCKER := docker run --rm -it \
        --network host \
        -e DISPLAY=$(DISPLAY) \
        $(if $(wildcard $(HOME)/.Xauthority),-v "$(HOME)/.Xauthority:$(HOME)/.Xauthority:ro") \
        -v "$(PROJECT_ROOT)":/work \
        -e HOME=$(CURRENT_DIR) \
        -w $(CURRENT_DIR) \
        --user $(shell id -u):$(shell id -g) \
        $(GTK_WAVES_IMAGE) gtkwave
endif


# Common rules
.PHONY: clean rebuild build run waves formal formal-cover formal-waves waves-list waves-cover waves-bmc lec lec-waves synth sv2v pdk-sky130 sta

clean:
	@# Clean Verilator artifacts
	rm -rf obj_dir .cache *.vcd
	@# Clean formal verification artifacts
	rm -rf *_bmc *_cover *_prove *_live
	rm -rf sby-* *.xml *.sqlite *.smtc *.yw *_tb.v
	rm -rf status status.* PASS FAIL UNKNOWN logfile.txt config.sby
	@# Clean equivalence checking artifacts
	rm -rf eqy-* *.eqy.log
	@# Clean synthesis artifacts
	rm -f *_synth*.v _synth*.sv*.log
	@# Remove any directories that match .sby/.eqy basenames (SBY/EQY output directories)
	@for f in *.sby; do [ -f "$$f" ] && rm -rf "$$(basename "$$f" .sby)" || true; done 2>/dev/null || true
	@for f in *.eqy; do [ -f "$$f" ] && rm -rf "$$(basename "$$f" .eqy)" || true; done 2>/dev/null || true
	# Clean up scratch / temporary files
	rm -rf temp/ tmp/ scratch/ build_*/ 


rebuild:
	$(MAKE) clean
	$(MAKE) build

build: obj_dir/run_sim

obj_dir/run_sim: $(FILE_LIST)
	$(VERILATOR_DOCKER) $(VERILATOR_BUILD_ARGS) $(VERILATOR_INCLUDE_ARGS) $(FILE_LIST)

run: obj_dir/run_sim
	obj_dir/run_sim $(PLUSARGS)

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

# Logical Equivalence Checking (LEC) rules
lec: $(EQY_FILE)
	$(EQY_DOCKER) -f $(EQY_FILE)

# Synthesis rules
synth: $(SYNTH_SCRIPT)
	$(YOSYS_DOCKER) -s $(SYNTH_SCRIPT)

lec-waves: $(EQY_FILE)
	@# List and select VCD files from equivalence checking
	@EQY_BASE=$$(basename $(EQY_FILE) .eqy); \
	if [ -n "$(WAVE)" ]; then \
		if [ -f "$(WAVE)" ]; then \
			echo "Opening specified trace: $(WAVE)"; \
			$(GTKWAVES_DOCKER) $(WAVE); \
		else \
			echo "Error: Specified wave file '$(WAVE)' not found."; \
			exit 1; \
		fi \
	else \
		TRACE_FILES=$$(find "$${EQY_BASE}" -name "*.vcd" 2>/dev/null | sort); \
		if [ -n "$$TRACE_FILES" ]; then \
			TRACE_COUNT=$$(echo "$$TRACE_FILES" | wc -l); \
			if [ $$TRACE_COUNT -eq 1 ]; then \
				TRACE_FILE=$$TRACE_FILES; \
				echo "Opening equivalence trace: $$TRACE_FILE"; \
				$(GTKWAVES_DOCKER) $$TRACE_FILE; \
			else \
				echo "Multiple VCD files found:"; \
				echo "$$TRACE_FILES" | nl -w2 -s': '; \
				echo ""; \
				echo "Usage: make lec-waves WAVE=<filename>     # Open specific file"; \
				echo ""; \
				echo "Opening first trace: $$(echo "$$TRACE_FILES" | head -1)"; \
				$(GTKWAVES_DOCKER) $$(echo "$$TRACE_FILES" | head -1); \
			fi \
		else \
			echo "No VCD trace files found. Run 'make lec' first."; \
		fi \
	fi

# SystemVerilog to Verilog conversion rules
# Usage: make sv2v SV2V_FILES="file1.sv file2.sv" [SV2V_OUT_DIR=output_dir]
# If SV2V_OUT_DIR is not specified, creates .v files adjacent to .sv files
sv2v:
	@if [ -z "$(SV2V_FILES)" ]; then \
		echo "Error: SV2V_FILES variable not set. Please specify SystemVerilog files to convert."; \
		echo "Usage: make sv2v SV2V_FILES=\"file1.sv file2.sv\" [SV2V_OUT_DIR=output_dir]"; \
		exit 1; \
	fi
	@echo "Converting $(SV2V_FILES) to adjacent .v files..."; \
	$(SV2V_DOCKER) --write=adjacent $(SV2V_FILES); \
	if [ -n "$(SV2V_OUT_DIR)" ]; then \
		echo "Moving generated .v files to $(SV2V_OUT_DIR)..."; \
		mkdir -p "$(SV2V_OUT_DIR)"; \
		for f in $(SV2V_FILES); do \
			outf="$${f%.sv}.v"; \
			if [ -f "$$outf" ]; then \
				mv "$$outf" "$(SV2V_OUT_DIR)/"; \
			else \
				echo "Warning: Output file $$outf not found."; \
			fi; \
		done; \
	fi

# --- Sky130 PDK (prebuilt via ciel) ---
# Fetches a prebuilt Sky130 PDK into the shared cache under rtl-toolkit/.pdk.
# This is the smallest practical way to get real Liberty .lib files for OpenSTA.
SKY130_PDK_FAMILY ?= sky130
SKY130_PDK_VARIANT ?= sky130A
SKY130_CIEL_VERSION ?=
SKY130_HD_LIB_DIR_HOST ?= $(PDK_ROOT_HOST)/$(SKY130_PDK_VARIANT)/libs.ref/sky130_fd_sc_hd/lib

pdk-sky130:
	@mkdir -p "$(PDK_ROOT_HOST)"
	@if ls "$(SKY130_HD_LIB_DIR_HOST)"/*.lib >/dev/null 2>&1; then \
		echo "Sky130 PDK already present (found .lib under $(SKY130_HD_LIB_DIR_HOST))"; \
	else \
		echo "Fetching Sky130 PDK via ciel (this can take a while)..."; \
		docker run --rm -t \
			-v "$(PDK_ROOT_HOST)":/pdk \
			-e HOME=/tmp \
			$(OSS_CAD_IMAGE) bash -lc 'set -e; \
				python3 -m pip install --break-system-packages --user -q ciel; \
				CIEL=/tmp/.local/bin/ciel; \
				VER="$(SKY130_CIEL_VERSION)"; \
				if [ -z "$$VER" ]; then VER=$$($$CIEL ls-remote --pdk-family=$(SKY130_PDK_FAMILY) | head -n 1); fi; \
				echo "Using ciel version: $$VER"; \
				$$CIEL enable --pdk-root /pdk --pdk-family=$(SKY130_PDK_FAMILY) -l sky130_fd_sc_hd "$$VER"; \
			'; \
	fi

# --- OpenSTA ---
# Usage: make sta STA_SCRIPT=path/to/run.tcl
# Optional: set STA_OUT=path/to/report.txt to capture stdout.
sta:
	@if [ -z "$(STA_SCRIPT)" ]; then \
		echo "Error: STA_SCRIPT not set."; \
		echo "Usage: make sta STA_SCRIPT=run.tcl"; \
		exit 1; \
	fi
	@if [ ! -f "$(STA_SCRIPT)" ]; then \
		echo "Error: STA_SCRIPT '$(STA_SCRIPT)' not found."; \
		exit 1; \
	fi
	@if [ -n "$(STA_OUT)" ]; then \
		$(OPENSTA_DOCKER) "$(STA_SCRIPT)" > "$(STA_OUT)"; \
		echo "Wrote $(STA_OUT)"; \
	else \
		$(OPENSTA_DOCKER) "$(STA_SCRIPT)"; \
	fi

endif # TOOL_FLOWS_MK