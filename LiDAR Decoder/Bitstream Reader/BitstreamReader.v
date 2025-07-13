module BitstreamReader (
    input  logic        clk,
    input  logic        reset,
    input  logic        data_in_valid,   // Tín hiệu dữ liệu vào hợp lệ
    input  logic [511:0] compressed_data,
    output logic [511:0] encoded_data,
    output logic [9:0]   data_size,
    output logic [15:0]  point_count,
    output logic [127:0] metadata,
    output logic         data_valid,     // Dữ liệu đầu ra sẵn sàng
    output logic         crc_error,
    output logic         buffer_full     // Bộ đệm đầy
);
    // Tín hiệu nội bộ
    logic [511:0] temp_bitstream;
    logic [7:0]   version;
    logic [7:0]   header_length;
    logic         header_valid;
    logic         metadata_valid;
    logic         slice_valid;

    // BitstreamBuffer
    BitstreamBuffer buffer (
        .clk(clk),
        .reset(reset),
        .wr_en(data_in_valid && !buffer_full),
        .bitstream_in(compressed_data),
        .bitstream_out(temp_bitstream),
        .full(buffer_full)
    );

    // HeaderExtractor
    HeaderExtractor header (
        .bitstream(temp_bitstream),
        .version(version),
        .point_count(point_count),
        .header_length(header_length),
        .header_valid(header_valid)
    );

    // MetadataParser
    MetadataParser metadata_parser (
        .bitstream(temp_bitstream),
        .header_length(header_length),
        .metadata(metadata),
        .metadata_valid(metadata_valid)
    );

    // DataSlicer
    DataSlicer slicer (
        .bitstream(temp_bitstream),
        .header_length(header_length),
        .encoded_data(encoded_data),
        .data_size(data_size),
        .data_valid(slice_valid)
    );

    // CRCChecker
    CRCChecker crc (
        .bitstream(temp_bitstream),
        .crc_enable(header_valid),
        .crc_error(crc_error)
    );

    // Điều khiển đầu ra
    assign data_valid = header_valid && metadata_valid && slice_valid && !crc_error;
endmodule