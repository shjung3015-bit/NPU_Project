IVERILOG = iverilog
VERILATOR = verilator
VVP = vvp
FLAGS = -g2012

SRC_DIR = src
TB_DIR = tb
BUILD_DIR = build
SVA_DIR = sva

SRCS = $(SRC_DIR)/Top_Module.sv $(SRC_DIR)/Controller.sv $(SRC_DIR)/FIFO_All.sv $(SRC_DIR)/FIFO.sv $(SRC_DIR)/MAC_Unit.sv $(SRC_DIR)/SKEW_Unit.sv $(SRC_DIR)/SRAM.sv $(SRC_DIR)/Systolic_Array.sv $(SRC_DIR)/Systolic_Core.sv $(SRC_DIR)/UART_Bridge.sv $(SRC_DIR)/UART_RX.sv $(SRC_DIR)/UART_TX.sv

TB = $(TB_DIR)/tb_Top_module.sv

OUT = $(BUILD_DIR)/tb_Top_module.vvp

SVAS = $(SVA_DIR)/bind.sv $(SVA_DIR)/FIFO_sva.sv $(SVA_DIR)/FIFO_All_sva.sv $(SVA_DIR)/SRAM_sva.sv $(SVA_DIR)/Controller_sva.sv


# The testbench $dumpfile()s a bare filename, so vvp must be run with
# BUILD_DIR as its cwd for the .vcd to land next to the .vvp.

test: $(OUT)
	cd $(BUILD_DIR) && $(VVP) $(notdir $(OUT))

$(OUT): $(SRCS) $(TB) $(SVAS) | $(BUILD_DIR)
	$(IVERILOG) $(FLAGS) -o $(OUT) $(SRCS) $(TB) $(SVAS)

test_sva: $(BUILD_DIR)
	$(VERILATOR) --binary --assert --timing -Wall -Wno-fatal \
		--top-module tb_Top_Module \
		--Mdir $(BUILD_DIR)/verilator_obj \
		$(SRCS) $(SVAS) $(TB)
	$(BUILD_DIR)/verilator_obj/Vtb_Top_Module


$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

wave: $(OUT)
	cd $(BUILD_DIR) && $(VVP) -n $(notdir $(OUT))
	gtkwave $(BUILD_DIR)/tb_Top_module.vcd

clean:
	rm -rf $(BUILD_DIR)

.PHONY: test test_sva wave clean