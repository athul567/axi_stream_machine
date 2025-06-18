module stream_processor_tb;
    logic clk = 0, reset_n = 0;
    always #5 clk = ~clk;
    
    // AXI4-Stream interface
    logic [1:0][23:0] s_axis_tdata;
    logic [1:0]       s_axis_tvalid, s_axis_tlast;
    logic [1:0]       s_axis_tready;
    logic [63:0]      m_axis_tdata;
    logic             m_axis_tvalid, m_axis_tlast;
    logic             m_axis_tready = 0;
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
    
    // Byte counters per channel
    int byte_idx [1:0] = '{-3, -3};  // Start before first group
    int base_char [1:0] = '{8'hA0, 8'hA0};  // Base characters for ch0, ch1
    
	integer backpressure_count = 0;
	
	always @(posedge clk) begin

			m_axis_tready <= 1;
        //#5000;                   // Wait for completion

        //#5000; //                  // Wait for completion
		//	m_axis_tready <= 1;

        //#1000;                   // Wait for completion
		if (backpressure_count > 0) begin
			m_axis_tready <= 0;
			backpressure_count--;
		end else if ($urandom_range(0, 10) < 2) begin
			backpressure_count <= $urandom_range(1, 5);
			m_axis_tready <= 0;
		end else begin
			m_axis_tready <= 1;
		end
	end

    // === Task: Send packet ===
    task automatic send_packet(input int ch, input int beats, input int delay_cycles = 0);
        fork
            begin
                logic [7:0] b0, b1, b2;
                
                // Initial delay
                if (delay_cycles > 0) repeat (delay_cycles) @(posedge clk);
                
                for (int i = 0; i < beats; i++) begin
                    // Prepare data for this beat
                    byte_idx[ch] += 3;
                    b0 = base_char[ch] + byte_idx[ch] + 0;
                    b1 = base_char[ch] + byte_idx[ch] + 1;
                    b2 = base_char[ch] + byte_idx[ch] + 2;
                    
                    // Wait for clock edge, then drive signals
                    @(posedge clk);
                    s_axis_tdata[ch]  = {b2, b1, b0};
                    s_axis_tvalid[ch] = 1;
                    s_axis_tlast[ch]  = (i == beats - 1);
                    
                    // Wait for handshake completion (both valid and ready high)
                    do begin
                        @(posedge clk);
                    end while (!(s_axis_tvalid[ch] && s_axis_tready[ch]));
                    
                    $display("CH%0d SENT BEAT %0d/%0d: DATA=%h, LAST=%b", 
                             ch, i+1, beats, s_axis_tdata[ch], s_axis_tlast[ch]);
                    
                    // Deassert valid and last after successful handshake
                    s_axis_tvalid[ch] = 0;
                    s_axis_tlast[ch]  = 0;
                    
                    // Optional: Add some idle cycles between beats
                    if (i < beats - 1) begin
                        repeat ($urandom_range(0, 2)) @(posedge clk); // 0-2 idle cycles
                    end
                end
                $display("CH%0d PACKET COMPLETE (%0d beats, %0d bytes)", ch, beats, beats*3);
            end
        join_none
    endtask
    
    // Task to monitor output
    task automatic monitor_output();
        fork
            begin
                forever begin
                    @(posedge clk);
                    if (m_axis_tvalid && m_axis_tready) begin
                        $display("                                             OUTPUT: DATA=%h, LAST=%b", m_axis_tdata, m_axis_tlast);
                    end
                end
            end
        join_none
    endtask
    
    // Task to randomly control m_axis_tready
    task automatic random_backpressure();
        fork
            begin
                forever begin
                    @(posedge clk);
                    // Randomly assert/deassert ready (80% ready, 20% not ready)
                    m_axis_tready = ($urandom_range(1, 100) <= 80);
                end
            end
        join_none
    endtask
    
    // === Main Test Sequence ===
    initial begin
        // Initialize all signals
        s_axis_tvalid = '{default:0};
        s_axis_tlast  = '{default:0};
        s_axis_tdata  = '{default:24'h0};
        config_mode   = 1;
        
        // Reset sequence
        reset_n = 0;
        repeat (5) @(posedge clk);
        reset_n = 1;
        repeat (3) @(posedge clk);
        
        // Start monitoring
        monitor_output();
        
        $display("\n=== Starting AXI4-Stream Tests ===");
        
        // === Test 1: Non-Interleaved Mode ===
        $display("\n=== Test 1: Non-Interleaved Mode ===");
        config_mode = 1;
        @(posedge clk);
        
        // Send packets sequentially
fork
    send_packet(0, 17, 0);
    send_packet(1, 17, 0);
join

        #1000;                   // Wait for completion

        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)
// contine


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)

        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)

        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)

        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)

        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 17, 0);    // Channel 0: 6 beats (18 bytes)
        #20;                   // Wait for completion
        send_packet(1, 17, 0);    // Channel 1: 4 beats (12 bytes)
        #20;
        send_packet(0, 17, 0);    // Channel 0: 2 beats (6 bytes)
        #20;
        send_packet(1, 17, 0);    // Channel 1: 3 beats (9 bytes)

//contine

        send_packet(0, 6, 5);    // Channel 0: 6 beats (18 bytes)
        #100;                   // Wait for completion
        send_packet(1, 4, 5);    // Channel 1: 4 beats (12 bytes)
        #100;
        send_packet(0, 2, 5);    // Channel 0: 2 beats (6 bytes)
        #100;
        send_packet(1, 3, 5);    // Channel 1: 3 beats (9 bytes)


        #100;
        // Send packets sequentially
        send_packet(0, 6, 5);    // Channel 0: 6 beats (18 bytes)
        #100;                   // Wait for completion
        send_packet(1, 4, 5);    // Channel 1: 4 beats (12 bytes)
        #100;
        send_packet(0, 2, 5);    // Channel 0: 2 beats (6 bytes)
        #100;
        send_packet(1, 3, 5);    // Channel 1: 3 beats (9 bytes)


        send_packet(0, 6, 5);    // Channel 0: 6 beats (18 bytes)
        #100;                   // Wait for completion
        send_packet(1, 4, 5);    // Channel 1: 4 beats (12 bytes)
        #100;
        send_packet(0, 2, 5);    // Channel 0: 2 beats (6 bytes)
        #100;
        send_packet(1, 3, 5);    // Channel 1: 3 beats (9 bytes)
        
        // Wait for all transactions to complete
        repeat (50) @(posedge clk);
        
        // === Test 2: Interleaved Mode ===
        $display("\n=== Test 2: Interleaved Mode ===");
        config_mode = 1;  // Enable interleaved mode
        @(posedge clk);
        
        // Send packets simultaneously (interleaved)
        send_packet(0, 4, 0);    // Channel 0: 4 beats (12 bytes)
        send_packet(1, 4, 0);    // Channel 1: 4 beats (12 bytes)
        
        repeat (100) @(posedge clk);
        
        // === Test 3: Different packet sizes ===
        $display("\n=== Test 3: Size Mismatch Test ===");
        config_mode = 1;
        @(posedge clk);
        
        // Send packets with different sizes to test mismatch detection
        send_packet(0, 3, 0);    // Channel 0: 3 beats (9 bytes)
        send_packet(1, 5, 0);    // Channel 1: 5 beats (15 bytes) - size mismatch
        
        repeat (80) @(posedge clk);
        
        // === Test 4: Backpressure Test ===
        $display("\n=== Test 4: Backpressure Test ===");
        config_mode = 0;
        random_backpressure();   // Enable random backpressure
        
        send_packet(0, 3, 0);
        send_packet(1, 3, 10);
        
        repeat (100) @(posedge clk);
        
        // Check status
        if (status_packets_size_mismatch) begin
            $display("⚠️  Status: Packet size mismatch detected");
        end else begin
            $display("✅ Status: No packet size mismatch");
        end
        
        $display("\n✅ All tests completed successfully!");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50000; // 50us timeout
        $display("❌ ERROR: Simulation timeout!");
        $finish;
    end
    
endmodule