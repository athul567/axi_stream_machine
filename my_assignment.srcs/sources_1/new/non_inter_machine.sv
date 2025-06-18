//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2025 21:20:55
// Design Name: 
// Module Name: non_inter_mechine
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


module non_inter_machine (
    input  logic        clk,
    input  logic        reset_n,

    input  logic [23:0] fifo_data_out,
    input  logic        fifo_last_out,
	input  logic        m_axis_tready,
    input  logic        start_proces,

    output logic        fifo_rd,
    output logic        m_axis_tvalid,
	output logic        m_axis_tlast,
	output logic 		reset_init,
    output logic [2:0]  switch_select,

    output logic [7:0]  buffer_1 [10:0],
    output logic [7:0]  buffer_2 [10:0],
    output logic [7:0]  buffer_3 [10:0]
);




logic [2:0] remaining_ptr_a_buf_1;
logic [2:0] extra_ptr_b_buf_1;
logic [2:0] remaining_ptr_a_buf_2;
logic [2:0] extra_ptr_b_buf_2;
logic [5:0] write_ptr_a;
logic [5:0] write_ptr_b;
logic buffer_switch;
logic fifo_rd_reg_1;
logic m_axis_tvalid_reg;
logic start_proces_reg;
logic [1:0] switch_select_reg;
logic m_axis_tlast_reg;
logic extr_data;

assign    remaining_ptr_a_buf_1   = 8 - write_ptr_a ;
assign    extra_ptr_b_buf_2       = 3 - remaining_ptr_a_buf_1;
assign    remaining_ptr_a_buf_2   = 8 - write_ptr_b ;
assign    extra_ptr_b_buf_1       = 3 - remaining_ptr_a_buf_2;
assign    m_axis_tvalid = m_axis_tvalid_reg;
assign    switch_select = switch_select_reg;
assign    m_axis_tlast = m_axis_tlast_reg;

	always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            m_axis_tlast_reg  <= 0;
            fifo_rd  <= 1'b0;
            write_ptr_a <= 1'b0;
            write_ptr_b <= 1'b0;
			buffer_switch <= 0;
			fifo_rd_reg_1 <= 1'b0;
            m_axis_tvalid_reg <= 0;
			start_proces_reg <=  1'b0;
			reset_init    <= 0;
			m_axis_tlast <= 1'b0;
			switch_select_reg <= 2'b00;
						extr_data 		  <= 0;
            for (int i = 0; i < 11; i++) begin
                buffer_1[i] <= 8'd0;
                buffer_2[i] <= 8'd0;
            end


        end else begin
					fifo_rd_reg_1 <= fifo_rd;
			if (start_proces) begin
				start_proces_reg <= start_proces;
				fifo_rd  <= 1'b1;
            end 


            if (extr_data) begin
                switch_select_reg <= 2'b10;
				m_axis_tlast_reg  <= 1;
                m_axis_tvalid_reg <= 1;
            end else if (start_proces_reg) begin
				fifo_rd  <= 1'b1;
                m_axis_tvalid_reg <= 0;
                m_axis_tlast_reg  <= 0;
                if (buffer_switch) begin 
                    if (!fifo_last_out) begin
                        if (write_ptr_b > 5) begin
                            write_ptr_a <= extra_ptr_b_buf_1;
                            write_ptr_b <= 0;
                            buffer_switch <= !buffer_switch;
                            m_axis_tvalid_reg <= 1;
							switch_select_reg <= 2'b01;
                            if (remaining_ptr_a_buf_2 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_2[write_ptr_b+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_2[write_ptr_b+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end
                            if (extra_ptr_b_buf_1 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_1[i] <= fifo_data_out[(8 * (2 - i)) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_1[i] <= fifo_data_out[(8 * (2 - i)) +: 8];  // next bytes filled with 0
                                end
                            end 
                        end else begin
                            for (int i = 0; i < 3; i++) begin
                                buffer_2[write_ptr_b+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                            end
                                write_ptr_b <= (write_ptr_b + 3) ;
                        end
                    end
                    if (fifo_last_out) begin
                        m_axis_tvalid_reg <= 1;
						switch_select_reg <= 2'b01;
						reset_init    <= 1;
                            fifo_rd <= 1'b0;
							write_ptr_a <= 0;
							write_ptr_b <= 0;
                        if (write_ptr_b > 5) begin
							extr_data 		  <= 1;

                            if (extra_ptr_b_buf_1-1 <= 1) buffer_3[7] <= 8'h00;

                            if (extra_ptr_b_buf_1-1 <= 2) buffer_3[6] <= 8'h00;

                            if (extra_ptr_b_buf_1-1 <= 3) buffer_3[5] <= 8'h00;

                            if (extra_ptr_b_buf_1-1 <= 4) buffer_3[4] <= 8'h00;

                            if (extra_ptr_b_buf_1-1 <= 5) buffer_3[3] <= 8'h00;

                            if (extra_ptr_b_buf_1-1 <= 6) buffer_3[2] <= 8'h00;

                            if (extra_ptr_b_buf_1-1 <= 7) buffer_3[1] <= 8'h00;

                            if (extra_ptr_b_buf_1-1 <= 8) buffer_3[0] <= 8'h00;

                            if (remaining_ptr_a_buf_2 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_2[write_ptr_b+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_2[write_ptr_b+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end
                            if (extra_ptr_b_buf_1 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_3[i] <= fifo_data_out[16 + (8 * i) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_3[i] <= fifo_data_out[8 + (i * 8) +: 8];  // next bytes filled with 0
                                end
                            end 
                        end else begin
							m_axis_tlast_reg  <= 1;
                            for (int i = 0; i < 3; i++) begin
                                buffer_2[write_ptr_b+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                            end
                        end
                    end 
                end else begin
                    if (!fifo_last_out) begin
                        if (write_ptr_a > 5) begin
                            // Pad with zeroes to next 8-byte boundary
                            if (remaining_ptr_a_buf_1 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_1[write_ptr_a+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_1[write_ptr_a+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end
                            if (extra_ptr_b_buf_2 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_2[i] <= fifo_data_out[(8 * (2 - i)) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_2[i] <= fifo_data_out[(8 * (2 - i)) +: 8];  // next bytes filled with 0
                                end
                            end 
                                write_ptr_b <= extra_ptr_b_buf_2;
                                write_ptr_a <= 0;
                                buffer_switch <= !buffer_switch;
                                m_axis_tvalid_reg <= 1;
								switch_select_reg <= 2'b00;
                        end else begin
                            for (int i = 0; i < 3; i++) begin
                                buffer_1[write_ptr_a+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                            end
                                write_ptr_a <= (write_ptr_a + 3) ;
                        end
                    end
                    if (fifo_last_out) begin
                            m_axis_tvalid_reg <= 1;
							switch_select_reg <= 2'b00;
							reset_init    <= 1;
                                fifo_rd <= 1'b0;
								write_ptr_a <= 0;
								write_ptr_b <= 0;
                        if (write_ptr_a > 5) begin
								extr_data 		  <= 1;

                            if (extra_ptr_b_buf_2 >= 1) buffer_3[7] <= 8'h00;

                            if (extra_ptr_b_buf_2 >= 2) buffer_3[6] <= 8'h00;

                            if (extra_ptr_b_buf_2 >= 3) buffer_3[5] <= 8'h00;

                            if (extra_ptr_b_buf_2 >= 4) buffer_3[4] <= 8'h00;

                            if (extra_ptr_b_buf_2 >= 5) buffer_3[3] <= 8'h00;

                            if (extra_ptr_b_buf_2 >= 6) buffer_3[2] <= 8'h00;

                            if (extra_ptr_b_buf_2 >= 7) buffer_3[1] <= 8'h00;

                            if (extra_ptr_b_buf_2 >= 8) buffer_3[0] <= 8'h00;

                            if (remaining_ptr_a_buf_1 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_1[write_ptr_a+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_1[write_ptr_a+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                                end
                            end
                            if (extra_ptr_b_buf_2 == 1) begin
                                for (int i = 0; i < 1; i++) begin
                                    buffer_3[i] <= fifo_data_out[16 + (8 * i) +: 8];  // next bytes filled with 0
                                end
                            end else begin
                                for (int i = 0; i < 2; i++) begin
                                    buffer_3[i] <= fifo_data_out[8 + (i * 8) +: 8];  // next bytes filled with 0
                                end
                            end 
                        end else begin
								m_axis_tlast_reg  <= 1;
                            for (int i = 0; i < 3; i++) begin
                                buffer_1[write_ptr_a+i] <= fifo_data_out[(8 * i) +: 8];  // next bytes filled with 0
                            end
                        end
                    end 
                end
            end
		end
	end
endmodule
