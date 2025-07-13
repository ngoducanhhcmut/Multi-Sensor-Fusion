typedef struct packed {
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] z;
} point_t;

// Point Predictor with overflow prevention
module PointPredictor (
    input  logic [1:0] mode,
    input  point_t P_prev1,
    input  point_t P_prev2,
    output point_t pred
);
    always_comb begin
        case (mode)
            2'b00: pred = P_prev1;  // Predict previous point
            2'b01: begin            // Linear extrapolation
                // Use temporary variables to prevent overflow
                logic signed [31:0] temp_x = P_prev1.x * 2;
                logic signed [31:0] temp_y = P_prev1.y * 2;
                logic signed [31:0] temp_z = P_prev1.z * 2;
                pred.x = temp_x - P_prev2.x;
                pred.y = temp_y - P_prev2.y;
                pred.z = temp_z - P_prev2.z;
            end
            default: pred = '{0, 0, 0}; // Handle invalid mode
        endcase
    end
endmodule