// Internal signals
logic [7:0] buffer_1 [0:11];
logic [7:0] buffer_2 [0:11];
logic [3:0] write_ptr_a, write_ptr_b;
logic [2:0] ptr0_a, ptr1_a, ptr2_a;
logic [2:0] ptr0_b, ptr1_b, ptr2_b;

// Reset and update logic
always_ff @(posedge clk or posedge reset) begin
  if (reset) begin
    write_ptr_a <= 0;
    write_ptr_b <= 0;
    for (int i = 0; i < 8; i++) begin
      buffer_1[i] <= 8'd0;
      buffer_2[i] <= 8'd0;
    end
  end else if (valid) begin

    ptr0_a = write_ptr_a & 3'b111;
    ptr1_a = (write_ptr_a + 1) & 3'b111;
    ptr2_a = (write_ptr_a + 2) & 3'b111;

    ptr0_b = write_ptr_b & 3'b111;
    ptr1_b = (write_ptr_b + 1) & 3'b111;
    ptr2_b = (write_ptr_b + 2) & 3'b111;

    if (write_ptr_b > 7) begin
      write_ptr_b <= (write_ptr_b + 3) & 4'hF;

      if (write_ptr_b == 8) begin
        buffer_1[8] <= input_3B[23:16];
        write_ptr_a <= (write_ptr_a + 1) & 4'hF;
        write_ptr_b <= 0;
      end else if (write_ptr_b == 9) begin
        buffer_1[9] <= input_3B[23:16];
        buffer_1[8] <= input_3B[15:8];
        write_ptr_a <= (write_ptr_a + 2) & 4'hF;
        write_ptr_b <= 0;
      end else if (write_ptr_b == 10) begin
        buffer_1[10] <= input_3B[23:16];
        buffer_1[9]  <= input_3B[15:8];
        buffer_1[8]  <= input_3B[7:0];
        write_ptr_a <= (write_ptr_a + 3) & 4'hF;
        write_ptr_b <= 0;
      end

    end else if (write_ptr_b < 7 && write_ptr_b != 0) begin
      write_ptr_b <= (write_ptr_b + 3) & 4'hF;
      buffer_2[ptr0_b] <= input_3B[23:16];
      buffer_2[ptr1_b] <= input_3B[15:8];
      buffer_2[ptr2_b] <= input_3B[7:0];

    end else if (write_ptr_a > 7) begin
      write_ptr_a <= (write_ptr_a + 3) & 4'hF;

      if (write_ptr_a == 8) begin
        buffer_2[8] <= input_3B[23:16];
        write_ptr_b <= (write_ptr_b + 1) & 4'hF;
        write_ptr_a <= 0;
      end else if (write_ptr_a == 9) begin
        buffer_2[10] <= input_3B[23:16];
        buffer_2[9]  <= input_3B[15:8];
        write_ptr_a <= 0;
        write_ptr_b <= (write_ptr_b + 2) & 4'hF;
      end else if (write_ptr_a == 10) begin
        buffer_2[11] <= input_3B[23:16];
        buffer_2[10] <= input_3B[15:8];
        buffer_2[9]  <= input_3B[7:0];
        write_ptr_a <= 0;
        write_ptr_b <= (write_ptr_b + 3) & 4'hF;
      end

    end else begin
      buffer_1[ptr0_a] <= input_3B[23:16];
      buffer_1[ptr1_a] <= input_3B[15:8];
      buffer_1[ptr2_a] <= input_3B[7:0];
      write_ptr_a <= (write_ptr_a + 3) & 4'hF;
    end



  end
end
