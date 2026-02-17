// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
// Date        : Thu Jul 24 17:45:28 2025
// Host        : IonutAvion-ro running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               e:/VivadoMigrations2025.1/ZyboZ7-Pcam-10/Zybo-Z7/hw/proj/hw.gen/sources_1/bd/system/ip/system_MIPI_D_PHY_RX_0_0/system_MIPI_D_PHY_RX_0_0_stub.v
// Design      : system_MIPI_D_PHY_RX_0_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "system_MIPI_D_PHY_RX_0_0,MIPI_DPHY_Receiver,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "MIPI_DPHY_Receiver,Vivado 2025.1" *) 
module system_MIPI_D_PHY_RX_0_0(dphy_clk_hs_p, dphy_clk_hs_n, dphy_clk_lp_p, 
  dphy_clk_lp_n, dphy_data_hs_p, dphy_data_hs_n, dphy_data_lp_p, dphy_data_lp_n, RefClk, aRst, 
  rDlyCtrlLockedOut, RxDDRClkHS, aRxClkActiveHS, aClkStopstate, aClkEnable, 
  aClkUlpsActiveNot, aRxUlpsClkNot, aClkForceRxmode, aClkErrControl, RxByteClkHS, 
  aD0Stopstate, aD0Enable, aD0UlpsActiveNot, rbD0RxDataHS, rbD0RxValidHS, rbD0RxActiveHS, 
  rbD0RxSyncHS, rbD0ErrSotHS, rbD0ErrSotSyncHS, aD0ForceRxmode, D0RxClkEsc, aD0RxDataEsc, 
  aD0RxValidEsc, aD0RxLpdtEsc, aD0RxUlpsEsc, aD0RxTriggerEsc, aD0ErrEsc, aD0ErrControl, 
  aD1Stopstate, aD1Enable, aD1UlpsActiveNot, rbD1RxDataHS, rbD1RxValidHS, rbD1RxActiveHS, 
  rbD1RxSyncHS, rbD1ErrSotHS, rbD1ErrSotSyncHS, aD1ForceRxmode, D1RxClkEsc, aD1RxDataEsc, 
  aD1RxValidEsc, aD1RxLpdtEsc, aD1RxUlpsEsc, aD1RxTriggerEsc, aD1ErrEsc, aD1ErrControl, 
  s_axi_lite_awaddr, s_axi_lite_awprot, s_axi_lite_awvalid, s_axi_lite_awready, 
  s_axi_lite_wdata, s_axi_lite_wstrb, s_axi_lite_wvalid, s_axi_lite_wready, 
  s_axi_lite_bresp, s_axi_lite_bvalid, s_axi_lite_bready, s_axi_lite_araddr, 
  s_axi_lite_arprot, s_axi_lite_arvalid, s_axi_lite_arready, s_axi_lite_rdata, 
  s_axi_lite_rresp, s_axi_lite_rvalid, s_axi_lite_rready, s_axi_lite_aclk, 
  s_axi_lite_aresetn)
/* synthesis syn_black_box black_box_pad_pin="dphy_clk_hs_p,dphy_clk_hs_n,dphy_clk_lp_p,dphy_clk_lp_n,dphy_data_hs_p[1:0],dphy_data_hs_n[1:0],dphy_data_lp_p[1:0],dphy_data_lp_n[1:0],aRst,rDlyCtrlLockedOut,aRxClkActiveHS,aClkStopstate,aClkEnable,aClkUlpsActiveNot,aRxUlpsClkNot,aClkForceRxmode,aClkErrControl,aD0Stopstate,aD0Enable,aD0UlpsActiveNot,rbD0RxDataHS[7:0],rbD0RxValidHS,rbD0RxActiveHS,rbD0RxSyncHS,rbD0ErrSotHS,rbD0ErrSotSyncHS,aD0ForceRxmode,D0RxClkEsc,aD0RxDataEsc[7:0],aD0RxValidEsc,aD0RxLpdtEsc,aD0RxUlpsEsc,aD0RxTriggerEsc[3:0],aD0ErrEsc,aD0ErrControl,aD1Stopstate,aD1Enable,aD1UlpsActiveNot,rbD1RxDataHS[7:0],rbD1RxValidHS,rbD1RxActiveHS,rbD1RxSyncHS,rbD1ErrSotHS,rbD1ErrSotSyncHS,aD1ForceRxmode,D1RxClkEsc,aD1RxDataEsc[7:0],aD1RxValidEsc,aD1RxLpdtEsc,aD1RxUlpsEsc,aD1RxTriggerEsc[3:0],aD1ErrEsc,aD1ErrControl,s_axi_lite_awaddr[3:0],s_axi_lite_awprot[2:0],s_axi_lite_awvalid,s_axi_lite_awready,s_axi_lite_wdata[31:0],s_axi_lite_wstrb[3:0],s_axi_lite_wvalid,s_axi_lite_wready,s_axi_lite_bresp[1:0],s_axi_lite_bvalid,s_axi_lite_bready,s_axi_lite_araddr[3:0],s_axi_lite_arprot[2:0],s_axi_lite_arvalid,s_axi_lite_arready,s_axi_lite_rdata[31:0],s_axi_lite_rresp[1:0],s_axi_lite_rvalid,s_axi_lite_rready,s_axi_lite_aresetn" */
/* synthesis syn_force_seq_prim="RefClk" */
/* synthesis syn_force_seq_prim="RxDDRClkHS" */
/* synthesis syn_force_seq_prim="RxByteClkHS" */
/* synthesis syn_force_seq_prim="s_axi_lite_aclk" */;
  (* x_interface_info = "xilinx.com:interface:diff_clock:1.0 dphy_hs_clock CLK_P" *) (* x_interface_mode = "slave dphy_hs_clock" *) (* x_interface_parameter = "XIL_INTERFACENAME dphy_hs_clock, CAN_DEBUG false, FREQ_HZ 336000000" *) input dphy_clk_hs_p;
  (* x_interface_info = "xilinx.com:interface:diff_clock:1.0 dphy_hs_clock CLK_N" *) input dphy_clk_hs_n;
  input dphy_clk_lp_p;
  input dphy_clk_lp_n;
  input [1:0]dphy_data_hs_p;
  input [1:0]dphy_data_hs_n;
  input [1:0]dphy_data_lp_p;
  input [1:0]dphy_data_lp_n;
  (* x_interface_info = "xilinx.com:signal:clock:1.0 RefClk CLK" *) (* x_interface_mode = "slave RefClk" *) (* x_interface_parameter = "XIL_INTERFACENAME RefClk, ASSOCIATED_RESET aRst, FREQ_HZ 200000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0" *) input RefClk /* synthesis syn_isclock = 1 */;
  (* x_interface_info = "xilinx.com:signal:reset:1.0 aRst RST" *) (* x_interface_mode = "slave aRst" *) (* x_interface_parameter = "XIL_INTERFACENAME aRst, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *) input aRst;
  output rDlyCtrlLockedOut;
  output RxDDRClkHS /* synthesis syn_isclock = 1 */;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_RXCLKACTIVEHS" *) (* x_interface_mode = "master D_PHY_PPI" *) output aRxClkActiveHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_STOPSTATE" *) output aClkStopstate;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_ENABLE" *) input aClkEnable;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_ULPSACTIVENOT" *) output aClkUlpsActiveNot;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_RXULPSCLKNOT" *) output aRxUlpsClkNot;
  input aClkForceRxmode;
  output aClkErrControl;
  (* x_interface_info = "xilinx.com:signal:clock:1.0 RxByteClkHS CLK" *) (* x_interface_mode = "master RxByteClkHS" *) (* x_interface_parameter = "XIL_INTERFACENAME RxByteClkHS, FREQ_HZ 84000000, ASSOCIATED_BUSIF D_PHY_PPI, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN system_MIPI_D_PHY_RX_0_0_RxByteClkHS, INSERT_VIP 0" *) output RxByteClkHS /* synthesis syn_isclock = 1 */;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_STOPSTATE" *) output aD0Stopstate;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ENABLE" *) input aD0Enable;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ULPSACTIVENOT" *) output aD0UlpsActiveNot;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXDATAHS" *) output [7:0]rbD0RxDataHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXVALIDHS" *) output rbD0RxValidHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXACTIVEHS" *) output rbD0RxActiveHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXSYNCHS" *) output rbD0RxSyncHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRSOTHS" *) output rbD0ErrSotHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRSOTSYNCHS" *) output rbD0ErrSotSyncHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_FORCERXMODE" *) input aD0ForceRxmode;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXCLKESC" *) output D0RxClkEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXDATAESC" *) output [7:0]aD0RxDataEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXVALIDESC" *) output aD0RxValidEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXLPDTESC" *) output aD0RxLpdtEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXULPSESC" *) output aD0RxUlpsEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXTRIGGERESC" *) output [3:0]aD0RxTriggerEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRESC" *) output aD0ErrEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRCONTROL" *) output aD0ErrControl;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_STOPSTATE" *) output aD1Stopstate;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ENABLE" *) input aD1Enable;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ULPSACTIVENOT" *) output aD1UlpsActiveNot;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXDATAHS" *) output [7:0]rbD1RxDataHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXVALIDHS" *) output rbD1RxValidHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXACTIVEHS" *) output rbD1RxActiveHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXSYNCHS" *) output rbD1RxSyncHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRSOTHS" *) output rbD1ErrSotHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRSOTSYNCHS" *) output rbD1ErrSotSyncHS;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_FORCERXMODE" *) input aD1ForceRxmode;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXCLKESC" *) output D1RxClkEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXDATAESC" *) output [7:0]aD1RxDataEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXVALIDESC" *) output aD1RxValidEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXLPDTESC" *) output aD1RxLpdtEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXULPSESC" *) output aD1RxUlpsEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXTRIGGERESC" *) output [3:0]aD1RxTriggerEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRESC" *) output aD1ErrEsc;
  (* x_interface_info = "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRCONTROL" *) output aD1ErrControl;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWADDR" *) (* x_interface_mode = "slave S_AXI_LITE" *) (* x_interface_parameter = "XIL_INTERFACENAME S_AXI_LITE, WIZ_DATA_WIDTH 32, WIZ_NUM_REG 4, SUPPORTS_NARROW_BURST 0, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 50000000, ID_WIDTH 0, ADDR_WIDTH 4, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input [3:0]s_axi_lite_awaddr;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWPROT" *) input [2:0]s_axi_lite_awprot;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWVALID" *) input s_axi_lite_awvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWREADY" *) output s_axi_lite_awready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE WDATA" *) input [31:0]s_axi_lite_wdata;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE WSTRB" *) input [3:0]s_axi_lite_wstrb;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE WVALID" *) input s_axi_lite_wvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE WREADY" *) output s_axi_lite_wready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE BRESP" *) output [1:0]s_axi_lite_bresp;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE BVALID" *) output s_axi_lite_bvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE BREADY" *) input s_axi_lite_bready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARADDR" *) input [3:0]s_axi_lite_araddr;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARPROT" *) input [2:0]s_axi_lite_arprot;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARVALID" *) input s_axi_lite_arvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARREADY" *) output s_axi_lite_arready;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE RDATA" *) output [31:0]s_axi_lite_rdata;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE RRESP" *) output [1:0]s_axi_lite_rresp;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE RVALID" *) output s_axi_lite_rvalid;
  (* x_interface_info = "xilinx.com:interface:aximm:1.0 S_AXI_LITE RREADY" *) input s_axi_lite_rready;
  (* x_interface_info = "xilinx.com:signal:clock:1.0 s_axi_lite_aclk CLK" *) (* x_interface_mode = "slave s_axi_lite_aclk" *) (* x_interface_parameter = "XIL_INTERFACENAME s_axi_lite_aclk, ASSOCIATED_RESET s_axi_lite_aresetn, ASSOCIATED_BUSIF S_AXI_LITE, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0" *) input s_axi_lite_aclk /* synthesis syn_isclock = 1 */;
  (* x_interface_info = "xilinx.com:signal:reset:1.0 s_axi_lite_aresetn RST" *) (* x_interface_mode = "slave s_axi_lite_aresetn" *) (* x_interface_parameter = "XIL_INTERFACENAME s_axi_lite_aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) input s_axi_lite_aresetn;
endmodule
