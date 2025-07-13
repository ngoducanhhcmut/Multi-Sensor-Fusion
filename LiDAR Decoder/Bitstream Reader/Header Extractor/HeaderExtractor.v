module HeaderExtractor (
    input  logic [511:0] bitstream,
    output logic [7:0]   version,
    output logic [15:0]  point_count,
    output logic [7:0]   header_length, // Độ dài header (bit)
    output logic         header_valid
);
    always_comb begin
        version = bitstream[511:504];
        header_valid = (version >= 8'h01) && (version <= 8'h0F); // Phạm vi version hợp lệ
        if (version == 8'h01) begin
            point_count = bitstream[503:488];
            header_length = 24; // 3 bytes
        end else if (version == 8'h02) begin
            point_count = bitstream[503:480];
            header_length = 32; // 4 bytes
        end else begin
            point_count = '0;
            header_length = '0;
        end
    end
endmodule