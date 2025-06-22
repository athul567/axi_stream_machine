// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Sun Jun 22 08:21:25 2025
// Host        : athulbhx running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/expriment/new/axi_stream_machine/axi4stream_vip_mst_0/axi4stream_vip_mst_0_stub.v
// Design      : axi4stream_vip_mst_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "axi4stream_vip_v1_1_17_top,Vivado 2024.1" *)
module axi4stream_vip_mst_0(aclk, aresetn, m_axis_tvalid, m_axis_tready, 
  m_axis_tdata, m_axis_tlast)
/* synthesis syn_black_box black_box_pad_pin="aclk,aresetn,m_axis_tvalid[0:0],m_axis_tready[0:0],m_axis_tdata[47:0],m_axis_tlast[0:0]" */;
  input aclk;
  input aresetn;
  output [0:0]m_axis_tvalid;
  input [0:0]m_axis_tready;
  output [47:0]m_axis_tdata;
  output [0:0]m_axis_tlast;
endmodule
