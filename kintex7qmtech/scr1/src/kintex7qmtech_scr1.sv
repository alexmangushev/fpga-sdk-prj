/// Copyright by Syntacore LLC © 2016, 2017, 2018, 2021. See LICENSE for details
/// @file       <nexys4ddr_scr1.sv>
/// @brief      Top-level entity with SCR1 for Digilent Nexys 4 DDR board
///

`include "scr1_arch_types.svh"
`include "scr1_arch_custom.svh"
`include "scr1_arch_description.svh"

parameter bit [31:0] FPGA_NEXYS_A7_SOC_ID           = `SCR1_PTFM_SOC_ID;
parameter bit [31:0] FPGA_NEXYS_A7_BLD_ID           = `SCR1_PTFM_BLD_ID;
parameter bit [31:0] FPGA_NEXYS_A7_CORE_CLK_FREQ    = `SCR1_PTFM_CORE_CLK_FREQ;


module kintex7qmtech_scr1 (
    // === CLOCK ===========================================
    input  logic                    CLK50MHZ,
    // === RESET ===========================================
    input  logic                    CPU_RESETn,
    // === DDR3SDRAM ======================================
    output logic                    DDR3_CK_N,
    output logic                    DDR3_CK_P,
    output logic                    DDR3_CKE,
    output logic                    DDR3_RESET_N,
    //output logic                    DDR3_CS_N,
    output logic                    DDR3_WE_N,
    output logic                    DDR3_RAS_N,
    output logic                    DDR3_CAS_N,
    output logic [2:0]              DDR3_BA,
    output logic [13:0]             DDR3_ADDR,
    output logic [1:0]              DDR3_DM,
    inout  logic [15:0]             DDR3_DQ,
    inout  logic [1:0]              DDR3_DQS_P,
    inout  logic [1:0]              DDR3_DQS_N,
    output logic                    DDR3_ODT,
    // === LEDs ============================================
    output logic    [3:2]           LED,
    // === PMOD D ==========================================
    inout  logic    [ 3:0]          JC,
    // === FTDI UART =======================================
    input  logic                    FTDI_TXD,
    output logic                    FTDI_RXD
);

//=======================================================
//  PARAMETER declarations
//=======================================================


//=======================================================
//  Signals / Variables declarations
//=======================================================
logic                               pwrup_rst_n;
logic                               cpu_clk;
logic                               extn_rst_n;
logic [1:0]                         extn_rst_n_sync;
logic                               hard_rst_n;
logic [3:0]                         hard_rst_n_count;
logic                               soc_rst_n;
logic                               cpu_reset;
`ifdef SCR1_DBG_EN
logic                               sys_rst_n;
`endif // SCR1_DBG_EN

// --- SCR1 ---------------------------------------------

// AXI IMEM
logic [ 2:0]                        axi_imem_arid;
logic [31:0]                        axi_imem_araddr;
logic                               axi_imem_arvalid;
logic                               axi_imem_arready;
logic [ 7:0]                        axi_imem_arlen;
logic [ 2:0]                        axi_imem_arsize;
logic [ 1:0]                        axi_imem_arburst;
logic [ 3:0]                        axi_imem_arcache;
logic [ 2:0]                        axi_imem_rid;
logic [31:0]                        axi_imem_rdata;
logic                               axi_imem_rvalid;
logic                               axi_imem_rready;
logic [ 1:0]                        axi_imem_rresp;
logic                               axi_imem_rlast;
// AXI DMEM
logic [ 1:0]                        axi_dmem_awid;
logic [31:0]                        axi_dmem_awaddr;
logic                               axi_dmem_awvalid;
logic                               axi_dmem_awready;
logic [ 7:0]                        axi_dmem_awlen;
logic [ 2:0]                        axi_dmem_awsize;
logic [ 1:0]                        axi_dmem_awburst;
logic [ 3:0]                        axi_dmem_awcache;
logic [31:0]                        axi_dmem_wdata;
logic [ 3:0]                        axi_dmem_wstrb;
logic                               axi_dmem_wvalid;
logic                               axi_dmem_wready;
logic                               axi_dmem_wlast;
logic [ 1:0]                        axi_dmem_bid;
logic [ 1:0]                        axi_dmem_bresp;
logic                               axi_dmem_bvalid;
logic                               axi_dmem_bready;
logic [ 1:0]                        axi_dmem_arid;
logic [31:0]                        axi_dmem_araddr;
logic                               axi_dmem_arvalid;
logic                               axi_dmem_arready;
logic [ 7:0]                        axi_dmem_arlen;
logic [ 2:0]                        axi_dmem_arsize;
logic [ 1:0]                        axi_dmem_arburst;
logic [ 3:0]                        axi_dmem_arcache;
logic [ 1:0]                        axi_dmem_rid;
logic [31:0]                        axi_dmem_rdata;
logic                               axi_dmem_rvalid;
logic                               axi_dmem_rready;
logic [ 1:0]                        axi_dmem_rresp;
logic                               axi_dmem_rlast;

`ifdef SCR1_IPIC_EN
logic [SCR1_IRQ_LINES_NUM-1:0]      scr1_irq;
`else
logic                               scr1_irq;
`endif // SCR1_IPIC_EN

// --- DDR3 SDRAM ---------------------------------------
logic                               ddr3_init_complete;

// --- JTAG ---------------------------------------------
`ifdef SCR1_DBG_EN
//logic                               jtag_srst_n;
logic                               jtag_trst_n;
logic                               jtag_tck;
logic                               jtag_tms;
logic                               jtag_tdi;
logic                               jtag_tdo;
logic                               jtag_tdo_en;
`endif // SCR1_DBG_EN

// --- UART ---------------------------------------------
logic                               uart_rxd;   // -> UART
logic                               uart_txd;   // <- UART
logic                               uart_rts_n; // <- UART
logic                               uart_dtr_n; // <- UART
logic                               uart_irq;

// --- Heartbeat ----------------------------------------
logic [31:0]                        rtc_counter;
logic                               tick_2Hz;
logic                               heartbeat;


//=======================================================
//  Resets
//=======================================================
always_ff @(posedge cpu_clk, negedge pwrup_rst_n)
begin
    if (~pwrup_rst_n) begin
        extn_rst_n_sync     <= '0;
    end else begin
        extn_rst_n_sync[0]  <= CPU_RESETn;
        extn_rst_n_sync[1]  <= extn_rst_n_sync[0];
    end
end
assign extn_rst_n = extn_rst_n_sync[1];

always_ff @(posedge cpu_clk, negedge pwrup_rst_n)
begin
    if (~pwrup_rst_n) begin
        hard_rst_n          <= 1'b0;
        hard_rst_n_count    <= '0;
    end else begin
        if (hard_rst_n) begin
            // hard_rst_n == 1 - de-asserted
            hard_rst_n          <= extn_rst_n;
            hard_rst_n_count    <= '0;
        end else begin
            // hard_rst_n == 0 - asserted
            if (extn_rst_n) begin
                if (hard_rst_n_count == '1) begin
                    // If extn_rst_n = 1 at least 16 clocks,
                    // de-assert hard_rst_n
                    hard_rst_n          <= 1'b1;
                end else begin
                    hard_rst_n_count    <= hard_rst_n_count + 1;
                end
            end else begin
                // If extn_rst_n is asserted within 16-cycles window -> start
                // counting from the beginning
                hard_rst_n_count    <= '0;
            end
        end
    end
end

`ifdef SCR1_DBG_EN
assign soc_rst_n = sys_rst_n;
`else
assign soc_rst_n = hard_rst_n;
`endif // SCR1_DBG_EN

//=======================================================
//  Heartbeat
//=======================================================
always_ff @(posedge cpu_clk, negedge hard_rst_n)
begin
    if (~hard_rst_n) begin
        rtc_counter     <= '0;
        tick_2Hz        <= 1'b0;
    end
    else begin
        if (rtc_counter == '0) begin
            rtc_counter <= (FPGA_NEXYS_A7_CORE_CLK_FREQ/2);
            tick_2Hz    <= 1'b1;
        end
        else begin
            rtc_counter <= rtc_counter - 1'b1;
            tick_2Hz    <= 1'b0;
        end
    end
end

always_ff @(posedge cpu_clk, negedge hard_rst_n)
begin
    if (~hard_rst_n) begin
        heartbeat       <= 1'b0;
    end
    else begin
        if (tick_2Hz) begin
            heartbeat   <= ~heartbeat;
        end
    end
end

//=======================================================
//  SCR1 Core's Processor Cluster
//=======================================================

assign scr1_irq = {31'd0, uart_irq};


scr1_top_axi
i_scr1 (
    // Common
    .pwrup_rst_n                (pwrup_rst_n),
    .rst_n                      (hard_rst_n),
    .cpu_rst_n                  (~cpu_reset),
    .test_mode                  (1'b0),
    .test_rst_n                 (1'b1),
    .clk                        (cpu_clk),
    .rtc_clk                    (1'b0),
`ifdef SCR1_DBG_EN
    .sys_rst_n_o                (sys_rst_n),
    .sys_rdc_qlfy_o             (),
`endif // SCR1_DBG_EN

    // Fuses
    .fuse_mhartid               ('0),
`ifdef SCR1_DBG_EN
    .fuse_idcode                (`SCR1_TAP_IDCODE),
`endif // SCR1_DBG_EN

    // IRQ
`ifdef SCR1_IPIC_EN
    .irq_lines                  (scr1_irq),
`else
    .ext_irq                    (scr1_irq),
`endif // SCR1_IPIC_EN
    .soft_irq                   (1'b0),

`ifdef SCR1_DBG_EN
    // Debug Interface - JTAG I/F
    .trst_n                     (jtag_trst_n),
    .tck                        (jtag_tck),
    .tms                        (jtag_tms),
    .tdi                        (jtag_tdi),
    .tdo                        (jtag_tdo),
    .tdo_en                     (jtag_tdo_en),
`endif // SCR1_DBG_EN

    // Instruction Memory Interface
    .io_axi_imem_awid           (),
    .io_axi_imem_awaddr         (),
    .io_axi_imem_awlen          (),
    .io_axi_imem_awsize         (),
    .io_axi_imem_awburst        (),
    .io_axi_imem_awlock         (),
    .io_axi_imem_awcache        (),
    .io_axi_imem_awprot         (),
    .io_axi_imem_awregion       (),
    .io_axi_imem_awuser         (),
    .io_axi_imem_awqos          (),
    .io_axi_imem_awvalid        (),
    .io_axi_imem_awready        ('0),
    .io_axi_imem_wdata          (),
    .io_axi_imem_wstrb          (),
    .io_axi_imem_wlast          (),
    .io_axi_imem_wuser          (),
    .io_axi_imem_wvalid         (),
    .io_axi_imem_wready         ('0),
    .io_axi_imem_bid            ('0),
    .io_axi_imem_bresp          ('0),
    .io_axi_imem_bvalid         ('0),
    .io_axi_imem_buser          ('0),
    .io_axi_imem_bready         (),
    .io_axi_imem_arid           (axi_imem_arid),
    .io_axi_imem_araddr         (axi_imem_araddr),
    .io_axi_imem_arlen          (axi_imem_arlen),
    .io_axi_imem_arsize         (axi_imem_arsize),
    .io_axi_imem_arburst        (axi_imem_arburst),
    .io_axi_imem_arlock         (),
    .io_axi_imem_arcache        (),
    .io_axi_imem_arprot         (),
    .io_axi_imem_arregion       (),
    .io_axi_imem_aruser         (),
    .io_axi_imem_arqos          (),
    .io_axi_imem_arvalid        (axi_imem_arvalid),
    .io_axi_imem_arready        (axi_imem_arready),
    .io_axi_imem_rid            (axi_imem_rid),
    .io_axi_imem_rdata          (axi_imem_rdata),
    .io_axi_imem_rresp          (axi_imem_rresp),
    .io_axi_imem_rlast          (axi_imem_rlast),
    .io_axi_imem_ruser          ('0),
    .io_axi_imem_rvalid         (axi_imem_rvalid),
    .io_axi_imem_rready         (axi_imem_rready),

    // Data Memory Interface
    .io_axi_dmem_awid           (axi_dmem_awid),
    .io_axi_dmem_awaddr         (axi_dmem_awaddr),
    .io_axi_dmem_awlen          (axi_dmem_awlen),
    .io_axi_dmem_awsize         (axi_dmem_awsize),
    .io_axi_dmem_awburst        (axi_dmem_awburst),
    .io_axi_dmem_awlock         (),
    .io_axi_dmem_awcache        (),
    .io_axi_dmem_awprot         (),
    .io_axi_dmem_awregion       (),
    .io_axi_dmem_awuser         (),
    .io_axi_dmem_awqos          (),
    .io_axi_dmem_awvalid        (axi_dmem_awvalid),
    .io_axi_dmem_awready        (axi_dmem_awready),
    .io_axi_dmem_wdata          (axi_dmem_wdata),
    .io_axi_dmem_wstrb          (axi_dmem_wstrb),
    .io_axi_dmem_wlast          (axi_dmem_wlast),
    .io_axi_dmem_wuser          (),
    .io_axi_dmem_wvalid         (axi_dmem_wvalid),
    .io_axi_dmem_wready         (axi_dmem_wready),
    .io_axi_dmem_bid            (axi_dmem_bid),
    .io_axi_dmem_bresp          (axi_dmem_bresp),
    .io_axi_dmem_bvalid         (axi_dmem_bvalid),
    .io_axi_dmem_buser          ('0),
    .io_axi_dmem_bready         (axi_dmem_bready),
    .io_axi_dmem_arid           (axi_dmem_arid),
    .io_axi_dmem_araddr         (axi_dmem_araddr),
    .io_axi_dmem_arlen          (axi_dmem_arlen),
    .io_axi_dmem_arsize         (axi_dmem_arsize),
    .io_axi_dmem_arburst        (axi_dmem_arburst),
    .io_axi_dmem_arlock         (),
    .io_axi_dmem_arcache        (),
    .io_axi_dmem_arprot         (),
    .io_axi_dmem_arregion       (),
    .io_axi_dmem_aruser         (),
    .io_axi_dmem_arqos          (),
    .io_axi_dmem_arvalid        (axi_dmem_arvalid),
    .io_axi_dmem_arready        (axi_dmem_arready),
    .io_axi_dmem_rid            (axi_dmem_rid),
    .io_axi_dmem_rdata          (axi_dmem_rdata),
    .io_axi_dmem_rresp          (axi_dmem_rresp),
    .io_axi_dmem_rlast          (axi_dmem_rlast),
    .io_axi_dmem_ruser          ('0),
    .io_axi_dmem_rvalid         (axi_dmem_rvalid),
    .io_axi_dmem_rready         (axi_dmem_rready)
);

//=======================================================
//  FPGA Platform's System-on-Programmable-Chip (SOPC)
//=======================================================
kintex7qmtech_sopc
i_soc (
    // CLOCKs & RESETs
    .pwrup_rst_n_o              (pwrup_rst_n        ),
    .soc_rst_n                  (soc_rst_n          ),
    .osc_clk                    (CLK50MHZ          ),
    .cpu_clk_o                  (cpu_clk            ),
    .cpu_reset_o                (cpu_reset          ),
    // DDR3 SDRAM
    .ddr3_ck_p                  (DDR3_CK_P          ),
    .ddr3_ck_n                  (DDR3_CK_N          ),
    .ddr3_cke                   (DDR3_CKE           ),
    .ddr3_reset_n               (DDR3_RESET_N       ),
    //.ddr3_cs_n                  (DDR3_CS_N          ),
    .ddr3_we_n                  (DDR3_WE_N          ),
    .ddr3_ras_n                 (DDR3_RAS_N         ),
    .ddr3_cas_n                 (DDR3_CAS_N         ),
    .ddr3_ba                    (DDR3_BA            ),
    .ddr3_addr                  (DDR3_ADDR          ),
    .ddr3_dm                    (DDR3_DM            ),
    .ddr3_dq                    (DDR3_DQ            ),
    .ddr3_dqs_p                 (DDR3_DQS_P         ),
    .ddr3_dqs_n                 (DDR3_DQS_N         ),
    .ddr3_odt                   (DDR3_ODT           ),
    // DDR3 SDRAM initialization/calibration complete
    .ddr3_init_complete         (ddr3_init_complete ),
    //.ddr2_sdram_addr            (ddr2_sdram_addr    ),
    //.ddr2_sdram_ba              (ddr2_sdram_ba      ),
    //.ddr2_sdram_cas_n           (ddr2_sdram_cas_n   ),
    //.ddr2_sdram_ck_n            (ddr2_sdram_ck_n    ),
    //.ddr2_sdram_ck_p            (ddr2_sdram_ck_p    ),
    //.ddr2_sdram_cke             (ddr2_sdram_cke     ),
    //.ddr2_sdram_cs_n            (ddr2_sdram_cs_n    ),
    //.ddr2_sdram_dm              (ddr2_sdram_dm      ),
    //.ddr2_sdram_dq              (ddr2_sdram_dq      ),
    //.ddr2_sdram_dqs_n           (ddr2_sdram_dqs_n   ),
    //.ddr2_sdram_dqs_p           (ddr2_sdram_dqs_p   ),
    //.ddr2_sdram_odt             (ddr2_sdram_odt     ),
    //.ddr2_sdram_ras_n           (ddr2_sdram_ras_n   ),
    //.ddr2_sdram_we_n            (ddr2_sdram_we_n    ),
    //.ddr2_calib                 (LED[0]             ),
    // AXI I-MEM
    .axi_imem_arid              (axi_imem_arid      ),
    .axi_imem_araddr            (axi_imem_araddr    ),
    .axi_imem_arlen             (axi_imem_arlen     ),
    .axi_imem_arsize            (axi_imem_arsize    ),
    .axi_imem_arburst           (axi_imem_arburst   ),
    .axi_imem_arlock            ('0                 ),
    .axi_imem_arcache           ('d3                ),
    .axi_imem_arprot            ('0                 ),
    .axi_imem_arqos             ('0                 ),
    .axi_imem_arvalid           (axi_imem_arvalid   ),
    .axi_imem_arready           (axi_imem_arready   ),
    .axi_imem_rid               (axi_imem_rid       ),
    .axi_imem_rdata             (axi_imem_rdata     ),
    .axi_imem_rresp             (axi_imem_rresp     ),
    .axi_imem_rlast             (axi_imem_rlast     ),
    .axi_imem_rvalid            (axi_imem_rvalid    ),
    .axi_imem_rready            (axi_imem_rready    ),
    // AXI D-MEM
    .axi_dmem_awid              (axi_dmem_awid      ),
    .axi_dmem_awaddr            (axi_dmem_awaddr    ),
    .axi_dmem_awlen             (axi_dmem_awlen     ),
    .axi_dmem_awsize            (axi_dmem_awsize    ),
    .axi_dmem_awburst           (axi_dmem_awburst   ),
    .axi_dmem_awlock            ('0                 ),
    .axi_dmem_awcache           ('d3                ),
    .axi_dmem_awprot            ('0                 ),
    .axi_dmem_awqos             ('0                 ),
    .axi_dmem_awvalid           (axi_dmem_awvalid   ),
    .axi_dmem_awready           (axi_dmem_awready   ),
    .axi_dmem_wdata             (axi_dmem_wdata     ),
    .axi_dmem_wstrb             (axi_dmem_wstrb     ),
    .axi_dmem_wlast             (axi_dmem_wlast     ),
    .axi_dmem_wvalid            (axi_dmem_wvalid    ),
    .axi_dmem_wready            (axi_dmem_wready    ),
    .axi_dmem_bid               (axi_dmem_bid       ),
    .axi_dmem_bresp             (axi_dmem_bresp     ),
    .axi_dmem_bvalid            (axi_dmem_bvalid    ),
    .axi_dmem_bready            (axi_dmem_bready    ),
    .axi_dmem_arid              (axi_dmem_arid      ),
    .axi_dmem_araddr            (axi_dmem_araddr    ),
    .axi_dmem_arlen             (axi_dmem_arlen     ),
    .axi_dmem_arsize            (axi_dmem_arsize    ),
    .axi_dmem_arburst           (axi_dmem_arburst   ),
    .axi_dmem_arlock            ('0                 ),
    .axi_dmem_arcache           ('d3                ),
    .axi_dmem_arprot            ('0                 ),
    .axi_dmem_arqos             ('0                 ),
    .axi_dmem_arvalid           (axi_dmem_arvalid   ),
    .axi_dmem_arready           (axi_dmem_arready   ),
    .axi_dmem_rid               (axi_dmem_rid       ),
    .axi_dmem_rdata             (axi_dmem_rdata     ),
    .axi_dmem_rresp             (axi_dmem_rresp     ),
    .axi_dmem_rlast             (axi_dmem_rlast     ),
    .axi_dmem_rvalid            (axi_dmem_rvalid    ),
    .axi_dmem_rready            (axi_dmem_rready    ),
    // UART
    .uart_rxd                   (uart_rxd),
    .uart_txd                   (uart_txd),
    .uart_rtsn                  (uart_rts_n),
    .uart_ctsn                  (uart_rts_n),
    .uart_dtrn                  (uart_dtr_n),
    .uart_dsrn                  (uart_dtr_n),
    .uart_ri                    (1'b1),
    .uart_dcdn                  (uart_dtr_n),
    .uart_baudoutn              (),
    .uart_ddis                  (),
    .uart_out1n                 (),
    .uart_out2n                 (),
    .uart_rxrdyn                (),
    .uart_txrdyn                (),
    .uart_irq                   (uart_irq),
    // IDs
    .soc_id_tri_i               (FPGA_NEXYS_A7_SOC_ID),
    .bld_id_tri_i               (FPGA_NEXYS_A7_BLD_ID),
    .core_clk_freq_tri_i        (FPGA_NEXYS_A7_CORE_CLK_FREQ)
);

//==========================================================
// JTAG
//==========================================================
`ifdef SCR1_DBG_EN
// JTAG pin-out PMOD-JTAG-DIGILENT-HS2
assign jtag_trst_n      = 1'b1;
assign jtag_tck         = JC[3];    // PMOD JC.pin4
assign jtag_tms         = JC[0];    // PMOD JC.pin1
assign jtag_tdi         = JC[1];    // PMOD JC.pin2
assign JC[2]            = (jtag_tdo_en == 1'b1) ? jtag_tdo : 1'bZ; // PMOD JC.pin3
`else // SCR1_DBG_EN
assign JC               = 'Z;
`endif // SCR1_DBG_EN

//==========================================================
// UART
//==========================================================
assign uart_rxd         = FTDI_TXD;
assign FTDI_RXD         = uart_txd;

//==========================================================
// LEDs
//==========================================================
assign LED[2]           =  ddr3_init_complete;
assign LED[3]           =  heartbeat;
//assign LED[2]           = ~hard_rst_n;

//==========================================================
// DIP Switch
//==========================================================

//==========================================================
// Buttons
//==========================================================

endmodule : kintex7qmtech_scr1
