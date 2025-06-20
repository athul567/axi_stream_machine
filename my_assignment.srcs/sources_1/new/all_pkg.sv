package all_pkg;

typedef enum logic [3:0] {
    MUX_BUFFER_1 = 4'd0,
    MUX_BUFFER_2 = 4'd1,
    MUX_BUFFER_3 = 4'd2,
    IDLE    = 4'd3
} mux_st;

typedef enum logic [3:0] {
    STATE_0  = 4'd1,
    STATE_1  = 4'd2,
    STATE_2  = 4'd3,
    STATE_3  = 4'd4,
    STATE_4  = 4'd5,
    STATE_BUFFER_0 = 4'd6,
    STATE_BUFFER_1 = 4'd7,
    STATE_BUFFER_2 = 4'd8,
    DATA_TRANSFER = 4'd9
} S_mux_sel_t;

endpackage