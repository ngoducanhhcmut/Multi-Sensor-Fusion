module DataSlicer (
    input  logic [511:0] bitstream,
    input  logic [7:0]   header_length,
    output logic [511:0] encoded_data, // Hỗ trợ tối đa 512-bit
    output logic [9:0]   data_size,    // Kích thước dữ liệu (bit)
    output logic         data_valid
);
    always_comb begin
        data_valid = 1'b0;
        encoded_data = 512'b0;
        data_size = 10'b0;
        if (header_length > 0 && header_length < 384) begin
            int data_start = header_length;
            int data_end = 512 - 128; // Trừ metadata
            if (data_start < data_end) begin
                data_size = data_end - data_start;
                encoded_data[0 +: data_size] = bitstream[data_start +: data_size];
                data_valid = 1'b1;
            end
        end
    end
endmodule