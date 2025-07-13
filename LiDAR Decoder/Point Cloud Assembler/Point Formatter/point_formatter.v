// Sub-module: Point Formatter
module point_formatter (
    input  logic [31:0] x,
    input  logic [31:0] y,
    input  logic [31:0] z,
    input  logic [7:0]  R,
    input  logic [7:0]  G,
    input  logic [7:0]  B,
    input  logic [7:0]  intensity,
    input  logic        valid_in,
    output logic [127:0] point,
    output logic         valid_out
);
    // Combinational logic to format point
    assign point = {x, y, z, R, G, B, intensity}; // 32*3 + 8*4 = 128 bits
    assign valid_out = valid_in;

endmodule