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


module inter_machine(
    input  logic        clk,
    input  logic        reset_n,
    input  logic [23:0] fifo_data_out_1,
    input  logic [23:0] fifo_data_out_2,
    input  logic        start_proces,
    input  logic        fifo_last_out,
    input  logic        m_axis_tready,
    output logic        first_data,

    output logic         load_value,
    output logic        m_axis_tvalid,
    output logic        m_axis_tlast,
    output logic        reset_init,
    output logic        switch_select,

    output logic [7:0]  buffer_1 [7:0],
    output logic [7:0]  buffer_2 [7:0],
    output logic [7:0]  buffer_3 [7:0]
);




logic [2:0] remaining_ptr_a_buf_1;
logic [2:0] extra_ptr_b_buf_1;
logic [2:0] remaining_ptr_a_buf_2;
logic [2:0] extra_ptr_b_buf_2;
logic [5:0] write_ptr_a;
logic [5:0] write_ptr;
logic buffer_switch;
logic fifo_rd_reg_1;
logic m_axis_tlast_reg;
logic extr_data;
logic [47:0] fifo_data_combine;
logic first_a;
logic [7:0] buffer_1_wire [7:0];
logic [7:0] buffer_2_wire [7:0];
logic [7:0] buffer_3_wire [7:0];
logic tem;

typedef enum logic [3:0] {
    IDEAL    = 4'd0,
    STATE_0  = 4'd1,
    STATE_1  = 4'd2,
    STATE_2  = 4'd3,
    STATE_3  = 4'd4,
    STATE_4  = 4'd5,
    STATE_BUFFER_0 = 4'd6,
    STATE_BUFFER_1 = 4'd7,
    STATE_BUFFER_2 = 4'd8,
    STATE_BUFFER_3 = 4'd9
} state_t;

state_t state;
state_t next_state;


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
            state <= STATE_0;
            first_a <= 0;
            m_axis_tlast <= 0;
            m_axis_tvalid <= 0;
            write_ptr <= 0;
            switch_select <= 1'b0;
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
			first_data <= 1;
			load_value    <= 1;
        end else begin
            case (state)

                STATE_0: begin
							first_data <= 1;
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_0;
                            m_axis_tlast <= 1;
                            switch_select <= 1'b0;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                            m_axis_tvalid <= 0;
                        end else begin
                            m_axis_tvalid <= 0;
                            switch_select <= 1'b0;
                            state <= STATE_1;
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
							load_value <= 1;
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_BUFFER_0;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b0;
							first_data <= 0;
                            buffer_1[6] <= fifo_data_combine[7:0];
                            buffer_1[7] <= fifo_data_combine[15:8];
                            buffer_2[0] <= fifo_data_combine[23:16];
                            buffer_2[1] <= fifo_data_combine[31:24];
                            buffer_2[2] <= fifo_data_combine[39:32];
                            buffer_2[3] <= fifo_data_combine[47:40];
                            m_axis_tvalid <= 1;
                        end else begin
                            state <= STATE_2;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b0;
							first_data <= 0;
                            buffer_1[6] <= fifo_data_combine[7:0];
                            buffer_1[7] <= fifo_data_combine[15:8];
                            buffer_2[0] <= fifo_data_combine[23:16];
                            buffer_2[1] <= fifo_data_combine[31:24];
                            buffer_2[2] <= fifo_data_combine[39:32];
                            buffer_2[3] <= fifo_data_combine[47:40];
                            m_axis_tvalid <= 1;
                        end
                    end
                end
                STATE_2: begin
                        
							//first_data <= 0;
							//first_data <= 1;
                            m_axis_tvalid <= 1;
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_BUFFER_1;
                            m_axis_tlast <= 1;
                            switch_select <= 1'b1;
                            m_axis_tvalid <= 1;
							first_data <= 0;
                            buffer_2[4] <= fifo_data_combine[7:0];
                            buffer_2[5] <= fifo_data_combine[15:8];
                            buffer_2[6] <= fifo_data_combine[23:16];
                            buffer_2[7] <= fifo_data_combine[31:24];
                            buffer_1[0] <= fifo_data_combine[39:32];
                            buffer_1[1] <= fifo_data_combine[47:40];
                        end else begin
                            state <= STATE_3;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b1;
                            m_axis_tvalid <= 1;
                            buffer_2[4] <= fifo_data_combine[7:0];
                            buffer_2[5] <= fifo_data_combine[15:8];
                            buffer_2[6] <= fifo_data_combine[23:16];
                            buffer_2[7] <= fifo_data_combine[31:24];
                            buffer_1[0] <= fifo_data_combine[39:32];
                            buffer_1[1] <= fifo_data_combine[47:40];
                        end
                    end
                end

                STATE_3: begin

							//first_data <= 1;
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_BUFFER_2;
                            m_axis_tlast <= 1;
                            switch_select <= 1'b0;
                            m_axis_tvalid <= 1;
							first_data <= 0;
                            buffer_1[2] <= fifo_data_combine[7:0];
                            buffer_1[3] <= fifo_data_combine[15:8];
                            buffer_1[4] <= fifo_data_combine[23:16];
                            buffer_1[5] <= fifo_data_combine[31:24];
                            buffer_1[6] <= fifo_data_combine[39:32];
                            buffer_1[7] <= fifo_data_combine[47:40];
                        end else begin
                            state <= STATE_4;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b0;
                            m_axis_tvalid <= 1;
							first_data <= 0;
                            buffer_1[2] <= fifo_data_combine[7:0];
                            buffer_1[3] <= fifo_data_combine[15:8];
                            buffer_1[4] <= fifo_data_combine[23:16];
                            buffer_1[5] <= fifo_data_combine[31:24];
                            buffer_1[6] <= fifo_data_combine[39:32];
                            buffer_1[7] <= fifo_data_combine[47:40];
                        end
					end
                end

//new

                STATE_4: begin
							first_data <= 0;
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_BUFFER_0;
                            m_axis_tlast <= 1;
                            switch_select <= 1'b0;
							first_data <= 0;
                            m_axis_tvalid <= 0;
							load_value    <= 0;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end else begin
                            state <= STATE_1;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b0;
							first_data <= 0;
                            m_axis_tvalid <= 0;
							load_value    <= 0;
							tem <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end 
					end
                end

                STATE_BUFFER_0: begin
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_1;
                            m_axis_tlast <= 1;
                            switch_select <= 1'b1;
                            m_axis_tvalid <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end else begin
                            state <= STATE_1;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b1;
                            m_axis_tvalid <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end
                    end
                end

                STATE_BUFFER_1: begin
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_BUFFER_0;
                            m_axis_tlast <= 1;
                            switch_select <= 1'b0;
                            m_axis_tvalid <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end else begin
                            state <= STATE_2;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b0;
                            m_axis_tvalid <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end
                    end
                end
                STATE_BUFFER_2: begin
                    if (start_proces) begin
                        if (fifo_last_out) begin    
                            state <= STATE_1;
                            m_axis_tlast <= 1;
                            switch_select <= 1'b0;
                            m_axis_tvalid <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end else begin
                            state <= STATE_1;
                            m_axis_tlast <= 0;
                            switch_select <= 1'b0;
                            m_axis_tvalid <= 1;
                            buffer_1[0] <= fifo_data_combine[7:0];
                            buffer_1[1] <= fifo_data_combine[15:8];
                            buffer_1[2] <= fifo_data_combine[23:16];
                            buffer_1[3] <= fifo_data_combine[31:24];
                            buffer_1[4] <= fifo_data_combine[39:32];
                            buffer_1[5] <= fifo_data_combine[47:40];
                        end
                    end
                end

                default: begin
                    state <= STATE_0;
                end

            endcase
        end
    end

endmodule
