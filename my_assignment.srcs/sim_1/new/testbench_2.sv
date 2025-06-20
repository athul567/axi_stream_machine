`timescale 1ns/1ps

module tb_stream_processor;

    // Clock and Reset
    logic clk;
    logic reset_n;
    
    // AXI4-Stream Slave Interfaces
    logic [1:0][23:0] s_axis_tdata;
    logic [1:0]       s_axis_tvalid;
    logic [1:0]       s_axis_tready;
    logic [1:0]       s_axis_tlast;
    
    // AXI4-Stream Master Interface
    logic [63:0]      m_axis_tdata;
    logic             m_axis_tvalid;
    logic             m_axis_tready;
    logic             m_axis_tlast;
    
    // Configuration and Status
    logic             config_mode;
    logic             status_packets_size_mismatch;

    // Instantiate DUT
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

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Test control variables
    int test_errors = 0;
    int test_passed = 0;
    
    // Data counters for each channel
    int ch0_data_counter = 1;
    int ch1_data_counter = 1;

    //======================================================================
    // Test Classes and Tasks
    //======================================================================

    class axi_stream_packet;
        logic [23:0] data_queue[$];
        rand int packet_size;
        
        constraint packet_size_c {
            packet_size inside {[4:16]}; // Random packet size between 4-16 beats
        }
        
        function void generate_data(int channel, ref int data_counter);
            data_queue = {};
            for (int i = 0; i < packet_size; i++) begin
                data_queue.push_back(data_counter);
                data_counter++;
            end
        endfunction
        
        function void print_packet(int pkt_num, int channel);
            $display("--- Packet %0d on Channel %0d ---", pkt_num, channel);
            $display("Packet Size: %0d beats", packet_size);
            for (int i = 0; i < data_queue.size(); i++) begin
                $display("  Data[%0d]: 0x%06h", i, data_queue[i]);
            end
        endfunction
    endclass

    // Task to send incremental data on specified slave channel
    task automatic send_axi_stream_data(
        input int channel,          // 0 or 1 for slave channel
        input int num_packets,      // Number of packets to send
        input string test_name = "DEFAULT"
    );
        axi_stream_packet pkt;
        int beat_count;
        int packet_num;
        
        for (packet_num = 0; packet_num < num_packets; packet_num++) begin
            pkt = new();
            assert(pkt.randomize()) else $fatal("Randomization failed");
            
            // Generate incremental data based on channel
            if (channel == 0) begin
                pkt.generate_data(channel, ch0_data_counter);
            end else begin
                pkt.generate_data(channel, ch1_data_counter);
            end
            
            beat_count = 0;
            
            // Send each beat in the packet (no print statements for slave side)
            while (beat_count < pkt.packet_size) begin
                @(posedge clk);
                
                // Set up the data and control signals
                s_axis_tdata[channel] = pkt.data_queue[beat_count];
                s_axis_tvalid[channel] = 1'b1;
                s_axis_tlast[channel] = (beat_count == pkt.packet_size - 1);
                
                // Wait for ready handshake
                while (!s_axis_tready[channel]) begin
                    @(posedge clk);
                end
                
                beat_count++;
            end
            
            // Deassert valid after packet
            @(posedge clk);
            s_axis_tvalid[channel] = 1'b0;
            s_axis_tlast[channel] = 1'b0;
            
            // Add some idle cycles between packets
            repeat($urandom_range(1,4)) @(posedge clk);
        end
    endtask

    // Task to monitor and print only master output
    task automatic monitor_master_output(input string test_name = "MONITOR");
        int beat_count = 0;
        int packet_count = 0;
        
        $display("\n=== Master Output Monitor: %s ===", test_name);
        
        forever begin
            @(posedge clk);
            
            if (m_axis_tvalid && m_axis_tready) begin
                $display("[%0t] MASTER: Beat[%0d] Data=0x%016h Last=%b", 
                         $time, beat_count, m_axis_tdata, m_axis_tlast);
                
                beat_count++;
                
                if (m_axis_tlast) begin
                    packet_count++;
                    $display("[%0t] MASTER: Packet %0d completed (%0d beats)", $time, packet_count, beat_count);
                    $display(""); // Empty line for readability
                    beat_count = 0;
                end
            end
            
            // Monitor status signals
            if (status_packets_size_mismatch) begin
                $display("[%0t] STATUS: Packet size mismatch detected!", $time);
                test_errors++;
            end
        end
    endtask

    // Combined test task for both channels
    task automatic test_dual_channel_random(
        input int packets_per_channel,
        input logic test_config_mode,
        input string test_name
    );
        
        // Set configuration
        config_mode = test_config_mode;
        
        // Initialize all slave signals
        s_axis_tdata = '0;
        s_axis_tvalid = '0;
        s_axis_tlast = '0;
        m_axis_tready = 1'b1; // Master ready to receive
        
        $display("\n########## %s ##########", test_name);
        $display("Config Mode: %s", config_mode ? "INTERLEAVED" : "NON-INTERLEAVED");
        $display("Packets per channel: %0d", packets_per_channel);
        
        // Start master monitor in parallel
        fork
            monitor_master_output(test_name);
        join_none
        
        if (config_mode) begin
            // Interleaved mode: send packets alternating between channels
            fork
                begin
                    for (int i = 0; i < packets_per_channel; i++) begin
                        send_axi_stream_data(0, 1, $sformatf("%s_CH0_PKT%0d", test_name, i));
                        #200; // Small delay between channel switches
                        send_axi_stream_data(1, 1, $sformatf("%s_CH1_PKT%0d", test_name, i));
                        #200;
                    end
                end
            join
        end else begin
            // Non-interleaved mode: send all packets on channel 0, then channel 1
            fork
                begin
                    send_axi_stream_data(0, packets_per_channel, $sformatf("%s_CH0_ALL", test_name));
                    #500; // Delay before starting second channel
                    send_axi_stream_data(1, packets_per_channel, $sformatf("%s_CH1_ALL", test_name));
                end
            join
        end
        
        // Wait for any remaining master transactions
        #2000;
        test_passed++;
        
        $display("########## %s COMPLETED ##########", test_name);
    endtask

    // Random backpressure task for more realistic testing
    task automatic apply_random_backpressure(input int ready_percentage = 80);
        forever begin
            @(posedge clk);
            //m_axis_tready = ($urandom_range(0,100) < ready_percentage);
            m_axis_tready = 0;
        end
    endtask

    // Task to send single beat transactions with incremental data
    task automatic send_single_beat(input int channel, input logic [23:0] data);
        @(posedge clk);
        s_axis_tdata[channel] = data;
        s_axis_tvalid[channel] = 1'b1;
        s_axis_tlast[channel] = 1'b1; // Single beat packet
        
        while (!s_axis_tready[channel]) @(posedge clk);
        
        @(posedge clk);
        s_axis_tvalid[channel] = 1'b0;
        s_axis_tlast[channel] = 1'b0;
    endtask

    // Reset task
    task reset_dut();
        $display("=== Applying Reset ===");
        reset_n = 1'b0;
        s_axis_tdata = '0;
        s_axis_tvalid = '0;
        s_axis_tlast = '0;
        m_axis_tready = 1'b0;
        config_mode = 1'b0;
        
        // Reset data counters
        ch0_data_counter = 1;
        ch1_data_counter = 1;
        
        repeat(10) @(posedge clk);
        reset_n = 1'b1;
        repeat(5) @(posedge clk);
        $display("=== Reset Released ===");
    endtask

    //======================================================================
    // Main Test Sequence
    //======================================================================
    
    initial begin
        $dumpfile("stream_processor_tb.vcd");
        $dumpvars(0, tb_stream_processor);
        
        $display("########################################");
        $display("  Stream Processor Testbench Started  ");
        $display("########################################");
        
        // Initialize
        reset_dut();
        
        // Test 1: Non-interleaved mode with random backpressure
        fork
            apply_random_backpressure(75); // 75% ready
        join_none
        
        test_dual_channel_random(3, 1'b0, "TEST1_NON_INTERLEAVED");
        
        // Test 2: Interleaved mode with high backpressure
        disable fork; // Stop previous backpressure
        fork
            apply_random_backpressure(60); // 60% ready (more backpressure)
        join_none
        
        test_dual_channel_random(3, 1'b1, "TEST2_INTERLEAVED");
        
        // Test 3: Single beat packets
        disable fork;
        m_axis_tready = 1'b0;
        
        $display("\n########## TEST3_SINGLE_BEATS ##########");
        fork
            monitor_master_output("TEST3_SINGLE_BEATS");
        join_none
        
        for (int i = 0; i < 5; i++) begin
            send_single_beat(0, ch0_data_counter);
            ch0_data_counter++;
            #100;
            send_single_beat(1, ch1_data_counter);
            ch1_data_counter++;
            #100;
        end
        
        #1000;
        
        // Test 4: Stress test with no backpressure
        disable fork;
        m_axis_tready = 1'b1;
        test_dual_channel_random(5, 1'b0, "TEST4_STRESS_NON_INTERLEAVED");
        test_dual_channel_random(5, 1'b1, "TEST5_STRESS_INTERLEAVED");
        
        // Final results
        #1000;
        disable fork;
        
        $display("\n########################################");
        $display("           Test Summary                 ");
        $display("########################################");
        $display("Tests Passed: %0d", test_passed);
        $display("Test Errors:  %0d", test_errors);
        
        if (test_errors == 0) begin
            $display("*** ALL TESTS PASSED! ***");
        end else begin
            $display("*** SOME TESTS FAILED! ***");
        end
        
        $display("########################################");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("\n*** ERROR: Test timeout! ***");
        $finish;
    end

endmodule