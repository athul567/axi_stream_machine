package all_pkg;

typedef enum logic [3:0] {
    MUX_BUFFER_1 = 4'd0,
    MUX_BUFFER_1_IDLE = 4'd1,
    MUX_BUFFER_2 = 4'd2,
    MUX_BUFFER_2_IDLE = 4'd3,
    MUX_BUFFER_3 = 4'd4,
    MUX_BUFFER_3_IDLE = 4'd5,
    IDLE    = 4'd6
} mux_st;

typedef enum logic [3:0] {
    STATE_0  = 4'd1,
    STATE_1  = 4'd2,
    STATE_2  = 4'd3,
    STATE_3  = 4'd4,
    STATE_4  = 4'd5,
    STATE_5  = 4'd6,
    STATE_6  = 4'd7,
    STATE_7  = 4'd8
} S_mux_sel_t;

typedef enum logic [2:0] {
    STATE_IDLE,
    READ_FIFO,NON_INTER_MODE,INTER_MODE_CH1
} state_t;


function string mux_state_to_string(mux_st state);
    case (state)
        MUX_BUFFER_1: return "MUX_BUFFER_1";
        MUX_BUFFER_2: return "MUX_BUFFER_2";
        MUX_BUFFER_3: return "MUX_BUFFER_3";
        IDLE:         return "IDLE";
        default:      return "UNKNOWN";
    endcase
endfunction




endpackage