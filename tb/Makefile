SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../rtl/csr_regs.v
VERILOG_SOURCES += $(PWD)/../rtl/axis_skid_fifo.v
VERILOG_SOURCES += $(PWD)/../rtl/scrambler_128b.v
VERILOG_SOURCES += $(PWD)/../rtl/crc32_128b.v
VERILOG_SOURCES += $(PWD)/../rtl/fec_conv_enc.v
VERILOG_SOURCES += $(PWD)/../rtl/qam_mapper_axis.v
VERILOG_SOURCES += $(PWD)/../rtl/tx_6g_baseband_top.v

TOPLEVEL = tx_6g_baseband_top
MODULE = test_tx_6g_baseband

ifeq ($(SIM),verilator)
EXTRA_ARGS += --Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

GL_NL ?= ../librelane/runs/latest/final/nl/tx_6g_baseband_top.nl.v
PDK_SC_V ?= $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog

.PHONY: sim-gl
sim-gl:
	$(MAKE) SIM=icarus \
	  VERILOG_SOURCES="$(PDK_SC_V)/primitives.v $(PDK_SC_V)/gf180mcu_fd_sc_mcu7t5v0.v $(GL_NL)" \
	  COMPILE_ARGS="-DFUNCTIONAL -DUNIT_DELAY=#1 -DUSE_POWER_PINS=0"
