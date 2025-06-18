module sync_fifo #(
  parameter WIDTH = 24,
    parameter DEPTH = 256
)(
    input  logic clk,
    input  logic reset,

    // Write interface
    input  logic [WIDTH-1:0]  din,
    input  logic              wr_en,
    output logic              full,

    // Read interface
    input  logic              rd_en,
    output logic [WIDTH-1:0]  dout,
    output logic              valid,
    output logic              empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Internal memory and control
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [ADDR_WIDTH:0]   count;

    // Write logic
    always_ff @(posedge clk) begin
        if (reset) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read logic
    always_ff @(posedge clk) begin
        if (reset) begin
            rd_ptr <= 0;
        end else if (rd_en && valid) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

    // Count management
    always_ff @(posedge clk) begin
        if (reset) begin
            count <= 0;
        end else begin
            case ({wr_en && !full, rd_en && valid})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

    // Output and status
    assign dout  = mem[rd_ptr];
    assign valid = (count > 0);
    assign empty = (count == 0);
    assign full  = (count == DEPTH);

endmodule