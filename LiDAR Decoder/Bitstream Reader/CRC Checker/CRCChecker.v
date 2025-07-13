module CRCChecker (
    input  logic [511:0] bitstream,
    input  logic         crc_enable,   // Cho phép kiểm tra CRC
    output logic         crc_error
);
    logic [31:0] calculated_crc;
    logic [31:0] crc_table [0:255]; // Bảng tra cứu CRC-32

    initial begin
        for (int i = 0; i < 256; i++) crc_table[i] = 32'h0; // Giả lập, cần triển khai thực tế
    end

    always_comb begin
        calculated_crc = 32'hFFFFFFFF;
        if (crc_enable) begin
            for (int i = 0; i < 64; i++) begin
                logic [7:0] data_byte = bitstream[i*8 +: 8];
                calculated_crc = crc_table[(calculated_crc ^ data_byte) & 8'hFF] ^ (calculated_crc >> 8);
            end
            crc_error = (calculated_crc != 32'h0); // Giả định CRC appended là 0
        end else begin
            crc_error = 1'b0;
        end
    end
endmodule