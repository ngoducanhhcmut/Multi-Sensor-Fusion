module Sensor_Preprocessor #(
    parameter MIN_VAL = -16384,
    parameter MAX_VAL = 16383
) (
    input  wire [255:0] raw_vector,
    output wire [255:0] normalized_vector,
    output wire [15:0]  error_flags  // Thêm cờ báo lỗi
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : clip_loop
            wire signed [15:0] element = raw_vector[16*i + 15 : 16*i];
            wire signed [15:0] clipped_element;
            wire               out_of_range;
            
            assign out_of_range = (element < MIN_VAL) || (element > MAX_VAL);
            assign clipped_element = (element < MIN_VAL) ? MIN_VAL :
                                     (element > MAX_VAL) ? MAX_VAL :
                                     element;
            assign normalized_vector[16*i + 15 : 16*i] = clipped_element;
            assign error_flags[i] = out_of_range;  // Báo lỗi cho Fault Monitor
        end
    endgenerate
endmodule