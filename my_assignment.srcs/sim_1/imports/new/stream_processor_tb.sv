`timescale 1ns / 1ps

module tb_stream_processor_2;

    // Clock and Reset
    logic clk;
    logic clk_monitor;
    logic reset_n;

    // AXI4-Stream Inputs
    logic [1:0][23:0] s_axis_tdata;
    logic [1:0]       s_axis_tvalid;
    logic [1:0]       s_axis_tready;
    logic [1:0]       s_axis_tlast;

    // AXI4-Stream Output
    logic [63:0]      m_axis_tdata;
    logic             m_axis_tvalid;
    logic             m_axis_tready;
    logic             m_axis_tlast;

    // Configuration
    logic             config_mode;
    logic             status_packets_size_mismatch;

    // Data counters
    logic [7:0] ch0_data_counter = 8'hA0;
    logic [7:0] ch1_data_counter = 8'hA0;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        clk_monitor = 0;
        #1;
        forever #5 clk_monitor = ~clk_monitor;
    end

    // DUT instantiation
    stream_processor dut (
        .clk(clk),
        .reset_n(reset_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .config_mode(config_mode),
        .status_packets_size_mismatch(status_packets_size_mismatch)
    );

    // ✅ Correct byte order: a2a1a0, starting from a0 = A0
    task automatic generate_channel_data(input int channel, input int beat_num, output logic [23:0] data);
        logic [7:0] a0, a1, a2;
        if (channel == 0) begin
            a0 = ch0_data_counter;
            a1 = ch0_data_counter + 1;
            a2 = ch0_data_counter + 2;
            ch0_data_counter += 3;
        end else begin
            a0 = ch1_data_counter;
            a1 = ch1_data_counter + 1;
            a2 = ch1_data_counter + 2;
            ch1_data_counter += 3;
        end
        data = {a2, a1, a0}; // MSB = a2, LSB = a0
        $display(">> GEN CH%0d: a2=%02x a1=%02x a0=%02x → DATA=%06x", channel, a2, a1, a0, data);
    endtask

    task automatic send_beat(input int channel, input int beat_num, input int total_beats);
        logic [23:0] data;
        logic is_last;

        generate_channel_data(channel, beat_num, data);
        is_last = (beat_num == total_beats);

        @(posedge clk);
        s_axis_tdata[channel] <= data;
        s_axis_tvalid[channel] <= 1'b1;
        s_axis_tlast[channel] <= is_last;

        // Wait for AXI4-Stream handshake
        do @(posedge clk); while (!(s_axis_tvalid[channel] && s_axis_tready[channel]));

        $display("@%0t CH%0d SENT BEAT %0d/%0d: DATA=%06x, LAST=%0d",
                 $time, channel, beat_num, total_beats, data, is_last);

        s_axis_tvalid[channel] <= 1'b0;
        s_axis_tlast[channel] <= 1'b0;
    endtask

    task automatic send_packet(input int channel, input int packet_size);
        $display("@%0t\n=== Starting packet transmission on CH%0d (Size: %0d) ===", $time, channel, packet_size);
        for (int i = 1; i <= packet_size; i++) begin
            send_beat(channel, i, packet_size);
        end
        $display("@%0t === Completed packet transmission on CH%0d ===\n", $time, channel);
    endtask

    // Output monitor
    always @(posedge clk) begin
        if (reset_n && m_axis_tvalid && m_axis_tready) begin
            $display("@%0t                              -> MASTER_OUTPUT: %02x_%02x_%02x_%02x_%02x_%02x_%02x_%02x LAST=%0d",
                     $time,
                     m_axis_tdata[63:56], m_axis_tdata[55:48], m_axis_tdata[47:40], m_axis_tdata[39:32],
                     m_axis_tdata[31:24], m_axis_tdata[23:16], m_axis_tdata[15:8],  m_axis_tdata[7:0],
                     m_axis_tlast);
        end
    end

    // Master ready toggling
    initial begin
        m_axis_tready = 1;
        #42;
        forever begin
            m_axis_tready = $urandom_range(0, 1);
            repeat($urandom_range(1, 4)) @(negedge clk);
        end
    end

    task test_basic();
        $display("@%0t\n*** TEST: CH0 and CH1 sending packets ***", $time);
        config_mode = 0;
        #10;

        fork
            send_packet(0, 5);
            send_packet(1, 5);
        join

        #50;
    endtask

    initial begin
        // Reset
        reset_n = 0;
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        config_mode = 0;
        m_axis_tready = 1;

        #20;
        reset_n = 1;
        #20;

        $display("@%0t === AXI4-Stream Processor Testbench Started ===", $time);
        test_basic();
        #20;
        test_basic();
        #20;
        test_basic();


        $display("@%0t === Testbench completed ===", $time);
        $finish;
    end

    // Timeout
    initial begin
        #10000;
        $display("@%0t ERROR: Testbench timeout!", $time);
        $finish;
    end

    initial begin
        $dumpfile("stream_processor_tb.vcd");
        $dumpvars(0, tb_stream_processor_2);
    end

endmodule