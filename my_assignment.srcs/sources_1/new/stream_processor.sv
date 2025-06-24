import all_pkg::*;


module stream_processor (
    input  logic clk,
    input  logic reset_n,

    // AXI4-Stream Inputs
    input  logic [1:0][23:0] s_axis_tdata,
    input  logic [1:0]       s_axis_tvalid,
    output logic [1:0]       s_axis_tready,
    input  logic [1:0]       s_axis_tlast,

    // AXI4-Stream Output
    output logic [63:0]      m_axis_tdata,
    output logic             m_axis_tvalid,
    input  logic             m_axis_tready,
    output logic             m_axis_tlast,

    // Configuration
    input  logic             config_mode, // 0: non-interleaved, 1: interleaved
    output logic             status_packets_size_mismatch
);

    // FIFO signals
    logic        start_proces,start_proces_1f,m_axis_tready_next;
    logic        fifo_full [1:0];
    logic        fifo_empty[1:0];
	logic        fifo_valid [1:0];
    logic        fifo_rd   [1:0];
	logic 		 non_inter_fifo_rd [1:0];
	logic 		 fifo_rd_1 [1:0];
    logic        fifo_wr   [1:0];


// Internal signals
logic [1:0][24:0] fifo_din;  // 24-bit data + 8-bit control (tlast + padding)
logic [1:0][24:0] fifo_dout;
logic [1:0][23:0] fifo_data; 
logic [1:0] fifo_tlast;  
logic [1:0] ch_enable;
logic inter_enable;
logic [1:0] m_axis_tlast_sig;
logic inter_buffer_tlast;
logic  m_axis_tlast_both;
logic [1:0] reset_init;
mux_st switch_select;
logic [63:0] inter_buffer_data_stage_2;
logic internal_buffer_valid_inter;
logic ch0_valid_stage_2;
logic ch1_valid_stage_2;
logic inter_buffer_last;
logic ch0_last_stage_2;
logic ch1_last_stage_2;
logic internal_buffer_ready_inter;
logic ch0_ready_stage_0;
logic ch1_ready_stage_0;
logic ch0_ready_stage_1;
logic ch1_ready_stage_1;
logic buffer_valid;
logic [7:0] pkt_cnt_fifo [1:0];
logic [63:0] m_axis_tdata_after_mux;
logic non_inter_mode_ch_0;
logic non_inter_mode_ch_1;
logic ch0_stop;
logic ch1_stop;
state_t state;
logic        fifo_rd_intr;
logic [63:0] inter_buffer_data;
logic ch1_last_stage_1;
logic ch0_last_stage_1;
logic [63:0] ch0_data_stage_1;
logic [63:0] ch1_data_stage_1;
logic [63:0] ch0_data_stage_2;
logic [63:0] ch1_data_stage_2;
logic both_fifo_valid;
logic [7:0]  inter_buffer_tdata [7:0];
logic [7:0]  non_inter_m_axis_tdata_slv_0 [7:0];
logic [7:0]  non_inter_m_axis_tdata_slv_1 [7:0];
logic inter_buffer_has_data;
logic ch0_valid_stage_1;
logic ch1_valid_stage_1;
logic ninter_enable;
// === FIFO Instances ===
genvar ch;
generate
    for (ch = 0; ch < 2; ch++) begin : sync_fifo
        sync_fifo #(
            .WIDTH(25),
            .DEPTH(256)
        ) fifo_inst (
            .clk     (clk),
            .reset   (~reset_n),
            .wr_en   (fifo_wr[ch]),
            .din     (fifo_din[ch]),
            .full    (fifo_full[ch]),
            .rd_en   (fifo_rd[ch]),
            .dout    (fifo_dout[ch]),
            .valid   (fifo_valid[ch]),
            .empty   (fifo_empty[ch])
        );
    end
endgenerate
non_inter_machine u_non_inter_machine_1  (
    .clk                			(clk),
    .reset_n            			(reset_n),
	.enable							(ch_enable[0]),
    .fifo_data          			(fifo_data[0]),
	.fifo_valid						(fifo_valid[0]),
    .fifo_tlast    	  				(fifo_tlast[0]),
	.inter_buffer_ready      		(ch0_ready_stage_0),
    .fifo_read          			(non_inter_fifo_rd[0]),
	.non_inter_buffer_has_data		(ch0_valid_stage_1),
    .non_inter_m_axis_tlast       	(ch0_last_stage_1),
    .non_inter_m_axis_tdata         (non_inter_m_axis_tdata_slv_0)
);

non_inter_machine u_non_inter_machine_2  (
    .clk                			(clk),
    .reset_n            			(reset_n),
	.enable 						(ch_enable[1]),
    .fifo_data          			(fifo_data[1]),
    .fifo_tlast    	  				(fifo_tlast[1]),
	.fifo_valid						(fifo_valid[1]),
	.inter_buffer_ready      		(ch1_ready_stage_0),
    .fifo_read            			(non_inter_fifo_rd[1]),
	.non_inter_buffer_has_data		(ch1_valid_stage_1),
    .non_inter_m_axis_tlast       	(ch1_last_stage_1),
    .non_inter_m_axis_tdata         (non_inter_m_axis_tdata_slv_1)
);

inter_machine u_inter_machine (
    .clk          			(clk),
    .reset_n     			(reset_n),
	.enable					(inter_enable),
    .fifo_data_out_1 		(fifo_data[0]),
    .fifo_data_out_2 		(fifo_data[1]),
    .fifo_tlast 			(m_axis_tlast_both),
	.fifo_valid				(both_fifo_valid),
    .inter_buffer_ready 	(internal_buffer_ready_inter),
    .fifo_read      		(fifo_rd_intr),
	.inter_buffer_has_data	(inter_buffer_has_data),
    .inter_buffer_tlast  	(inter_buffer_tlast),  
	.inter_buffer_tdata		(inter_buffer_tdata)
);

// Data to FIFO
assign fifo_wr[0]      = s_axis_tvalid[0] && !fifo_full[0];
assign fifo_wr[1]      = s_axis_tvalid[1] && !fifo_full[1];
assign s_axis_tready[0] = !fifo_full[0];
assign s_axis_tready[1] = !fifo_full[1];
assign both_fifo_valid  = fifo_valid [0] && fifo_valid[1];

    // Extract data from FIFO 
assign fifo_data[0]  = fifo_dout[0][23:0];
assign fifo_data[1]  = fifo_dout[1][23:0];
assign fifo_tlast[0]  = fifo_dout[0][24];    
assign fifo_tlast[1]  = fifo_dout[1][24];
assign m_axis_tlast_both = fifo_tlast[0] & fifo_tlast[1];
assign fifo_din[0] = {s_axis_tlast[0],s_axis_tdata[0]};
assign fifo_din[1] = {s_axis_tlast[1],s_axis_tdata[1]};




assign inter_buffer_data = {
    inter_buffer_tdata[7],
    inter_buffer_tdata[6],
    inter_buffer_tdata[5],
    inter_buffer_tdata[4],
    inter_buffer_tdata[3],
    inter_buffer_tdata[2],
    inter_buffer_tdata[1],
    inter_buffer_tdata[0]
};

assign ch0_data_stage_1 = {
    non_inter_m_axis_tdata_slv_0[7],
    non_inter_m_axis_tdata_slv_0[6],
    non_inter_m_axis_tdata_slv_0[5],
    non_inter_m_axis_tdata_slv_0[4],
    non_inter_m_axis_tdata_slv_0[3],
    non_inter_m_axis_tdata_slv_0[2],
    non_inter_m_axis_tdata_slv_0[1],
    non_inter_m_axis_tdata_slv_0[0]
};

assign ch1_data_stage_1 = {
    non_inter_m_axis_tdata_slv_1[7],
    non_inter_m_axis_tdata_slv_1[6],
    non_inter_m_axis_tdata_slv_1[5],
    non_inter_m_axis_tdata_slv_1[4],
    non_inter_m_axis_tdata_slv_1[3],
    non_inter_m_axis_tdata_slv_1[2],
    non_inter_m_axis_tdata_slv_1[1],
    non_inter_m_axis_tdata_slv_1[0]
};
    // === Output FSM ===
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= STATE_IDLE;
            status_packets_size_mismatch <= 0;
			ch_enable  <=  2'b00;
			inter_enable <= 0;
			ninter_enable <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (!config_mode) begin
                        state <= NON_INTER_MODE;
						ch_enable  <=  2'b11;
						ninter_enable <= 1;
						inter_enable <= 0;
                    end else begin
                        state <= INTER_MODE_CH1;
						ch_enable  <=  2'b00;
						inter_enable <= 1;
                    end
                end
                NON_INTER_MODE: begin
                    if (!config_mode) begin
                        state <= NON_INTER_MODE;
						ch_enable  <=  2'b11;
						ninter_enable <= 1;
						inter_enable <= 0;
                    end else begin
                        state <= INTER_MODE_CH1;
						ch_enable  <=  2'b00;
						inter_enable <= 1;
                    end
                end
                INTER_MODE_CH1: begin
                    if (!config_mode) begin
                        state <= NON_INTER_MODE;
						ch_enable  <=  2'b11;
						ninter_enable <= 1;
						inter_enable <= 0;
                    end else begin
                        state <= INTER_MODE_CH1;
						ch_enable  <=  2'b00;
						inter_enable <= 1;
                    end
                end
            endcase
        end
    end


assign internal_buffer_ready_inter 			= !internal_buffer_valid_inter || (!m_axis_tvalid || m_axis_tready);
assign ch0_ready_stage_0 					= !ch0_valid_stage_2 || (non_inter_mode_ch_0) && ch0_ready_stage_1;  // backpressure
assign ch1_ready_stage_0 					= !ch1_valid_stage_2 || (non_inter_mode_ch_1) && ch1_ready_stage_1;  // backpressure

//assign ch0_ready_stage_0 					= (non_inter_mode_ch_0) && ch0_ready_stage_1;  // backpressure
//assign ch1_ready_stage_0 					= (non_inter_mode_ch_1) && ch1_ready_stage_1;  // backpressure


assign ch0_ready_stage_1 					= (!ch0_valid_stage_2 || (!m_axis_tvalid || m_axis_tready));
assign ch1_ready_stage_1 					= (!ch1_valid_stage_2 || (!m_axis_tvalid || m_axis_tready));
// -------------------------
// Stage 2: Internal Register before output
// -------------------------
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
			inter_buffer_data_stage_2 <= '{default:8'h00};
			ch0_data_stage_2 <= '{default:8'h00};
			ch1_data_stage_2 <= '{default:8'h00};
			inter_buffer_last <= 1'b0;
			ch0_last_stage_2 <= 1'b0;
			ch1_last_stage_2 <= 1'b0;
			internal_buffer_valid_inter <= 1'b0;
			ch0_valid_stage_2 <= 1'b0;
			ch1_valid_stage_2 <= 1'b0;
			ch0_stop				  		  <= 0;
			ch1_stop				  		  <= 0;
    end else begin

// This is for inter mode
		if (internal_buffer_ready_inter && inter_buffer_has_data) begin  
			inter_buffer_data_stage_2 <= inter_buffer_data;
			internal_buffer_valid_inter <= 1'b1;
			inter_buffer_last <= inter_buffer_tlast;
		end else if (internal_buffer_valid_inter && internal_buffer_ready_inter) begin
			internal_buffer_valid_inter <= 1'b0;
			inter_buffer_last <= 1'b0;
		end
// This is for non-inter mode chn0
			if (ch0_ready_stage_0 && ch0_valid_stage_1) begin
				ch0_data_stage_2 	<= ch0_data_stage_1;
				ch0_valid_stage_2 	<= 1'b1;
				ch0_last_stage_2 	<= ch0_last_stage_1;
			end else if (ch0_valid_stage_2 && ch0_ready_stage_0) begin
				ch0_valid_stage_2 	<= 1'b0;
				ch0_last_stage_2 	<= 1'b0;
			end
// This is for non-inter mode chn1
			if (ch1_ready_stage_0 && ch1_valid_stage_1) begin
				ch1_data_stage_2 	<= ch1_data_stage_1;
				ch1_valid_stage_2 	<= 1'b1;
				ch1_last_stage_2 	<= ch1_last_stage_1;
			end else if (ch1_valid_stage_2 && ch1_ready_stage_0) begin
				ch1_valid_stage_2 	<= 1'b0;
				ch1_last_stage_2 	<= 1'b0;
			end
    end
end
// -------------------------
// Stage 3: AXI output stage
// -------------------------
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        m_axis_tdata <= '{default:8'h00};
        m_axis_tvalid <= 1'b0;
        m_axis_tlast <= 1'b0;
		non_inter_mode_ch_0 <= 1;
		non_inter_mode_ch_1 <= 0;
    end else begin
		// This is for inter mode
		if (inter_enable) begin
			if (m_axis_tvalid && m_axis_tready) begin
				if (internal_buffer_valid_inter) begin
					m_axis_tdata  <= inter_buffer_data_stage_2;
					m_axis_tvalid <= 1'b1;
					m_axis_tlast  <= inter_buffer_last;
				end else begin
					m_axis_tvalid <= 1'b0;
					m_axis_tlast  <= 1'b0;
				end 
			end else if (!m_axis_tvalid && internal_buffer_valid_inter) begin
				m_axis_tdata  <= inter_buffer_data_stage_2;
				m_axis_tvalid <= 1'b1;
				m_axis_tlast  <= inter_buffer_last;
			end
		end

		if (ninter_enable) begin
			if (non_inter_mode_ch_0) begin 							// This is for non-inter mode chn0
				if (m_axis_tvalid && m_axis_tready) begin
					if (ch0_valid_stage_2) begin
						m_axis_tdata  <= ch0_data_stage_2;
						m_axis_tvalid <= 1'b1;
						m_axis_tlast  <= ch0_last_stage_2;
					end else begin
						m_axis_tvalid <= 1'b0;
						m_axis_tlast  <= 1'b0;
					end 
				end else if (!m_axis_tvalid && ch0_valid_stage_2) begin
					m_axis_tdata  <= ch0_data_stage_2;
					m_axis_tvalid <= 1'b1;
					m_axis_tlast  <= ch0_last_stage_2;
				end
				if (ch0_last_stage_2&&((m_axis_tvalid && m_axis_tready) || (!m_axis_tvalid && ch0_valid_stage_2))) begin
							non_inter_mode_ch_0 <= 0;
							non_inter_mode_ch_1 <= 1;
				end
			end else if (non_inter_mode_ch_1) begin 				// This is for non-inter mode chn1
				if (m_axis_tvalid && m_axis_tready) begin
					if (ch1_valid_stage_2) begin
						m_axis_tdata  <= ch1_data_stage_2;
						m_axis_tvalid <= 1'b1;
						m_axis_tlast  <= ch1_last_stage_2;
					end else begin
						m_axis_tvalid <= 1'b0;
						m_axis_tlast  <= 1'b0;
					end 
				end else if (!m_axis_tvalid && ch1_valid_stage_2) begin
					m_axis_tdata  <= ch1_data_stage_2;
					m_axis_tvalid <= 1'b1;
					m_axis_tlast  <= ch1_last_stage_2;
				end
				if (ch1_last_stage_2&&((m_axis_tvalid && m_axis_tready) || (!m_axis_tvalid && ch1_valid_stage_2))) begin
							non_inter_mode_ch_0 <= 1;
							non_inter_mode_ch_1 <= 0;
				end
			end
		end
	end
end


always_comb begin
	if (config_mode) begin
		fifo_rd[0] = fifo_rd_intr ;
		fifo_rd[1] = fifo_rd_intr ;
	end else begin
		fifo_rd[0] = non_inter_fifo_rd[0];
		fifo_rd[1] = non_inter_fifo_rd[1];
	end
end 


endmodule
