IVERILOG = iverilog
VVP = vvp
FLAGS = -g2012

SRC_DIR = src
TB_DIR = tb
BUILD_DIR = build

SRCS = $(SRC_DIR)/Top_Module.sv $(SRC_DIR)/Controller.sv $(SRC_DIR)/FIFO_All.sv $(SRC_DIR)/FIFO.sv $(SRC_DIR)/MAC_Unit.sv $(SRC_DIR)/SKEW_Unit.sv $(SRC_DIR)/SRAM.sv $(SRC_DIR)/SYSTOLIC_ARRAY.sv

TB = $(TB_DIR)/tb_Top_module.sv

OUT = $(BUILD_DIR)/tb_Top_module.vvp

# The testbench $dumpfile()s a bare filename, so vvp must be run with
# BUILD_DIR as its cwd for the .vcd to land next to the .vvp.

test: $(OUT)
	cd $(BUILD_DIR) && $(VVP) $(notdir $(OUT))

$(OUT): $(SRCS) $(TB) | $(BUILD_DIR)
	$(IVERILOG) $(FLAGS) -o $(OUT) $(SRCS) $(TB)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

wave: $(OUT)
	cd $(BUILD_DIR) && $(VVP) -n $(notdir $(OUT))
	gtkwave $(BUILD_DIR)/tb_Top_module.vcd

clean:
	rm -rf $(BUILD_DIR)

.PHONY: test wave clean