`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.06.2025 15:31:38
// Design Name: 
// Module Name: inter_mechine
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import all_pkg::*;

module inter_machine(
    input  logic        clk,
    input  logic        reset_n,
    input  logic [23:0] fifo_data_out_1,
    input  logic [23:0] fifo_data_out_2,
    input  logic        fifo_tlast,
    input  logic        inter_m_axis_tready,
	input  logic  		fifo_valid,
	input  logic		inter_m_axis_tvalid,
	output logic 		fifo_read,
	output logic 		inter_buffer_has_data,
    output logic        inter_m_axis_tlast,    
	output logic [7:0]  inter_m_axis_tdata [7:0]
);

logic [7:0] buffer_1 [7:0];
logic [7:0] buffer_2 [7:0];
logic [7:0] buffer_3 [7:0];
logic [3:1] m_axis_tlast_sig;
logic [47:0] fifo_data_combine;
logic first_a;
mux_st switch_select;
mux_st STATE_MUX;
S_mux_sel_t data_wrt_reg_sel;

logic buffer_1_has_data;
logic buffer_2_has_data;
logic buffer_3_has_data;


// Condition to check buffer has data
assign inter_buffer_has_data = buffer_1_has_data || buffer_2_has_data || buffer_3_has_data;
// FIFO read logic
assign fifo_read = fifo_valid && (!buffer_1_has_data);

//Data selection logic
always_comb begin
    if (switch_select==MUX_BUFFER_1) begin
        inter_m_axis_tdata  = buffer_1;
		inter_m_axis_tlast  = m_axis_tlast_sig[1];
    end else if (switch_select==MUX_BUFFER_2) begin
        inter_m_axis_tdata  = buffer_2;
		inter_m_axis_tlast  = m_axis_tlast_sig[2];
    end else if (switch_select==MUX_BUFFER_3) begin
        inter_m_axis_tdata  = buffer_3;
		inter_m_axis_tlast   	   = m_axis_tlast_sig[3];
    end else if (switch_select==IDLE) begin
        inter_m_axis_tdata  = '{default:8'h00};
		inter_m_axis_tlast   	   = 0;
    end else begin
		inter_m_axis_tlast   	   = 0;
		inter_m_axis_tdata = '{default:8'h00};
    end
end

// This can be future use, now always first channel 0
always_comb begin
    if (first_a) begin
        fifo_data_combine = {fifo_data_out_1[23:16],
                             fifo_data_out_2[23:16],
                             fifo_data_out_1[15:8],
                             fifo_data_out_2[15:8],
                             fifo_data_out_1[7:0],
                             fifo_data_out_2[7:0]};
    end else begin
        fifo_data_combine = {fifo_data_out_2[23:16],
                             fifo_data_out_1[23:16],
                             fifo_data_out_2[15:8],
                             fifo_data_out_1[15:8],
                             fifo_data_out_2[7:0],
                             fifo_data_out_1[7:0]};
    end
end



    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            data_wrt_reg_sel <= STATE_0;
            first_a <= 0;
            m_axis_tlast_sig <= 0;
            buffer_2[0] <= 8'h00; 
            buffer_2[1] <= 8'h00;
            buffer_2[2] <= 8'h00;
            buffer_2[3] <= 8'h00;
            buffer_2[4] <= 8'h00;
            buffer_2[5] <= 8'h00;
            buffer_2[6] <= 8'h00;
            buffer_2[7] <= 8'h00;
            buffer_1[0] <= 8'h00;
            buffer_1[1] <= 8'h00;
            buffer_1[2] <= 8'h00;
            buffer_1[3] <= 8'h00;
            buffer_1[4] <= 8'h00;
            buffer_1[5] <= 8'h00;
            buffer_1[6] <= 8'h00;
            buffer_1[7] <= 8'h00;
            buffer_3[0] <= 0;
            buffer_3[1] <= 0;
            buffer_3[2] <= 0;
            buffer_3[3] <= 0;
            buffer_3[4] <= 0;
            buffer_3[5] <= 0;
            buffer_3[6] <= 0;
            buffer_3[7] <= 0;
			buffer_1_has_data <= 0;
			buffer_2_has_data <= 0;
			buffer_3_has_data <= 0;
			switch_select      <= MUX_BUFFER_1;
			STATE_MUX          <= MUX_BUFFER_1;
        end else begin
            case (data_wrt_reg_sel)
                STATE_0: begin
                    if (fifo_valid&&!buffer_1_has_data) begin
                        if (fifo_tlast) begin   
							buffer_1_has_data <= 1;
                            data_wrt_reg_sel <= STATE_0;
                            m_axis_tlast_sig[1] <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                            buffer_1[6] <= 0;
                            buffer_1[7] <= 0;
                        end else begin
                            data_wrt_reg_sel <= STATE_1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end
					end 
                end
                STATE_1: begin
                    if (fifo_valid&&!buffer_2_has_data) begin
                        if (fifo_tlast) begin   
							buffer_2_has_data <= 1;
							buffer_1_has_data <= 1;
                            data_wrt_reg_sel <= STATE_0;
                            m_axis_tlast_sig[2] <= 1;
                            buffer_1[6] <= fifo_data_combine[7:0];
                            buffer_1[7] <= fifo_data_combine[15:8];
                            buffer_2[0] <= fifo_data_combine[23:16];
                            buffer_2[1] <= fifo_data_combine[31:24];
                            buffer_2[2] <= fifo_data_combine[39:32];
                            buffer_2[3] <= fifo_data_combine[47:40];
                            buffer_2[4] <= 0;
                            buffer_2[5] <= 0;
                            buffer_2[6] <= 0;
                            buffer_2[7] <= 0;
                        end else begin 
							buffer_1_has_data <= 1;
                            data_wrt_reg_sel <= STATE_2;
                            buffer_1[6] <= fifo_data_combine[7:0];
                            buffer_1[7] <= fifo_data_combine[15:8];
                            buffer_2[0] <= fifo_data_combine[23:16];
                            buffer_2[1] <= fifo_data_combine[31:24];
                            buffer_2[2] <= fifo_data_combine[39:32];
                            buffer_2[3] <= fifo_data_combine[47:40];
                        end
                    end
                end
                STATE_2: begin
                    if (fifo_valid&&!buffer_3_has_data) begin
                        if (fifo_tlast) begin    
							buffer_3_has_data <= 1;
							buffer_2_has_data <= 1;
                            data_wrt_reg_sel <= STATE_0;
                            m_axis_tlast_sig[3] <= 1;
                            buffer_2[4] <= fifo_data_combine[7:0];
                            buffer_2[5] <= fifo_data_combine[15:8];
                            buffer_2[6] <= fifo_data_combine[23:16];
                            buffer_2[7] <= fifo_data_combine[31:24];
                            buffer_3[0] <= fifo_data_combine[39:32];
                            buffer_3[1] <= fifo_data_combine[47:40];
                            buffer_3[2] <= 0;
                            buffer_3[3] <= 0;
                            buffer_3[4] <= 0;
                            buffer_3[5] <= 0;
                            buffer_3[6] <= 0;
                            buffer_3[7] <= 0;
                        end else begin
                            data_wrt_reg_sel <= STATE_3;
							buffer_2_has_data <= 1;
                            buffer_2[4] <= fifo_data_combine[7:0];
                            buffer_2[5] <= fifo_data_combine[15:8];
                            buffer_2[6] <= fifo_data_combine[23:16];
                            buffer_2[7] <= fifo_data_combine[31:24];
                            buffer_3[0] <= fifo_data_combine[39:32];
                            buffer_3[1] <= fifo_data_combine[47:40];
                        end
                    end
                end

                STATE_3: begin
                    if (fifo_valid) begin
                        if (fifo_tlast) begin    
							buffer_3_has_data <= 1;
                            data_wrt_reg_sel <= STATE_0;
                            m_axis_tlast_sig[3] <= 1;
                            buffer_3[2] <= fifo_data_combine[7:0];
                            buffer_3[3] <= fifo_data_combine[15:8];
                            buffer_3[4] <= fifo_data_combine[23:16];
                            buffer_3[5] <= fifo_data_combine[31:24];
                            buffer_3[6] <= fifo_data_combine[39:32];
                            buffer_3[7] <= fifo_data_combine[47:40];
                        end else begin
							buffer_3_has_data  <= 1;
                            data_wrt_reg_sel <= STATE_0;
                            buffer_3[2] <= fifo_data_combine[7:0];
                            buffer_3[3] <= fifo_data_combine[15:8];
                            buffer_3[4] <= fifo_data_combine[23:16];
                            buffer_3[5] <= fifo_data_combine[31:24];
                            buffer_3[6] <= fifo_data_combine[39:32];
                            buffer_3[7] <= fifo_data_combine[47:40];
                        end
					end
                end
                default: begin
                    data_wrt_reg_sel <= STATE_0;
                end
            endcase

// mux selection logic.
			if (inter_buffer_has_data) begin
				case (STATE_MUX)
			
					MUX_BUFFER_1: begin
						if ((inter_m_axis_tvalid && inter_m_axis_tready) || !inter_m_axis_tvalid) begin
							if (m_axis_tlast_sig[1]) begin
								buffer_1_has_data    <= 0;
								m_axis_tlast_sig[1]  <= 0;
								switch_select        <= MUX_BUFFER_1;
								STATE_MUX            <= MUX_BUFFER_1;
							end else begin
								buffer_1_has_data    <= 0;
								switch_select        <= MUX_BUFFER_2;
								STATE_MUX            <= MUX_BUFFER_2;
							end
						end
					end
			
					MUX_BUFFER_2: begin
						if ((inter_m_axis_tvalid && inter_m_axis_tready) || !inter_m_axis_tvalid) begin
							if (m_axis_tlast_sig[2]) begin
								buffer_2_has_data    <= 0;
								m_axis_tlast_sig[2]  <= 0;
								switch_select        <= MUX_BUFFER_1;
								STATE_MUX            <= MUX_BUFFER_1;
							end else begin
								buffer_2_has_data    <= 0;
								switch_select        <= MUX_BUFFER_3;
								STATE_MUX            <= MUX_BUFFER_3;
							end
						end
					end
			
					MUX_BUFFER_3: begin
						if ((inter_m_axis_tvalid && inter_m_axis_tready) || !inter_m_axis_tvalid) begin
							buffer_3_has_data    <= 0;
							m_axis_tlast_sig[3]  <= 0;
							switch_select        <= MUX_BUFFER_1;
							STATE_MUX            <= MUX_BUFFER_1;
						end
					end
			
					default: begin
						switch_select        <= MUX_BUFFER_1;
						STATE_MUX            <= MUX_BUFFER_1;
					end
			
				endcase
			end
        end
    end



/// Debug ONLY
logic count = 0;
always @(posedge clk or negedge reset_n) begin

		if (!reset_n) begin
			count <= 0;
		end
		if (inter_m_axis_tvalid && inter_m_axis_tready) begin
				count <= count +1;
		$display("@%0t  -----------------------------master_packet : %h", $time, count);		
		$display("@%0t 											[DUT]->  buffer_1: %02x_%02x_%02x_%02x_%02x_%02x_%02x_%02x",
				$time,
				buffer_1[7], buffer_1[6], buffer_1[5], buffer_1[4],
				buffer_1[3], buffer_1[2], buffer_1[1], buffer_1[0]);
		$display("@%0t 											[DUT]->  buffer_2: %02x_%02x_%02x_%02x_%02x_%02x_%02x_%02x",
				$time,
				buffer_2[7], buffer_2[6], buffer_2[5], buffer_2[4],
				buffer_2[3], buffer_2[2], buffer_2[1], buffer_2[0]);
		$display("@%0t 											[DUT]->  buffer_3: %02x_%02x_%02x_%02x_%02x_%02x_%02x_%02x",
				$time,
				buffer_3[7], buffer_3[6], buffer_3[5], buffer_3[4],
				buffer_3[3], buffer_3[2], buffer_3[1], buffer_3[0]);
		$display("@%0t 											[DUT] switch_select : %s", $time, mux_state_to_string(switch_select));
		$display("@%0t 											[DUT] switch_select : %s", $time, mux_state_to_string(STATE_MUX));
		$display("@%0t                                          buffer_a : %h , buffer_b : %h buffer_c : %h ", $time, buffer_1_has_data,buffer_2_has_data,buffer_3_has_data);
		$display("@%0t -------------------------------", $time);
		end
end
endmodule
