// Module: Attribute Combiner
module AttributeCombiner #(
    parameter ATTR_WIDTH = 8
)(
    input  logic [ATTR_WIDTH-1:0]         predicted_attribute,
    input  logic signed [ATTR_WIDTH-1:0]  residual,
    output logic [ATTR_WIDTH-1:0]         final_attribute,
    output logic                          overflow_flag
);
    logic signed [ATTR_WIDTH:0] temp; // Thêm 1 bit để phát hiện tràn

    always_comb begin
        temp = $signed({1'b0, predicted_attribute}) + residual;
        overflow_flag = (temp > 2**ATTR_WIDTH-1) || (temp < 0);
        
        if (temp < 0) begin
            final_attribute = 0;
        end else if (temp > 2**ATTR_WIDTH-1) begin
            final_attribute = 2**ATTR_WIDTH-1;
        end else begin
            final_attribute = temp[ATTR_WIDTH-1:0];
        end
    end
endmodule


// Module: Attribute Predictor
module AttributePredictor #(
    parameter ATTR_WIDTH = 8,
    parameter K = 4,
    parameter MODE_WIDTH = 3
)(
    input  logic [MODE_WIDTH-1:0] prediction_mode,
    input  logic [ATTR_WIDTH-1:0] neighboring_attributes [K-1:0],
    output logic [ATTR_WIDTH-1:0] predicted_attribute
);
    logic [ATTR_WIDTH + $clog2(K):0] sum; // Tự động tính bit cần thiết

    always_comb begin
        predicted_attribute = 0;
        if (prediction_mode < K) begin
            predicted_attribute = neighboring_attributes[prediction_mode];
        end
        else if (prediction_mode == K && K > 0) begin
            sum = 0;
            for (int i = 0; i < K; i++) begin
                sum += neighboring_attributes[i];
            end
            predicted_attribute = sum / K;
        end
    end
endmodule

// Module: Attribute Residual Extractor
module AttributeResidualExtractor #(
    parameter SYMBOL_WIDTH = 8,
    parameter ATTR_WIDTH = 8
)(
    input  logic [SYMBOL_WIDTH-1:0] residual_symbol,
    output logic signed [ATTR_WIDTH-1:0] residual
);
    always_comb begin
        if (SYMBOL_WIDTH >= ATTR_WIDTH) begin
            residual = residual_symbol[ATTR_WIDTH-1:0];
        end else begin
            residual = {{(ATTR_WIDTH-SYMBOL_WIDTH){residual_symbol[SYMBOL_WIDTH-1]}}, 
                       residual_symbol};
        end
    end
endmodule

module AttributeDecompressor #(
    parameter ATTR_WIDTH = 8,
    parameter K = 4,
    parameter MODE_WIDTH = 3,
    parameter SYMBOL_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [SYMBOL_WIDTH-1:0] decoded_symbols [1:0],
    input  logic [ATTR_WIDTH-1:0]   neighboring_attributes [K-1:0],
    output logic [ATTR_WIDTH-1:0]   final_attribute,
    output logic                    error_flag
);
    // Tín hiệu nội bộ
    logic [MODE_WIDTH-1:0]        prediction_mode;
    logic [SYMBOL_WIDTH-1:0]      residual_symbol;
    logic [ATTR_WIDTH-1:0]        predicted_attribute;
    logic signed [ATTR_WIDTH-1:0] residual;
    logic                         predictor_error;
    logic                         overflow_flag;

    // Phân tích input
    assign prediction_mode = decoded_symbols[0][MODE_WIDTH-1:0];
    assign residual_symbol = decoded_symbols[1];

    // Kiểm tra lỗi mode
    assign predictor_error = (prediction_mode > K);

    // Khối con
    AttributePredictor #(
        .ATTR_WIDTH(ATTR_WIDTH),
        .K(K),
        .MODE_WIDTH(MODE_WIDTH)
    ) predictor (
        .prediction_mode(prediction_mode),
        .neighboring_attributes(neighboring_attributes),
        .predicted_attribute(predicted_attribute)
    );

    AttributeResidualExtractor #(
        .SYMBOL_WIDTH(SYMBOL_WIDTH),
        .ATTR_WIDTH(ATTR_WIDTH)
    ) extractor (
        .residual_symbol(residual_symbol),
        .residual(residual)
    );

    AttributeCombiner #(
        .ATTR_WIDTH(ATTR_WIDTH)
    ) combiner (
        .predicted_attribute(predicted_attribute),
        .residual(residual),
        .final_attribute(final_attribute),
        .overflow_flag(overflow_flag)
    );

    // Tổng hợp lỗi
    assign error_flag = predictor_error || overflow_flag;

    // Pipeline register (tùy chọn)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_attribute <= 0;
        end else begin
            final_attribute <= combiner.final_attribute;
        end
    end
endmodule

module BitstreamBuffer (
    input  logic        clk,
    input  logic        reset,
    input  logic        wr_en,        // Tín hiệu ghi dữ liệu
    input  logic [511:0] bitstream_in,
    output logic [511:0] bitstream_out,
    output logic        full          // Báo hiệu bộ đệm đầy
);
    logic [511:0] buffer_reg;
    logic buffer_valid;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            buffer_reg <= 512'b0;
            buffer_valid <= 1'b0;
        end else if (wr_en && !full) begin
            buffer_reg <= bitstream_in;
            buffer_valid <= 1'b1;
        end
    end

    assign bitstream_out = buffer_valid ? buffer_reg : 512'b0;
    assign full = buffer_valid; // Bộ đệm đầy khi dữ liệu hợp lệ
endmodule

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

module ContextUpdater (
    input wire clk,
    input wire reset,
    input wire update_en,
    input wire [15:0] decoded_symbol,
    input wire [15:0] current_context,
    output reg [15:0] new_context,
    output reg context_valid
);
    // Bảng ngữ cảnh: ánh xạ biểu tượng giải mã và ngữ cảnh hiện tại
    reg [15:0] context_table [0:255][0:255];

    // Khởi tạo bảng ngữ cảnh
    initial begin
        $readmemh("context_table.mem", context_table);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            new_context <= 16'h0000;
            context_valid <= 1'b0;
        end
        else if (update_en) begin
            if (decoded_symbol[7:0] < 256 && current_context[7:0] < 256) begin
                new_context <= context_table[decoded_symbol[7:0]][current_context[7:0]];
                context_valid <= 1'b1;
            end
            else begin
                new_context <= current_context; // Giữ nguyên nếu không hợp lệ
                context_valid <= 1'b0;
            end
        end
        else begin
            context_valid <= 1'b0;
        end
    end
endmodule

module ProbabilityLookup (
    input wire clk,
    input wire reset,
    input wire [7:0] encoded_data,
    output reg [15:0] symbol_prob,
    output reg prob_valid
);
    reg [15:0] probability_table [0:255];

    initial begin
        integer i;
        for (i = 0; i < 256; i = i + 1) begin
            probability_table[i] = 16'h1000 + i * 16'h0100;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            symbol_prob <= 16'h0000;
            prob_valid <= 1'b0;
        end
        else begin
            symbol_prob <= probability_table[encoded_data];
            prob_valid <= 1'b1;
        end
    end
endmodule

module RangeInitializer (
    input wire clk,
    input wire reset,
    input wire init_pulse,
    output reg [15:0] range_initial
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            range_initial <= 16'hFFFF;
        else if (init_pulse)
            range_initial <= 16'hFFFF;
    end
endmodule

module RangeNormalizer (
    input wire clk,
    input wire reset,
    input wire normalize_en,
    input wire [15:0] range_updated,
    input wire [15:0] bitstream,
    output reg [15:0] range_normalized,
    output reg [15:0] new_bitstream,
    output reg underflow_flag
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            range_normalized <= 16'h0000;
            new_bitstream <= 16'h0000;
            underflow_flag <= 1'b0;
        end
        else if (normalize_en) begin
            if (range_updated == 16'h0000) begin
                range_normalized <= 16'h0000;
                underflow_flag <= 1'b1;
            end
            else if (range_updated < 16'h8000) begin
                range_normalized <= range_updated << 1;
                new_bitstream <= bitstream >> 1;
                underflow_flag <= (bitstream == 16'h0000);
            end
            else begin
                range_normalized <= range_updated;
                new_bitstream <= bitstream;
                underflow_flag <= 1'b0;
            end
        end
    end
endmodule


module RangeUpdater (
    input wire clk,
    input wire reset,
    input wire update_en,
    input wire [15:0] range_current,
    input wire [15:0] cum_prob,
    input wire [15:0] total_prob,
    output reg [15:0] range_updated,
    output reg overflow_flag
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            range_updated <= 16'h0000;
            overflow_flag <= 1'b0;
        end
        else if (update_en) begin
            if (total_prob == 16'h0000 || cum_prob >= total_prob) begin
                range_updated <= range_current;
                overflow_flag <= 1'b1;
            end
            else begin
                range_updated <= (range_current * cum_prob) / total_prob;
                overflow_flag <= 1'b0;
            end
        end
    end
endmodule


module RangeCalculator (
    input wire clk,
    input wire reset,
    input wire init_pulse,
    input wire update_en,
    input wire normalize_en,
    input wire [7:0] encoded_data,
    input wire [15:0] bitstream,
    output reg [15:0] decoded_range,
    output reg error_flag
);
    wire [15:0] range_initial;
    wire [15:0] symbol_prob;
    wire prob_valid;
    wire [15:0] range_updated;
    wire overflow_flag;
    wire [15:0] range_normalized;
    wire [15:0] new_bitstream;
    wire underflow_flag;

    RangeInitializer u_range_init (
        .clk(clk),
        .reset(reset),
        .init_pulse(init_pulse),
        .range_initial(range_initial)
    );

    ProbabilityLookup u_prob_lookup (
        .clk(clk),
        .reset(reset),
        .encoded_data(encoded_data),
        .symbol_prob(symbol_prob),
        .prob_valid(prob_valid)
    );

    RangeUpdater u_range_update (
        .clk(clk),
        .reset(reset),
        .update_en(update_en),
        .range_current(range_initial),
        .cum_prob(symbol_prob),
        .total_prob(16'hFFFF),
        .range_updated(range_updated),
        .overflow_flag(overflow_flag)
    );

    RangeNormalizer u_range_norm (
        .clk(clk),
        .reset(reset),
        .normalize_en(normalize_en),
        .range_updated(range_updated),
        .bitstream(bitstream),
        .range_normalized(range_normalized),
        .new_bitstream(new_bitstream),
        .underflow_flag(underflow_flag)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_range <= 16'h0000;
            error_flag <= 1'b0;
        end
        else if (normalize_en) begin
            if (!prob_valid || overflow_flag || underflow

_flag) begin
                decoded_range <= 16'h0000;
                error_flag <= 1'b1;
            end
            else begin
                decoded_range <= range_normalized;
                error_flag <= 1'b0;
            end
        end
    end
endmodule

module SymbolDecoder (
    input wire clk,
    input wire reset,
    input wire decode_en,
    input wire [7:0] symbol_code,
    output reg [15:0] decoded_symbol,
    output reg decode_valid
);
    reg [15:0] decode_table [0:255];

    initial begin
        $readmemh("decode_table.mem", decode_table);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_symbol <= 0;
            decode_valid <= 0;
        end
        else if (decode_en) begin
            decoded_symbol <= decode_table[symbol_code];
            decode_valid <= 1;
        end
        else begin
            decode_valid <= 0;
        end
    end
endmodule

module SymbolTableLookup (
    input wire clk,
    input wire reset,
    input wire lookup_en,
    input wire [15:0] decoded_range,
    output reg [7:0] symbol_code,
    output reg lookup_valid,
    output reg lookup_error
);
    reg [15:0] range_table [0:255];
    reg [7:0] symbol_table [0:255];

    initial begin
        $readmemh("range_table.mem", range_table);
        $readmemh("symbol_table.mem", symbol_table);
    end

    reg [7:0] low, high, mid;
    reg [1:0] search_state;
    reg [15:0] current_range;

    localparam IDLE = 0, SEARCHING = 1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lookup_valid <= 0;
            lookup_error <= 0;
            search_state <= IDLE;
        end
        else begin
            case (search_state)
                IDLE: begin
                    if (lookup_en) begin
                        current_range <= decoded_range;
                        low <= 0;
                        high <= 255;
                        mid <= 128;
                        search_state <= SEARCHING;
                        lookup_valid <= 0;
                        lookup_error <= 0;
                    end
                end
                SEARCHING: begin
                    if (low > high) begin
                        lookup_error <= 1;
                        search_state <= IDLE;
                    end
                    else if (current_range < range_table[mid]) begin
                        if (mid == 0 || current_range >= range_table[mid-1]) begin
                            symbol_code <= symbol_table[mid];
                            lookup_valid <= 1;
                            search_state <= IDLE;
                        end
                        else begin
                            high <= mid - 1;
                            mid <= (low + mid - 1) >> 1;
                        end
                    end
                    else begin
                        low <= mid + 1;
                        mid <= (mid + 1 + high) >> 1;
                    end
                end
            endcase
        end
    end
endmodule


module SymbolMapper (
    input wire clk,
    input wire reset,
    input wire mapper_en,
    input wire [15:0] decoded_range,
    output reg [15:0] decoded_symbol,
    output reg mapper_valid,
    output reg mapper_error
);
    wire [7:0] symbol_code;
    wire lookup_valid;
    wire lookup_error;
    wire decode_valid;

    SymbolTableLookup u_lookup (
        .clk(clk),
        .reset(reset),
        .lookup_en(mapper_en),
        .decoded_range(decoded_range),
        .symbol_code(symbol_code),
        .lookup_valid(lookup_valid),
        .lookup_error(lookup_error)
    );

    SymbolDecoder u_decoder (
        .clk(clk),
        .reset(reset),
        .decode_en(lookup_valid),
        .symbol_code(symbol_code),
        .decoded_symbol(decoded_symbol),
        .decode_valid(decode_valid)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mapper_valid <= 1'b0;
            mapper_error <= 1'b0;
        end
        else begin
            if (lookup_error) begin
                mapper_valid <= 1'b0;
                mapper_error <= 1'b1;
            end
            else if (decode_valid) begin
                mapper_valid <= 1'b1;
                mapper_error <= 1'b0;
            end
            else begin
                mapper_valid <= 1'b0;
                mapper_error <= 1'b0;
            end
        end
    end
endmodule

module EntropyDecoder (
    input wire clk,                     // Clock tín hiệu
    input wire reset,                   // Reset tín hiệu
    input wire decode_en,               // Enable để kích hoạt giải mã
    input wire [7:0] encoded_data,      // Dữ liệu mã hóa (8-bit)
    input wire [15:0] bitstream,        // Bitstream để chuẩn hóa range
    output reg [15:0] decoded_symbol,   // Biểu tượng giải mã
    output reg decode_valid,            // Cờ báo kết quả hợp lệ
    output reg decode_error             // Cờ báo lỗi
);

    // Tín hiệu trung gian
    wire [15:0] decoded_range;          // Phạm vi giải mã từ RangeCalculator
    wire range_error;                   // Cờ lỗi từ RangeCalculator
    wire [15:0] mapped_symbol;          // Biểu tượng từ SymbolMapper
    wire mapper_valid;                  // Cờ hợp lệ từ SymbolMapper
    wire mapper_error;                  // Cờ lỗi từ SymbolMapper
    wire [15:0] new_context;            // Ngữ cảnh mới từ ContextUpdater
    wire context_valid;                 // Cờ hợp lệ từ ContextUpdater

    // Thanh ghi lưu trữ ngữ cảnh hiện tại
    reg [15:0] current_context;

    // Khởi tạo các module con
    RangeCalculator u_range_calc (
        .clk(clk),
        .reset(reset),
        .init_pulse(decode_en),
        .update_en(decode_en),
        .normalize_en(decode_en),
        .encoded_data(encoded_data),
        .bitstream(bitstream),
        .decoded_range(decoded_range),
        .error_flag(range_error)
    );

    SymbolMapper u_symbol_map (
        .clk(clk),
        .reset(reset),
        .mapper_en(decode_en),
        .decoded_range(decoded_range),
        .decoded_symbol(mapped_symbol),
        .mapper_valid(mapper_valid),
        .mapper_error(mapper_error)
    );

    ContextUpdater u_context_update (
        .clk(clk),
        .reset(reset),
        .update_en(mapper_valid),
        .decoded_symbol(mapped_symbol),
        .current_context(current_context),
        .new_context(new_context),
        .context_valid(context_valid)
    );

    // Logic điều khiển chính
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_symbol <= 16'h0000;
            decode_valid <= 1'b0;
            decode_error <= 1'b0;
            current_context <= 16'h0000; // Khởi tạo ngữ cảnh mặc định
        end
        else if (decode_en) begin
            if (range_error || mapper_error || !context_valid) begin
                decoded_symbol <= 16'h0000;
                decode_valid <= 1'b0;
                decode_error <= 1'b1;
            end
            else if (mapper_valid) begin
                decoded_symbol <= mapped_symbol;
                decode_valid <= 1'b1;
                decode_error <= 1'b0;
                current_context <= new_context; // Cập nhật ngữ cảnh
            end
            else begin
                decode_valid <= 1'b0;
                decode_error <= 1'b0;
            end
        end
    end
endmodule


typedef struct packed {
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] z;
} point_t;

// Adder with saturation to prevent overflow
module AdderUnit (
    input  point_t pred,
    input  point_t res,
    output point_t P
);
    localparam MAX_VAL = (1 << 31) - 1;  // 2^31 - 1
    localparam MIN_VAL = - (1 << 31);    // -2^31
    
    function automatic logic signed [31:0] sat_add(
        input logic signed [31:0] a,
        input logic signed [31:0] b
    );
        logic signed [32:0] sum = a + b; // Extra bit to detect overflow
        if (sum > MAX_VAL) return MAX_VAL;
        else if (sum < MIN_VAL) return MIN_VAL;
        else return sum[31:0];
    endfunction

    assign P.x = sat_add(pred.x, res.x);
    assign P.y = sat_add(pred.y, res.y);
    assign P.z = sat_add(pred.z, res.z);
endmodule

typedef struct packed {
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] z;
} point_t;

// Point Predictor with overflow prevention
module PointPredictor (
    input  logic [1:0] mode,
    input  point_t P_prev1,
    input  point_t P_prev2,
    output point_t pred
);
    always_comb begin
        case (mode)
            2'b00: pred = P_prev1;  // Predict previous point
            2'b01: begin            // Linear extrapolation
                // Use temporary variables to prevent overflow
                logic signed [31:0] temp_x = P_prev1.x * 2;
                logic signed [31:0] temp_y = P_prev1.y * 2;
                logic signed [31:0] temp_z = P_prev1.z * 2;
                pred.x = temp_x - P_prev2.x;
                pred.y = temp_y - P_prev2.y;
                pred.z = temp_z - P_prev2.z;
            end
            default: pred = '{0, 0, 0}; // Handle invalid mode
        endcase
    end
endmodule


// Module: Attribute Residual Extractor
module AttributeResidualExtractor #(
    parameter SYMBOL_WIDTH = 8,
    parameter ATTR_WIDTH = 8
)(
    input  logic [SYMBOL_WIDTH-1:0] residual_symbol,
    output logic signed [ATTR_WIDTH-1:0] residual
);
    always_comb begin
        if (SYMBOL_WIDTH >= ATTR_WIDTH) begin
            residual = residual_symbol[ATTR_WIDTH-1:0];
        end else begin
            residual = {{(ATTR_WIDTH-SYMBOL_WIDTH){residual_symbol[SYMBOL_WIDTH-1]}}, 
                       residual_symbol};
        end
    end
endmodule


typedef struct packed {
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] z;
} point_t;

// Optimized Geometry Decompressor with FSM for enable handling
module GeometryDecompressor (
    input  logic clock,
    input  logic reset,
    input  logic enable,
    input  logic [1:0] mode,
    input  logic signed [31:0] res_x,
    input  logic signed [31:0] res_y,
    input  logic signed [31:0] res_z,
    output logic signed [31:0] P_x,
    output logic signed [31:0] P_y,
    output logic signed [31:0] P_z
);
    typedef enum logic { IDLE = 1'b0, PROCESS = 1'b1 } state_t;
    state_t state;

    point_t P_prev1, P_prev2;
    point_t pred, res, P_current;

    // Assign residuals directly
    assign res = '{res_x, res_y, res_z};

    // Instantiate sub-modules
    PointPredictor predictor (
        .mode(mode),
        .P_prev1(P_prev1),
        .P_prev2(P_prev2),
        .pred(pred)
    );

    AdderUnit adder (
        .pred(pred),
        .res(res),
        .P(P_current)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            state <= IDLE;
            P_prev1 <= '{0, 0, 0};
            P_prev2 <= '{0, 0, 0};
            {P_x, P_y, P_z} <= '{0, 0, 0};
        end else begin
            unique case (state)
                IDLE: 
                    if (enable) state <= PROCESS;
                
                PROCESS: begin
                    P_prev2 <= P_prev1;
                    P_prev1 <= P_current;
                    {P_x, P_y, P_z} <= {P_current.x, P_current.y, P_current.z};
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

// Sub-module: Buffer Writer
module buffer_writer (
    input  logic        clk,
    input  logic        reset,
    input  logic [127:0] point,
    input  logic         valid_in,
    output logic [511:0] buffer_next,
    output logic         write_full
);
    logic [511:0] buffer_reg;
    logic [2:0]   num_points;

    // Calculate next state
    always_comb begin
        if (valid_in) begin
            buffer_next = {point, buffer_reg[511:128]}; // Shift left, add point to MSB
            write_full = (num_points == 3'd3);
        end else begin
            buffer_next = buffer_reg;
            write_full = 1'b0;
        end
    end

    // Register update
    always_ff @(posedge clk) begin
        if (reset) begin
            buffer_reg <= 512'b0;
            num_points <= 3'b0;
        end else if (valid_in) begin
            buffer_reg <= buffer_next;
            num_points <= (num_points == 3'd3) ? 3'b0 : num_points + 1;
        end
    end

endmodule

// Sub-module: Data Encryption Module
module data_encryption_module (
    input  logic        clk,
    input  logic        reset,
    input  logic [511:0] point_cloud,
    input  logic         valid_in,
    output logic [511:0] encrypted_data,
    output logic         valid_out
);
    typedef enum logic [1:0] {IDLE, PROCESS, DONE} state_t;
    state_t state;
    logic [511:0] pipeline_reg;
    logic [255:0] encryption_key = 256'hA5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5_A5A5;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            encrypted_data <= 512'b0;
            valid_out <= 1'b0;
            pipeline_reg <= 512'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_in) begin
                        pipeline_reg <= point_cloud;
                        state <= PROCESS;
                        valid_out <= 1'b0;
                    end
                end
                /

                PROCESS: begin
                    // Simplified AES-256 (XOR for demo)
                    encrypted_data <= pipeline_reg ^ {2{encryption_key}};
                    state <= DONE;
                    valid_out <= 1'b0;
                end
                DONE: begin
                    valid_out <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// Sub-module: Output Packer
module output_packer (
    input  logic        clk,
    input  logic        reset,
    input  logic [511:0] buffer_next,
    input  logic         write_full,
    output logic [511:0] packed_data,
    output logic         packed_valid
);
    always_ff @(posedge clk) begin
        if (reset) begin
            packed_data <= 512'b0;
            packed_valid <= 1'b0;
        end else begin
            packed_valid <= write_full;
            if (write_full) begin
                packed_data <= buffer_next; // Capture buffer with four points
            end
        end
    end

endmodule

// Sub-module: Point Formatter
module point_formatter (
    input  logic [31:0] x,
    input  logic [31:0] y,
    input  logic [31:0] z,
    input  logic [7:0]  R,
    input  logic [7:0]  G,
    input  logic [7:0]  B,
    input  logic [7:0]  intensity,
    input  logic        valid_in,
    output logic [127:0] point,
    output logic         valid_out
);
    // Combinational logic to format point
    assign point = {x, y, z, R, G, B, intensity}; // 32*3 + 8*4 = 128 bits
    assign valid_out = valid_in;

endmodule


// Top-level module: Point Cloud Assembler (Improved)
module point_cloud_assembler (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] x,          // 32-bit x coordinate
    input  logic [31:0] y,          // 32-bit y coordinate
    input  logic [31:0] z,          // 32-bit z coordinate
    input  logic [7:0]  R,          // 8-bit red
    input  logic [7:0]  G,          // 8-bit green
    input  logic [7:0]  B,          // 8-bit blue
    input  logic [7:0]  intensity,  // 8-bit intensity
    input  logic        valid_in,   // Input valid signal
    output logic [511:0] encrypted_data, // Encrypted 512-bit output
    output logic         output_valid    // Output valid signal
);

    // Internal signals
    logic [127:0] point;          // 128-bit formatted point
    logic         point_valid;    // Point Formatter output valid
    logic [511:0] buffer_next;    // Next buffer value
    logic         write_full;     // Buffer full signal
    logic [511:0] packed_data;    // Packed 512-bit data
    logic         packed_valid;   // Packed data valid

    // Instantiate sub-modules
    point_formatter pf (
        .x(x),
        .y(y),
        .z(z),
        .R(R),
        .G(G),
        .B(B),
        .intensity(intensity),
        .valid_in(valid_in),
        .point(point),
        .valid_out(point_valid)
    );

    buffer_writer bw (
        .clk(clk),
        .reset(reset),
        .point(point),
        .valid_in(point_valid),
        .buffer_next(buffer_next),
        .write_full(write_full)
    );

    output_packer op (
        .clk(clk),
        .reset(reset),
        .buffer_next(buffer_next),
        .write_full(write_full),
        .packed_data(packed_data),
        .packed_valid(packed_valid)
    );

    data_encryption_module dem (
        .clk(clk),
        .reset(reset),
        .point_cloud(packed_data),
        .valid_in(packed_valid),
        .encrypted_data(encrypted_data),
        .valid_out(output_valid)
    );

endmodule


module LiDARDecoder (
    input  logic        clk,                // Clock tín hiệu
    input  logic        reset,              // Reset tín hiệu
    input  logic        data_in_valid,      // Tín hiệu dữ liệu đầu vào hợp lệ
    input  logic [511:0] compressed_data,   // Dữ liệu nén 512-bit
    output logic [511:0] decoded_data,      // Dữ liệu đám mây điểm giải mã 512-bit
    output logic         data_out_valid,    // Tín hiệu đầu ra hợp lệ
    output logic         error_flag         // Tín hiệu lỗi tổng hợp
);

    // Parameters
    parameter N_POINTS         = 4;         // Số điểm mỗi batch
    parameter SYMBOL_WIDTH     = 16;        // Độ rộng biểu tượng giải mã
    parameter SYMBOLS_PER_POINT = 6;        // Số biểu tượng mỗi điểm
    parameter TOTAL_SYMBOLS    = N_POINTS * SYMBOLS_PER_POINT;
    parameter ATTR_WIDTH       = 32;        // Độ rộng thuộc tính (đồng bộ với attributes)
    parameter K                = 4;         // Số điểm lân cận
    parameter MODE_WIDTH       = 3;         // Độ rộng chế độ dự đoán

    // Tín hiệu nội bộ
    logic [511:0] encoded_data;
    logic [9:0]   data_size;
    logic [15:0]  point_count;
    logic [127:0] metadata;
    logic         bitstream_data_valid;
    logic         crc_error;
    logic         buffer_full;

    logic [SYMBOL_WIDTH-1:0] decoded_symbol;
    logic                    decode_valid;
    logic                    decode_error;
    
    logic [1:0]   gd_mode;
    logic signed [31:0] gd_res_x, gd_res_y, gd_res_z;
    logic signed [31:0] gd_P_x, gd_P_y, gd_P_z;
    
    logic [ATTR_WIDTH-1:0]   final_attribute;
    logic                    attr_error_flag;
    logic [ATTR_WIDTH-1:0]   neighboring_attributes [K-1:0];
    logic [SYMBOL_WIDTH-1:0] attr_decoded_symbols [1:0];
    
    logic [31:0] attributes;
    logic        pca_valid_in;
    logic [511:0] pca_encrypted_data;
    logic        pca_output_valid;

    // FSM states
    enum logic [3:0] {
        IDLE,
        READ_BITSTREAM,
        DECODE_SYMBOLS,
        PROCESS_GEOMETRY,
        PROCESS_ATTRIBUTES,
        WAIT_ATTRIBUTES,
        OUTPUT_DATA
    } state, next_state;

    // Khởi tạo các mô-đun con
    BitstreamReader bitstream_reader (
        .clk(clk),
        .reset(reset),
        .data_in_valid(data_in_valid),
        .compressed_data(compressed_data),
        .encoded_data(encoded_data),
        .data_size(data_size),
        .point_count(point_count),
        .metadata(metadata),
        .data_valid(bitstream_data_valid),
        .crc_error(crc_error),
        .buffer_full(buffer_full)
    );

    EntropyDecoder entropy_decoder (
        .clk(clk),
        .reset(reset),
        .decode_en(state == DECODE_SYMBOLS),
        .encoded_data(encoded_data[byte_index*8 +: 8]),
        .bitstream(encoded_data[15:0]),
        .decoded_symbol(decoded_symbol),
        .decode_valid(decode_valid),
        .decode_error(decode_error)
    );

    GeometryDecompressor gd (
        .clock(clk),
        .reset(reset),
        .enable(state == PROCESS_GEOMETRY),
        .mode(gd_mode),
        .res_x(gd_res_x),
        .res_y(gd_res_y),
        .res_z(gd_res_z),
        .P_x(gd_P_x),
        .P_y(gd_P_y),
        .P_z(gd_P_z)
    );

    AttributeDecompressor #(
        .ATTR_WIDTH(ATTR_WIDTH),
        .K(K),
        .MODE_WIDTH(MODE_WIDTH),
        .SYMBOL_WIDTH(SYMBOL_WIDTH)
    ) attr_decompressor (
        .clk(clk),
        .rst_n(~reset),
        .decoded_symbols(attr_decoded_symbols),
        .neighboring_attributes(neighboring_attributes),
        .final_attribute(final_attribute),
        .error_flag(attr_error_flag)
    );

    point_cloud_assembler pca (
        .clk(clk),
        .reset(reset),
        .x(gd_P_x),
        .y(gd_P_y),
        .z(gd_P_z),
        .R(attributes[7:0]),
        .G(attributes[15:8]),
        .B(attributes[23:16]),
        .intensity(attributes[31:24]),
        .valid_in(pca_valid_in),
        .encrypted_data(pca_encrypted_data),
        .output_valid(pca_output_valid)
    );

    // Biến đếm và bộ đệm
    logic [4:0] symbol_index;
    logic [1:0] point_index;
    logic [8:0] byte_index;
    logic [SYMBOL_WIDTH-1:0] symbol_buffer [0:TOTAL_SYMBOLS-1];

    // Pipeline registers
    logic signed [31:0] P_x_reg, P_y_reg, P_z_reg;
    logic [ATTR_WIDTH-1:0] attr_reg;

    // FSM logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            symbol_index <= 0;
            point_index <= 0;
            byte_index <= 0;
            error_flag <= 0;
            data_out_valid <= 0;
            pca_valid_in <= 0;
            P_x_reg <= 0;
            P_y_reg <= 0;
            P_z_reg <= 0;
            attr_reg <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                DECODE_SYMBOLS: begin
                    if (decode_valid) begin
                        symbol_buffer[symbol_index] <= decoded_symbol;
                        symbol_index <= symbol_index + 1;
                        byte_index <= byte_index + 1;
                    end
                end
                
                PROCESS_GEOMETRY: begin
                    P_x_reg <= gd_P_x;
                    P_y_reg <= gd_P_y;
                    P_z_reg <= gd_P_z;
                end
                
                PROCESS_ATTRIBUTES: begin
                    attr_decoded_symbols[0] <= symbol_buffer[point_index * SYMBOLS_PER_POINT + 4];
                    attr_decoded_symbols[1] <= symbol_buffer[point_index * SYMBOLS_PER_POINT + 5];
                    if (point_index > 0) begin
                        neighboring_attributes[0] <= attr_reg;
                        neighboring_attributes[1] <= 0; // Placeholder, cần logic thực tế
                        neighboring_attributes[2] <= 0;
                        neighboring_attributes[3] <= 0;
                    end else begin
                        neighboring_attributes <= '{default: 0};
                    end
                end
                
                WAIT_ATTRIBUTES: begin
                    if (!attr_error_flag) begin
                        attr_reg <= final_attribute;
                    end else begin
                        error_flag <= 1;
                    end
                end
                
                OUTPUT_DATA: begin
                    pca_valid_in <= 1;
                    point_index <= point_index + 1;
                end
                
                default: begin
                    pca_valid_in <= 0;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        
        if (buffer_full) next_state = IDLE;
        
        case (state)
            IDLE: 
                if (data_in_valid && !buffer_full) 
                    next_state = READ_BITSTREAM;
            
            READ_BITSTREAM:
                if (bitstream_data_valid) 
                    next_state = crc_error ? IDLE : DECODE_SYMBOLS;
            
            DECODE_SYMBOLS:
                if (decode_error) 
                    next_state = IDLE;
                else if (symbol_index == TOTAL_SYMBOLS) 
                    next_state = PROCESS_GEOMETRY;
            
            PROCESS_GEOMETRY:
                next_state = PROCESS_ATTRIBUTES;
            
            PROCESS_ATTRIBUTES:
                next_state = WAIT_ATTRIBUTES;
            
            WAIT_ATTRIBUTES:
                if (!attr_error_flag) 
                    next_state = OUTPUT_DATA;
                else 
                    next_state = IDLE;
            
            OUTPUT_DATA: 
                if (point_index == N_POINTS-1) 
                    next_state = IDLE;
                else 
                    next_state = PROCESS_GEOMETRY;
        endcase
    end

    // Continuous assignments
    assign gd_mode = symbol_buffer[point_index * SYMBOLS_PER_POINT][1:0];
    assign gd_res_x = $signed(symbol_buffer[point_index * SYMBOLS_PER_POINT + 1]);
    assign gd_res_y = $signed(symbol_buffer[point_index * SYMBOLS_PER_POINT + 2]);
    assign gd_res_z = $signed(symbol_buffer[point_index * SYMBOLS_PER_POINT + 3]);
    assign attributes = attr_reg;

    // Xử lý lỗi toàn cục và đầu ra
    always_ff @(posedge clk) begin
        error_flag <= crc_error || decode_error || attr_error_flag || (point_count != N_POINTS);
        data_out_valid <= pca_output_valid;
        decoded_data <= pca_encrypted_data;
    end

endmodule



































