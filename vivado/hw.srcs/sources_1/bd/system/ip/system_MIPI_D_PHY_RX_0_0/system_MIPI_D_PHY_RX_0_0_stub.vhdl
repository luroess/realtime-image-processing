-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
-- Date        : Thu Jul 24 17:45:28 2025
-- Host        : IonutAvion-ro running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               e:/VivadoMigrations2025.1/ZyboZ7-Pcam-10/Zybo-Z7/hw/proj/hw.gen/sources_1/bd/system/ip/system_MIPI_D_PHY_RX_0_0/system_MIPI_D_PHY_RX_0_0_stub.vhdl
-- Design      : system_MIPI_D_PHY_RX_0_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z010clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity system_MIPI_D_PHY_RX_0_0 is
  Port ( 
    dphy_clk_hs_p : in STD_LOGIC;
    dphy_clk_hs_n : in STD_LOGIC;
    dphy_clk_lp_p : in STD_LOGIC;
    dphy_clk_lp_n : in STD_LOGIC;
    dphy_data_hs_p : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dphy_data_hs_n : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dphy_data_lp_p : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dphy_data_lp_n : in STD_LOGIC_VECTOR ( 1 downto 0 );
    RefClk : in STD_LOGIC;
    aRst : in STD_LOGIC;
    rDlyCtrlLockedOut : out STD_LOGIC;
    RxDDRClkHS : out STD_LOGIC;
    aRxClkActiveHS : out STD_LOGIC;
    aClkStopstate : out STD_LOGIC;
    aClkEnable : in STD_LOGIC;
    aClkUlpsActiveNot : out STD_LOGIC;
    aRxUlpsClkNot : out STD_LOGIC;
    aClkForceRxmode : in STD_LOGIC;
    aClkErrControl : out STD_LOGIC;
    RxByteClkHS : out STD_LOGIC;
    aD0Stopstate : out STD_LOGIC;
    aD0Enable : in STD_LOGIC;
    aD0UlpsActiveNot : out STD_LOGIC;
    rbD0RxDataHS : out STD_LOGIC_VECTOR ( 7 downto 0 );
    rbD0RxValidHS : out STD_LOGIC;
    rbD0RxActiveHS : out STD_LOGIC;
    rbD0RxSyncHS : out STD_LOGIC;
    rbD0ErrSotHS : out STD_LOGIC;
    rbD0ErrSotSyncHS : out STD_LOGIC;
    aD0ForceRxmode : in STD_LOGIC;
    D0RxClkEsc : out STD_LOGIC;
    aD0RxDataEsc : out STD_LOGIC_VECTOR ( 7 downto 0 );
    aD0RxValidEsc : out STD_LOGIC;
    aD0RxLpdtEsc : out STD_LOGIC;
    aD0RxUlpsEsc : out STD_LOGIC;
    aD0RxTriggerEsc : out STD_LOGIC_VECTOR ( 3 downto 0 );
    aD0ErrEsc : out STD_LOGIC;
    aD0ErrControl : out STD_LOGIC;
    aD1Stopstate : out STD_LOGIC;
    aD1Enable : in STD_LOGIC;
    aD1UlpsActiveNot : out STD_LOGIC;
    rbD1RxDataHS : out STD_LOGIC_VECTOR ( 7 downto 0 );
    rbD1RxValidHS : out STD_LOGIC;
    rbD1RxActiveHS : out STD_LOGIC;
    rbD1RxSyncHS : out STD_LOGIC;
    rbD1ErrSotHS : out STD_LOGIC;
    rbD1ErrSotSyncHS : out STD_LOGIC;
    aD1ForceRxmode : in STD_LOGIC;
    D1RxClkEsc : out STD_LOGIC;
    aD1RxDataEsc : out STD_LOGIC_VECTOR ( 7 downto 0 );
    aD1RxValidEsc : out STD_LOGIC;
    aD1RxLpdtEsc : out STD_LOGIC;
    aD1RxUlpsEsc : out STD_LOGIC;
    aD1RxTriggerEsc : out STD_LOGIC_VECTOR ( 3 downto 0 );
    aD1ErrEsc : out STD_LOGIC;
    aD1ErrControl : out STD_LOGIC;
    s_axi_lite_awaddr : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axi_lite_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axi_lite_awvalid : in STD_LOGIC;
    s_axi_lite_awready : out STD_LOGIC;
    s_axi_lite_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_lite_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axi_lite_wvalid : in STD_LOGIC;
    s_axi_lite_wready : out STD_LOGIC;
    s_axi_lite_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_lite_bvalid : out STD_LOGIC;
    s_axi_lite_bready : in STD_LOGIC;
    s_axi_lite_araddr : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axi_lite_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axi_lite_arvalid : in STD_LOGIC;
    s_axi_lite_arready : out STD_LOGIC;
    s_axi_lite_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_lite_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_lite_rvalid : out STD_LOGIC;
    s_axi_lite_rready : in STD_LOGIC;
    s_axi_lite_aclk : in STD_LOGIC;
    s_axi_lite_aresetn : in STD_LOGIC
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of system_MIPI_D_PHY_RX_0_0 : entity is "system_MIPI_D_PHY_RX_0_0,MIPI_DPHY_Receiver,{}";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of system_MIPI_D_PHY_RX_0_0 : entity is "yes";
end system_MIPI_D_PHY_RX_0_0;

architecture stub of system_MIPI_D_PHY_RX_0_0 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "dphy_clk_hs_p,dphy_clk_hs_n,dphy_clk_lp_p,dphy_clk_lp_n,dphy_data_hs_p[1:0],dphy_data_hs_n[1:0],dphy_data_lp_p[1:0],dphy_data_lp_n[1:0],RefClk,aRst,rDlyCtrlLockedOut,RxDDRClkHS,aRxClkActiveHS,aClkStopstate,aClkEnable,aClkUlpsActiveNot,aRxUlpsClkNot,aClkForceRxmode,aClkErrControl,RxByteClkHS,aD0Stopstate,aD0Enable,aD0UlpsActiveNot,rbD0RxDataHS[7:0],rbD0RxValidHS,rbD0RxActiveHS,rbD0RxSyncHS,rbD0ErrSotHS,rbD0ErrSotSyncHS,aD0ForceRxmode,D0RxClkEsc,aD0RxDataEsc[7:0],aD0RxValidEsc,aD0RxLpdtEsc,aD0RxUlpsEsc,aD0RxTriggerEsc[3:0],aD0ErrEsc,aD0ErrControl,aD1Stopstate,aD1Enable,aD1UlpsActiveNot,rbD1RxDataHS[7:0],rbD1RxValidHS,rbD1RxActiveHS,rbD1RxSyncHS,rbD1ErrSotHS,rbD1ErrSotSyncHS,aD1ForceRxmode,D1RxClkEsc,aD1RxDataEsc[7:0],aD1RxValidEsc,aD1RxLpdtEsc,aD1RxUlpsEsc,aD1RxTriggerEsc[3:0],aD1ErrEsc,aD1ErrControl,s_axi_lite_awaddr[3:0],s_axi_lite_awprot[2:0],s_axi_lite_awvalid,s_axi_lite_awready,s_axi_lite_wdata[31:0],s_axi_lite_wstrb[3:0],s_axi_lite_wvalid,s_axi_lite_wready,s_axi_lite_bresp[1:0],s_axi_lite_bvalid,s_axi_lite_bready,s_axi_lite_araddr[3:0],s_axi_lite_arprot[2:0],s_axi_lite_arvalid,s_axi_lite_arready,s_axi_lite_rdata[31:0],s_axi_lite_rresp[1:0],s_axi_lite_rvalid,s_axi_lite_rready,s_axi_lite_aclk,s_axi_lite_aresetn";
  attribute x_interface_info : string;
  attribute x_interface_info of dphy_clk_hs_p : signal is "xilinx.com:interface:diff_clock:1.0 dphy_hs_clock CLK_P";
  attribute x_interface_mode : string;
  attribute x_interface_mode of dphy_clk_hs_p : signal is "slave dphy_hs_clock";
  attribute x_interface_parameter : string;
  attribute x_interface_parameter of dphy_clk_hs_p : signal is "XIL_INTERFACENAME dphy_hs_clock, CAN_DEBUG false, FREQ_HZ 336000000";
  attribute x_interface_info of dphy_clk_hs_n : signal is "xilinx.com:interface:diff_clock:1.0 dphy_hs_clock CLK_N";
  attribute x_interface_info of RefClk : signal is "xilinx.com:signal:clock:1.0 RefClk CLK";
  attribute x_interface_mode of RefClk : signal is "slave RefClk";
  attribute x_interface_parameter of RefClk : signal is "XIL_INTERFACENAME RefClk, ASSOCIATED_RESET aRst, FREQ_HZ 200000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0";
  attribute x_interface_info of aRst : signal is "xilinx.com:signal:reset:1.0 aRst RST";
  attribute x_interface_mode of aRst : signal is "slave aRst";
  attribute x_interface_parameter of aRst : signal is "XIL_INTERFACENAME aRst, POLARITY ACTIVE_HIGH, INSERT_VIP 0";
  attribute x_interface_info of aRxClkActiveHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_RXCLKACTIVEHS";
  attribute x_interface_mode of aRxClkActiveHS : signal is "master D_PHY_PPI";
  attribute x_interface_info of aClkStopstate : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_STOPSTATE";
  attribute x_interface_info of aClkEnable : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_ENABLE";
  attribute x_interface_info of aClkUlpsActiveNot : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_ULPSACTIVENOT";
  attribute x_interface_info of aRxUlpsClkNot : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI CL_RXULPSCLKNOT";
  attribute x_interface_info of RxByteClkHS : signal is "xilinx.com:signal:clock:1.0 RxByteClkHS CLK";
  attribute x_interface_mode of RxByteClkHS : signal is "master RxByteClkHS";
  attribute x_interface_parameter of RxByteClkHS : signal is "XIL_INTERFACENAME RxByteClkHS, FREQ_HZ 84000000, ASSOCIATED_BUSIF D_PHY_PPI, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN system_MIPI_D_PHY_RX_0_0_RxByteClkHS, INSERT_VIP 0";
  attribute x_interface_info of aD0Stopstate : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_STOPSTATE";
  attribute x_interface_info of aD0Enable : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ENABLE";
  attribute x_interface_info of aD0UlpsActiveNot : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ULPSACTIVENOT";
  attribute x_interface_info of rbD0RxDataHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXDATAHS";
  attribute x_interface_info of rbD0RxValidHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXVALIDHS";
  attribute x_interface_info of rbD0RxActiveHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXACTIVEHS";
  attribute x_interface_info of rbD0RxSyncHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXSYNCHS";
  attribute x_interface_info of rbD0ErrSotHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRSOTHS";
  attribute x_interface_info of rbD0ErrSotSyncHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRSOTSYNCHS";
  attribute x_interface_info of aD0ForceRxmode : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_FORCERXMODE";
  attribute x_interface_info of D0RxClkEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXCLKESC";
  attribute x_interface_info of aD0RxDataEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXDATAESC";
  attribute x_interface_info of aD0RxValidEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXVALIDESC";
  attribute x_interface_info of aD0RxLpdtEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXLPDTESC";
  attribute x_interface_info of aD0RxUlpsEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXULPSESC";
  attribute x_interface_info of aD0RxTriggerEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_RXTRIGGERESC";
  attribute x_interface_info of aD0ErrEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRESC";
  attribute x_interface_info of aD0ErrControl : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL0_ERRCONTROL";
  attribute x_interface_info of aD1Stopstate : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_STOPSTATE";
  attribute x_interface_info of aD1Enable : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ENABLE";
  attribute x_interface_info of aD1UlpsActiveNot : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ULPSACTIVENOT";
  attribute x_interface_info of rbD1RxDataHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXDATAHS";
  attribute x_interface_info of rbD1RxValidHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXVALIDHS";
  attribute x_interface_info of rbD1RxActiveHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXACTIVEHS";
  attribute x_interface_info of rbD1RxSyncHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXSYNCHS";
  attribute x_interface_info of rbD1ErrSotHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRSOTHS";
  attribute x_interface_info of rbD1ErrSotSyncHS : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRSOTSYNCHS";
  attribute x_interface_info of aD1ForceRxmode : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_FORCERXMODE";
  attribute x_interface_info of D1RxClkEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXCLKESC";
  attribute x_interface_info of aD1RxDataEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXDATAESC";
  attribute x_interface_info of aD1RxValidEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXVALIDESC";
  attribute x_interface_info of aD1RxLpdtEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXLPDTESC";
  attribute x_interface_info of aD1RxUlpsEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXULPSESC";
  attribute x_interface_info of aD1RxTriggerEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_RXTRIGGERESC";
  attribute x_interface_info of aD1ErrEsc : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRESC";
  attribute x_interface_info of aD1ErrControl : signal is "xilinx.com:interface:rx_mipi_ppi_if:1.0 D_PHY_PPI DL1_ERRCONTROL";
  attribute x_interface_info of s_axi_lite_awaddr : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWADDR";
  attribute x_interface_mode of s_axi_lite_awaddr : signal is "slave S_AXI_LITE";
  attribute x_interface_parameter of s_axi_lite_awaddr : signal is "XIL_INTERFACENAME S_AXI_LITE, WIZ_DATA_WIDTH 32, WIZ_NUM_REG 4, SUPPORTS_NARROW_BURST 0, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 50000000, ID_WIDTH 0, ADDR_WIDTH 4, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute x_interface_info of s_axi_lite_awprot : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWPROT";
  attribute x_interface_info of s_axi_lite_awvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWVALID";
  attribute x_interface_info of s_axi_lite_awready : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE AWREADY";
  attribute x_interface_info of s_axi_lite_wdata : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE WDATA";
  attribute x_interface_info of s_axi_lite_wstrb : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE WSTRB";
  attribute x_interface_info of s_axi_lite_wvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE WVALID";
  attribute x_interface_info of s_axi_lite_wready : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE WREADY";
  attribute x_interface_info of s_axi_lite_bresp : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE BRESP";
  attribute x_interface_info of s_axi_lite_bvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE BVALID";
  attribute x_interface_info of s_axi_lite_bready : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE BREADY";
  attribute x_interface_info of s_axi_lite_araddr : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARADDR";
  attribute x_interface_info of s_axi_lite_arprot : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARPROT";
  attribute x_interface_info of s_axi_lite_arvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARVALID";
  attribute x_interface_info of s_axi_lite_arready : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE ARREADY";
  attribute x_interface_info of s_axi_lite_rdata : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE RDATA";
  attribute x_interface_info of s_axi_lite_rresp : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE RRESP";
  attribute x_interface_info of s_axi_lite_rvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE RVALID";
  attribute x_interface_info of s_axi_lite_rready : signal is "xilinx.com:interface:aximm:1.0 S_AXI_LITE RREADY";
  attribute x_interface_info of s_axi_lite_aclk : signal is "xilinx.com:signal:clock:1.0 s_axi_lite_aclk CLK";
  attribute x_interface_mode of s_axi_lite_aclk : signal is "slave s_axi_lite_aclk";
  attribute x_interface_parameter of s_axi_lite_aclk : signal is "XIL_INTERFACENAME s_axi_lite_aclk, ASSOCIATED_RESET s_axi_lite_aresetn, ASSOCIATED_BUSIF S_AXI_LITE, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0";
  attribute x_interface_info of s_axi_lite_aresetn : signal is "xilinx.com:signal:reset:1.0 s_axi_lite_aresetn RST";
  attribute x_interface_mode of s_axi_lite_aresetn : signal is "slave s_axi_lite_aresetn";
  attribute x_interface_parameter of s_axi_lite_aresetn : signal is "XIL_INTERFACENAME s_axi_lite_aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  attribute x_core_info : string;
  attribute x_core_info of stub : architecture is "MIPI_DPHY_Receiver,Vivado 2025.1";
begin
end;
