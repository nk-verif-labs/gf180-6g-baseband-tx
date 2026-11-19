// ============================================================================
// Module: tx_6g_baseband_top
// Description: GF180MCU 6G Baseband & High-Throughput Data-Transfer Engine
//              128-bit AXI4-Stream @ 50 MHz (6.4 Gbps peak internal datapath)
//              Pipeline: Skid/FIFO -> Scrambler -> CRC-32 -> FEC -> QAM Mapper
// ============================================================================
`timescale 1ns / 1ps

module tx_6g_baseband_top (
    input  wire         clk,
    input  wire         rst_n,

    // AXI4-Lite Control & Status Slave
    input  wire [3:0]   s_axil_awaddr,
    input  wire         s_axil_awvalid,
    output wire         s_axil_awready,
    input  wire [31:0]  s_axil_wdata,
    input  wire [3:0]   s_axil_wstrb,
    input  wire         s_axil_wvalid,
    output wire         s_axil_wready,
    output wire [1:0]   s_axil_bresp,
    output wire         s_axil_bvalid,
    input  wire         s_axil_bready,
    input  wire [3:0]   s_axil_araddr,
    input  wire         s_axil_arvalid,
    output wire         s_axil_arready,
    output wire [31:0]  s_axil_rdata,
    output wire [1:0]   s_axil_rresp,
    output wire         s_axil_rvalid,
    input  wire         s_axil_rready,

    // AXI4-Stream 128-bit Payload Input
    input  wire [127:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,

    // AXI4-Stream 128-bit Baseband Output
    output wire [127:0] m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,
    output wire         m_axis_tlast
);

    wire        ctrl_enable;
    wire        ctrl_soft_rst;
    wire        ctrl_bypass_scram;
    wire        ctrl_bypass_fec;
    wire [1:0]  ctrl_qam_mode;

    wire        fifo_full;
    wire        fifo_empty;
    wire [31:0] last_crc;
    reg  [31:0] pkt_cnt;

    // Gate input acceptance when disabled
    wire        in_tvalid = s_axis_tvalid && ctrl_enable;
    wire        in_tready;
    assign      s_axis_tready = in_tready && ctrl_enable;

    // Stage wires
    wire [127:0] fifo_tdata, scram_tdata, crc_tdata, fec_tdata;
    wire         fifo_tvalid, fifo_tready, fifo_tlast;
    wire         scram_tvalid, scram_tready, scram_tlast;
    wire         crc_tvalid, crc_tready, crc_tlast;
    wire         fec_tvalid, fec_tready, fec_tlast;

    wire tx_busy = fifo_tvalid || scram_tvalid || crc_tvalid || fec_tvalid || m_axis_tvalid;

    always @(posedge clk) begin
        if (!rst_n || ctrl_soft_rst) begin
            pkt_cnt <= 32'd0;
        end else if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
            pkt_cnt <= pkt_cnt + 1'b1;
        end
    end

    csr_regs u_csr (
        .clk              (clk),
        .rst_n            (rst_n),
        .s_axil_awaddr    (s_axil_awaddr),
        .s_axil_awvalid   (s_axil_awvalid),
        .s_axil_awready   (s_axil_awready),
        .s_axil_wdata     (s_axil_wdata),
        .s_axil_wstrb     (s_axil_wstrb),
        .s_axil_wvalid    (s_axil_wvalid),
        .s_axil_wready    (s_axil_wready),
        .s_axil_bresp     (s_axil_bresp),
        .s_axil_bvalid    (s_axil_bvalid),
        .s_axil_bready    (s_axil_bready),
        .s_axil_araddr    (s_axil_araddr),
        .s_axil_arvalid   (s_axil_arvalid),
        .s_axil_arready   (s_axil_arready),
        .s_axil_rdata     (s_axil_rdata),
        .s_axil_rresp     (s_axil_rresp),
        .s_axil_rvalid    (s_axil_rvalid),
        .s_axil_rready    (s_axil_rready),
        .ctrl_enable      (ctrl_enable),
        .ctrl_soft_rst    (ctrl_soft_rst),
        .ctrl_bypass_scram(ctrl_bypass_scram),
        .ctrl_bypass_fec  (ctrl_bypass_fec),
        .ctrl_qam_mode    (ctrl_qam_mode),
        .stat_tx_busy     (tx_busy),
        .stat_fifo_full   (fifo_full),
        .stat_fifo_empty  (fifo_empty),
        .stat_pkt_cnt     (pkt_cnt),
        .stat_last_crc    (last_crc)
    );

    axis_skid_fifo #(
        .DATA_W(128),
        .DEPTH (16)
    ) u_fifo (
        .clk          (clk),
        .rst_n        (rst_n),
        .soft_rst     (ctrl_soft_rst),
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tvalid(in_tvalid),
        .s_axis_tready(in_tready),
        .s_axis_tlast (s_axis_tlast),
        .m_axis_tdata (fifo_tdata),
        .m_axis_tvalid(fifo_tvalid),
        .m_axis_tready(fifo_tready),
        .m_axis_tlast (fifo_tlast),
        .fifo_full    (fifo_full),
        .fifo_empty   (fifo_empty)
    );

    scrambler_128b u_scrambler (
        .clk     (clk),
        .rst_n   (rst_n),
        .soft_rst(ctrl_soft_rst),
        .bypass  (ctrl_bypass_scram),
        .s_tdata (fifo_tdata),
        .s_tvalid(fifo_tvalid),
        .s_tready(fifo_tready),
        .s_tlast (fifo_tlast),
        .m_tdata (scram_tdata),
        .m_tvalid(scram_tvalid),
        .m_tready(scram_tready),
        .m_tlast (scram_tlast)
    );

    crc32_128b u_crc32 (
        .clk     (clk),
        .rst_n   (rst_n),
        .soft_rst(ctrl_soft_rst),
        .s_tdata (scram_tdata),
        .s_tvalid(scram_tvalid),
        .s_tready(scram_tready),
        .s_tlast (scram_tlast),
        .m_tdata (crc_tdata),
        .m_tvalid(crc_tvalid),
        .m_tready(crc_tready),
        .m_tlast (crc_tlast),
        .last_crc(last_crc)
    );

    fec_conv_enc u_fec (
        .clk     (clk),
        .rst_n   (rst_n),
        .soft_rst(ctrl_soft_rst),
        .bypass  (ctrl_bypass_fec),
        .s_tdata (crc_tdata),
        .s_tvalid(crc_tvalid),
        .s_tready(crc_tready),
        .s_tlast (crc_tlast),
        .m_tdata (fec_tdata),
        .m_tvalid(fec_tvalid),
        .m_tready(fec_tready),
        .m_tlast (fec_tlast)
    );

    qam_mapper_axis u_qam (
        .clk          (clk),
        .rst_n        (rst_n),
        .soft_rst     (ctrl_soft_rst),
        .qam_mode     (ctrl_qam_mode),
        .s_tdata      (fec_tdata),
        .s_tvalid     (fec_tvalid),
        .s_tready     (fec_tready),
        .s_tlast      (fec_tlast),
        .m_tdata      (m_axis_tdata),
        .m_tvalid     (m_axis_tvalid),
        .m_tready     (m_axis_tready),
        .m_tlast      (m_axis_tlast)
    );

endmodule
