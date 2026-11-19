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
