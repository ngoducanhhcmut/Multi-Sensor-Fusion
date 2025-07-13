// Optimized Slice Data Extractor Module
module slice_data_extractor (
    input  logic [3071:0]    nal_unit,     // Input NAL unit (slice RBSP)
    input  logic [11:0]      bit_pos,      // Position after header
    input  logic             valid_in,     // Valid signal from header parser
    output logic [3071:0]    slice_data,   // Encoded slice data
    output logic             valid_out     // Data extracted successfully
);

    // Use shift operation instead of part-select for better resource utilization
    always_comb begin
        slice_data = '0;
        valid_out = 0;
        
        if (valid_in) begin
            if (bit_pos < 3072) begin
                // Shift out processed header bits
                slice_data = nal_unit >> bit_pos;
                valid_out = 1;
            end
        end
    end

endmodule