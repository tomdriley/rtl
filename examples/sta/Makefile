include ../../tools/tool_flows.mk

SYNTH_SCRIPT := synth.ys
STA_SCRIPT := sta.tcl
STA_OUT := scratch/sta.rpt

make-scratch:
	@# Create a scratch directory for synthesis/STA outputs
	@mkdir -p scratch

# Add prerequisites to shared targets (no extra recipes -> no override warnings)
synth: make-scratch pdk-sky130

sta: synth
