module axis_fifo #(
    parameter WIDTH = 24,
    parameter DEPTH = 256
)(
    input  logic clk,
    input  logic reset,

    // Write interface
    input  logic              wr_en,
    input  logic [WIDTH-1:0]  din,
    output logic              full,

    // Read interface
    input  logic              rd_en,
    output logic [WIDTH-1:0]  dout,
    output logic              valid,
    output logic              empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr = 0;
    logic [ADDR_WIDTH-1:0] rd_ptr = 0;
    logic [ADDR_WIDTH:0]   count = 0;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    assign valid = !empty;
    assign dout  = mem[rd_ptr];

    always_ff @(posedge clk) begin
        if (reset) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1;
                count <= count + 1;
            end
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
                count <= count - 1;
            end
        end
    end

endmodule
