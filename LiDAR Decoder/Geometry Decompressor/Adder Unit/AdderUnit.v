typedef struct packed {
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] z;
} point_t;

// Adder with saturation to prevent overflow
module AdderUnit (
    input  point_t pred,
    input  point_t res,
    output point_t P
);
    localparam MAX_VAL = (1 << 31) - 1;  // 2^31 - 1
    localparam MIN_VAL = - (1 << 31);    // -2^31
    
    function automatic logic signed [31:0] sat_add(
        input logic signed [31:0] a,
        input logic signed [31:0] b
    );
        logic signed [32:0] sum = a + b; // Extra bit to detect overflow
        if (sum > MAX_VAL) return MAX_VAL;
        else if (sum < MIN_VAL) return MIN_VAL;
        else return sum[31:0];
    endfunction

    assign P.x = sat_add(pred.x, res.x);
    assign P.y = sat_add(pred.y, res.y);
    assign P.z = sat_add(pred.z, res.z);
endmodule