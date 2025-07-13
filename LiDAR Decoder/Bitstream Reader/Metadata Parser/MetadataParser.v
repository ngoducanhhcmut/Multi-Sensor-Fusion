module MetadataParser (
    input  logic [511:0] bitstream,
    input  logic [7:0]   header_length, // Từ HeaderExtractor (bit)
    output logic [127:0] metadata,      // 128-bit metadata
    output logic         metadata_valid
);
    always_comb begin
        metadata_valid = 1'b0;
        metadata = 128'b0;
        if (header_length > 0 && header_length < 384) begin // Đảm bảo đủ chỗ cho metadata
            int metadata_start = 512 - 128; // Metadata nằm ở cuối
            metadata = bitstream[metadata_start +: 128];
            metadata_valid = 1'b1;
        end
    end
endmodule