typedef struct packed {
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] z;
} point_t;

// Optimized Geometry Decompressor with FSM for enable handling
module GeometryDecompressor (
    input  logic clock,
    input  logic reset,
    input  logic enable,
    input  logic [1:0] mode,
    input  logic signed [31:0] res_x,
    input  logic signed [31:0] res_y,
    input  logic signed [31:0] res_z,
    output logic signed [31:0] P_x,
    output logic signed [31:0] P_y,
    output logic signed [31:0] P_z
);
    typedef enum logic { IDLE = 1'b0, PROCESS = 1'b1 } state_t;
    state_t state;

    point_t P_prev1, P_prev2;
    point_t pred, res, P_current;

    // Assign residuals directly
    assign res = '{res_x, res_y, res_z};

    // Instantiate sub-modules
    PointPredictor predictor (
        .mode(mode),
        .P_prev1(P_prev1),
        .P_prev2(P_prev2),
        .pred(pred)
    );

    AdderUnit adder (
        .pred(pred),
        .res(res),
        .P(P_current)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            state <= IDLE;
            P_prev1 <= '{0, 0, 0};
            P_prev2 <= '{0, 0, 0};
            {P_x, P_y, P_z} <= '{0, 0, 0};
        end else begin
            unique case (state)
                IDLE: 
                    if (enable) state <= PROCESS;
                
                PROCESS: begin
                    P_prev2 <= P_prev1;
                    P_prev1 <= P_current;
                    {P_x, P_y, P_z} <= {P_current.x, P_current.y, P_current.z};
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule