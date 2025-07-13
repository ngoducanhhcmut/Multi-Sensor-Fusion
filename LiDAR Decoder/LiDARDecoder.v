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