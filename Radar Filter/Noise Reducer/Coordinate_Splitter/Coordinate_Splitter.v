module Coordinate_Splitter (
    input  logic [127:0] window_in [0:4],
    output logic [31:0]  X [0:4],
    output logic [31:0]  Y [0:4],
    output logic [31:0]  Z [0:4]
);

    // Bit [127:96] (W) không được sử dụng
    for (genvar i = 0; i < 5; i++) begin
        assign X[i] = window_in[i][31:0];    // X: bits [31:0]
        assign Y[i] = window_in[i][63:32];   // Y: bits [63:32]
        assign Z[i] = window_in[i][95:64];   // Z: bits [95:64]
    end
endmodule