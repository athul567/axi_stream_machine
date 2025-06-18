module stream_processor (
    input  logic clk,
    input  logic reset_n,

    // AXI4-Stream Input Channel 0
    input  logic [23:0] s_axis_tdata_0,
    input  logic        s_axis_tvalid_0,
    output logic        s_axis_tready_0,
    input  logic        s_axis_tlast_0,

    // AXI4-Stream Input Channel 1
    input  logic [23:0] s_axis_tdata_1,
    input  logic        s_axis_tvalid_1,
    output logic        s_axis_tready_1,
    input  logic        s_axis_tlast_1,

    // AXI4-Stream Output
    output logic [63:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tlast,

    // Configuration
    input  logic        config_mode,
    output logic        status_packets_size_mismatch
);
    // FIFO signals
    logic [23:0] fifo_dout [1:0];
    logic        fifo_valid[1:0];
    logic        fifo_full [1:0];
    logic        fifo_empty[1:0];
    logic        fifo_rd   [1:0];
    logic        fifo_wr   [1:0];

    logic [7:0] pkt_cnt;

    typedef enum logic [1:0] {
        IDLE,
        READ_FIFO
    } state_t;

    state_t state;

    // === FIFO Instances ===
    genvar ch;
    generate
        for (ch = 0; ch < 2; ch++) begin : gen_fifo
            axis_fifo #(
                .WIDTH(24),
                .DEPTH(256)
            ) fifo_inst (
                .clk     (clk),
                .reset   (~reset_n),
                .wr_en   (fifo_wr[ch]),
                .din     (s_axis_tdata[ch]),
                .full    (fifo_full[ch]),
                .rd_en   (fifo_rd[ch]),
                .dout    (fifo_dout[ch]),
                .valid   (fifo_valid[ch]),
                .empty   (fifo_empty[ch])
            );
        end
    endgenerate


    // === Input Side ===
    assign fifo_wr[0]      = s_axis_tvalid[0] && !fifo_full[0];
    assign fifo_wr[1]      = s_axis_tvalid[1] && !fifo_full[1];
    assign s_axis_tready[0] = !fifo_full[0];
    assign s_axis_tready[1] = !fifo_full[1];

    // === Output FSM ===
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            pkt_cnt <= 0;
            fifo_rd[0] <= 0;
            fifo_rd[1] <= 0;
            status_packets_size_mismatch <= 0;
        end else begin
            // defaults
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            fifo_rd[0] <= 0;
            fifo_rd[1] <= 0;

            case (state)
                IDLE: begin
                    pkt_cnt <= 0;
                    if (!config_mode && fifo_valid[0]) begin
                        state <= READ_FIFO;
                    end else if (config_mode && fifo_valid[0] && fifo_valid[1]) begin
                        state <= READ_FIFO;
                    end
                end

                READ_FIFO: begin
                    if (!config_mode) begin
                        if (fifo_valid[0] && m_axis_tready) begin
                            m_axis_tdata  <= {fifo_dout[0], fifo_dout[0], 16'h0}; // dummy 64-bit packet
                            m_axis_tvalid <= 1;
                            fifo_rd[0]    <= 1;
                            pkt_cnt       <= pkt_cnt + 1;
                            if (pkt_cnt == 5) begin
                                m_axis_tlast <= 1;
                                state <= IDLE;
                            end
                        end
                    end else begin
                        if (fifo_valid[0] && fifo_valid[1] && m_axis_tready) begin
                            m_axis_tdata  <= {fifo_dout[0], fifo_dout[1], 16'h0}; // interleaved
                            m_axis_tvalid <= 1;
                            fifo_rd[0]    <= 1;
                            fifo_rd[1]    <= 1;
                            pkt_cnt       <= pkt_cnt + 1;
                            if (pkt_cnt == 2) begin
                                m_axis_tlast <= 1;
                                state <= IDLE;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule
