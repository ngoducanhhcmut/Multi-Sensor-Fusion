// ==========================================================
// Timestamp Extractor
// ==========================================================
module timestamp_extractor #(
    parameter DATA_WIDTH = 512
)(
    input [DATA_WIDTH+63:0] data_in,
    output logic [63:0] timestamp,
    output logic [DATA_WIDTH-1:0] sensor_data
);
    assign timestamp = data_in[DATA_WIDTH +: 64];
    assign sensor_data = data_in[0 +: DATA_WIDTH];
endmodule