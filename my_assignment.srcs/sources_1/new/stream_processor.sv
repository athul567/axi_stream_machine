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
	logic 		 both_empty;
	logic        fifo_valid [1:0];
    logic        fifo_rd   [1:0];
	logic 		 fifo_rd_1 [1:0];
    logic        fifo_wr   [1:0];


// Internal signals
logic [7:0] buffer_1_1 [10:0];
logic [7:0] buffer_1_2 [10:0];
logic [7:0] buffer_1_3 [10:0];

logic [7:0] buffer_2_1 [10:0];
logic [7:0] buffer_2_2 [10:0];
logic [7:0] buffer_2_3 [10:0];
logic m_axis_tvalid_reg;


logic buffer_switch[1:0];
logic [5:0] write_ptr_a[1:0];
logic [5:0] write_ptr_b[1:0];
logic [1:0] back_pressure;
logic [1:0][24:0] fifo_din;  // 24-bit data + 8-bit control (tlast + padding)
logic [1:0][24:0] fifo_dout;
logic fifo_ready[1:0];
logic [2:0] remaining_ptr_a_buf_1;
logic [2:0] extra_ptr_b_buf_1;
logic [2:0] remaining_ptr_a_buf_2;
logic [2:0] extra_ptr_b_buf_2;
logic [1:0][23:0] fifo_data_out; 
logic [1:0] fifo_last_out;  
logic [1:0] s_rst_n;
logic [1:0] ch_enable;
logic [2:0] m_axis_tlast_sig;
logic inter_m_axis_tlast;
logic  m_axis_tlast_both;
logic [1:0] reset_init;
logic [1:0] data_valid;
//
logic [7:0] pkt_cnt_fifo [1:0];
logic axi_out_mux;
logic [63:0] m_axis_tdata_after_mux;

    typedef enum logic [2:0] {
        IDLE,
        READ_FIFO,NON_INTER_MODE_CH1_INIT,NON_INTER_MODE_CH1_DATA_PROCESS,NON_INTER_MODE_CH2_DATA_PROCESS,INTER_MODE_CH1
    } state_t;

    state_t state;

    // Extract data from FIFO 

assign fifo_data_out[0]  = fifo_dout[0][23:0];
assign fifo_data_out[1]  = fifo_dout[1][23:0];
assign fifo_last_out[0]  = fifo_dout[0][24];    
assign fifo_last_out[1]  = fifo_dout[1][24];


assign m_axis_tlast_both = fifo_last_out[0] & fifo_last_out[1];
    // Pack data into FIFO
assign fifo_din[0] = {s_axis_tlast[0],s_axis_tdata[0]};
assign fifo_din[1] = {s_axis_tlast[1],s_axis_tdata[1]};

// Declare signals to connect to the submodule
logic [23:0] fifo_data_out_1;
logic [23:0] fifo_data_out_2;
logic        fifo_last;
logic        int_tready;
logic        fifo_rd_intr;

logic        intr_axis_tvalid;
logic        intr_axis_tlast;
logic        intr_reset_init;

logic [7:0] buffer_1 [7:0];
logic [7:0] buffer_2 [7:0];
logic [7:0] buffer_3 [7:0];
logic load_buffer,first_data;
logic [63:0] m_axis_tdata_sig;


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






logic both_fifo_valid;
logic [7:0]  inter_m_axis_tdata [7:0];
logic inter_buffer_has_data;

assign m_axis_tdata_sig = {
    inter_m_axis_tdata[7],
    inter_m_axis_tdata[6],
    inter_m_axis_tdata[5],
    inter_m_axis_tdata[4],
    inter_m_axis_tdata[3],
    inter_m_axis_tdata[2],
    inter_m_axis_tdata[1],
    inter_m_axis_tdata[0]
};



non_inter_machine u_non_inter_machine_1  (
    .clk                (clk),
    .reset_n            (s_rst_n[0]),

    .fifo_data_out      (fifo_data_out[0]),
    .fifo_rd            (fifo_rd_1[0]),
    .start_proces       (ch_enable[0]),
    .fifo_last_out      (fifo_last_out[0]),
	.m_axis_tready      (back_pressure[0]),

    .m_axis_tvalid  	(data_valid[0]),
    .m_axis_tlast       (m_axis_tlast_sig[0]),
    .switch_select      (switch_select[0]),
	.reset_init			(reset_init[0]),
    .buffer_1           (buffer_1_1),
    .buffer_2           (buffer_1_2),
    .buffer_3           (buffer_1_3)
);

non_inter_machine u_non_inter_machine_2 (
    .clk                (clk),
    .reset_n            (s_rst_n[1]),

    .fifo_data_out      (fifo_data_out[1]),
    .fifo_rd            (fifo_rd_1[1]),
    .start_proces       (ch_enable[1]),
    .fifo_last_out      (fifo_last_out[1]),
	.m_axis_tready      (back_pressure[1]),

    .m_axis_tvalid  	(data_valid[1]),
    .m_axis_tlast       (m_axis_tlast_sig[1]),
    .switch_select      (switch_select[1]),
	.reset_init			(reset_init[1]),
    .buffer_1           (buffer_2_1),
    .buffer_2           (buffer_2_2),
    .buffer_3           (buffer_2_3)
);


inter_machine u_inter_machine (
    .clk          			(clk)					,
    .reset_n     			(reset_n)				,
    .fifo_data_out_1 		(fifo_data_out[0])		,
    .fifo_data_out_2 		(fifo_data_out[1])		,
    .fifo_tlast 			(m_axis_tlast_both)		,
    .inter_m_axis_tready 	(m_axis_tready)			,
	.fifo_valid				(both_fifo_valid)		,
	.inter_m_axis_tvalid	(m_axis_tvalid)  		,
    .fifo_read      		(fifo_rd_intr)			,
	.inter_buffer_has_data	(inter_buffer_has_data)	,
    .inter_m_axis_tlast  	(inter_m_axis_tlast)	,  
	.inter_m_axis_tdata		(inter_m_axis_tdata)
);

    // === Input Side ===
    assign fifo_wr[0]      = s_axis_tvalid[0] && !fifo_full[0];
    assign fifo_wr[1]      = s_axis_tvalid[1] && !fifo_full[1];
    assign s_axis_tready[0] = !fifo_full[0];
    assign s_axis_tready[1] = !fifo_full[1];
	assign both_fifo_valid  = fifo_valid [0] && fifo_valid[1];


    // === Output FSM ===
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            pkt_cnt_fifo[1] <= 0;
            pkt_cnt_fifo[0] <= 0;
            status_packets_size_mismatch <= 0;
            write_ptr_a[0] <= 1'b0;
            write_ptr_b[0] <= 1'b0;
            write_ptr_a[1] <= 1'b0;
            write_ptr_b[1] <= 1'b0;
            buffer_switch[0] <= 1'b0;
            buffer_switch[1] <= 1'b0;
			s_rst_n 		 <= 2'b0;
			ch_enable  <=  2'b00;
			back_pressure <= 2'b00;
			axi_out_mux  	<= 1'b0;
			//start_proces <= 1'b0;

        end else begin
            case (state)
                IDLE: begin
						s_rst_n[1] 		 <= 1'b0;
						s_rst_n[0] 		 <= 1'b1;
                    if (!config_mode) begin
                        state <= NON_INTER_MODE_CH1_INIT;
                    end else begin
                        state <= INTER_MODE_CH1;
                    end
                end
                NON_INTER_MODE_CH1_INIT: begin
						// initial data process for ch1
					if (fifo_valid[0] && pkt_cnt_fifo[0] == 2) begin
						state <= NON_INTER_MODE_CH1_DATA_PROCESS;
						pkt_cnt_fifo[0] <= 0;
                          end else if (fifo_valid[0]) begin
						pkt_cnt_fifo[0] <= pkt_cnt_fifo[0] + 1;
						ch_enable[0] <= 1;
					end else begin
						ch_enable[0] <= 0;
					end  
                end
                NON_INTER_MODE_CH1_DATA_PROCESS: begin
						pkt_cnt_fifo[0] <= 0;
						axi_out_mux  	<= 1'b0;
					if (reset_init[0] && m_axis_tlast_sig[0] && m_axis_tready) begin
						state 			<= NON_INTER_MODE_CH2_DATA_PROCESS;
						s_rst_n[0] 		<= 1'b0;
						ch_enable[0] <= 0;
					end else if (!m_axis_tready) begin 
						ch_enable[0] <= 0;
					end else if (m_axis_tready && fifo_valid[0]) begin
						ch_enable[0] <= 1;
					end 

						// initial data process for ch2
                    if (fifo_valid[1] && pkt_cnt_fifo[1]==3) begin
						ch_enable[1] <= 0;
						pkt_cnt_fifo[1] <= pkt_cnt_fifo[1];
					end else if(fifo_valid[1] && pkt_cnt_fifo[1]==0) begin
						s_rst_n[1] 		<= 1'b1;
						ch_enable[1] <= 0;
						pkt_cnt_fifo[1] <= pkt_cnt_fifo[1] + 1;
					end else if (fifo_valid[1]) begin 
						pkt_cnt_fifo[1] <= pkt_cnt_fifo[1] + 1;
						ch_enable[1] <= 1;
					end else  begin
						ch_enable[1] <= 0;
                    end

				end
                NON_INTER_MODE_CH2_DATA_PROCESS: begin
								pkt_cnt_fifo[1] <= 0;
								axi_out_mux  	<= 1'b1;
					if (reset_init[1] && m_axis_tlast_sig[1] && m_axis_tready) begin
						state 			<= NON_INTER_MODE_CH1_DATA_PROCESS;
						s_rst_n[1] 		<= 1'b0;
						ch_enable[1] <= 0;
					end else if (!m_axis_tready) begin 
						ch_enable[1] <= 0;
					end else if (m_axis_tready && fifo_valid[1]) begin
						ch_enable[1] <= 1;
					end 
						// initial data process for ch2
                    if (fifo_valid[0] && pkt_cnt_fifo[0]==3) begin
						ch_enable[0] <= 0;
						pkt_cnt_fifo[0] <= pkt_cnt_fifo[0];
					end else if(fifo_valid[0] && pkt_cnt_fifo[0]==0) begin
						s_rst_n[0] 		<= 1'b1;
						ch_enable[0] <= 0;
						pkt_cnt_fifo[0] <= pkt_cnt_fifo[0] + 1;
					end else if (fifo_valid[0]) begin 
						pkt_cnt_fifo[0] <= pkt_cnt_fifo[0] + 1;
						ch_enable[0] <= 1;
					end else  begin
						ch_enable[0] <= 0;
                    end
                end
                INTER_MODE_CH1: begin
							//start_proces <= fifo_valid[0] & fifo_valid[1];
				end
            endcase
        end
    end
mux_st switch_select;
    // -------------------------
    // Stage 2: AXI output stage
    // -------------------------
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
			m_axis_tdata <= '{default:8'h00};
            m_axis_tvalid <= 1'b0;
			m_axis_tlast <= 0;
    end else begin
        if (m_axis_tvalid && m_axis_tready) begin
            if (inter_buffer_has_data) begin
                m_axis_tdata  <= m_axis_tdata_sig;
                m_axis_tvalid <= 1'b1;
				m_axis_tlast  <= inter_m_axis_tlast;
            end else begin
                m_axis_tvalid <= 1'b0; // No more data to send
				m_axis_tdata  <= '{default:8'h00};
				m_axis_tlast <= 0;
            end
        end else if (!m_axis_tvalid && inter_buffer_has_data) begin
            // Load data for the first time
            m_axis_tdata  <= m_axis_tdata_sig;
            m_axis_tvalid <= 1'b1;
			m_axis_tlast  <= inter_m_axis_tlast;
        end
    end
end



assign fifo_rd[0] = fifo_rd_intr;
assign fifo_rd[1] = fifo_rd_intr;
assign both_empty = fifo_empty[1] | fifo_empty[0];



endmodule
