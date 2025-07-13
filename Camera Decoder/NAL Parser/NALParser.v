// Top-level NAL Parser with Error Handling
module NALParser (
    input  logic         clk,
    input  logic         reset,
    input  logic [7:0]   bitstream_data,    // H.265 bitstream input
    input  logic         bitstream_valid,   // Valid signal for input
    output logic [7:0]   nal_type,          // Type of extracted NAL unit
    output logic [3071:0] nal_unit,         // Extracted NAL unit data
    output logic [9:0]   nal_unit_size,     // Size of valid data in NAL unit
    output logic         nal_valid,         // Valid signal for NAL unit
    output logic         error_overflow     // Buffer overflow error
);

    logic [3071:0] chunk_data;
    logic chunk_valid;
    logic chunk_overflow;
    logic nal_start;
    logic nal_end;
    logic [3071:0] nal_payload;
    logic [9:0] nal_payload_size;
    logic int_error_overflow;

    BitstreamReader reader (
        .clk(clk),
        .reset(reset),
        .bitstream_data(bitstream_data),
        .bitstream_valid(bitstream_valid),
        .chunk_data(chunk_data),
        .chunk_valid(chunk_valid),
        .chunk_overflow(chunk_overflow)
    );
    
    NALUnitDetector detector (
        .clk(clk),
        .reset(reset),
        .chunk_data(chunk_data),
        .chunk_valid(chunk_valid),
        .nal_start(nal_start),
        .nal_end(nal_end),
        .nal_payload(nal_payload),
        .nal_payload_size(nal_payload_size)
    );
    
    NALUnitExtractor extractor (
        .clk(clk),
        .reset(reset),
        .nal_start(nal_start),
        .nal_end(nal_end),
        .nal_payload(nal_payload),
        .nal_payload_size(nal_payload_size),
        .nal_type(nal_type),
        .nal_unit(nal_unit),
        .nal_unit_size(nal_unit_size),
        .nal_valid(nal_valid)
    );
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            int_error_overflow <= 1'b0;
            error_overflow <= 1'b0;
        end else begin
            if (chunk_overflow) begin
                int_error_overflow <= 1'b1;
            end
            error_overflow <= int_error_overflow;
        end
    end
endmodule