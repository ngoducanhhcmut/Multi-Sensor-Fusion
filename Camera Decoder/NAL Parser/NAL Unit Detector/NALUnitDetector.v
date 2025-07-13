// NAL Unit Detector Module (FSM-based)
module NALUnitDetector (
    input  logic         clk,
    input  logic         reset,
    input  logic [3071:0] chunk_data,      // 3072-bit chunk input
    input  logic         chunk_valid,      // Valid signal for chunk
    output logic         nal_start,        // Start of NAL unit
    output logic         nal_end,          // End of NAL unit
    output logic [3071:0] nal_payload,     // NAL payload data
    output logic [9:0]   nal_payload_size  // Valid bytes in payload
);

    typedef enum logic [1:0] {
        IDLE,
        PROCESS_CHUNK,
        START_FOUND
    } state_t;
    
    state_t state, next_state;
    logic [23:0] shift_reg;
    logic start_code_found;
    logic long_start_code;
    logic [9:0] byte_idx;
    logic [9:0] payload_count;
    logic [3071:0] payload_buffer;
    logic chunk_done;
    
    localparam START_CODE_SHORT = 24'h000001;
    localparam START_CODE_LONG  = 32'h00000001;
    
    always_comb begin
        start_code_found = (shift_reg[23:0] == START_CODE_SHORT);
        long_start_code = (shift_reg[15:0] == 16'h0000) && (chunk_data[byte_idx*8 +:8] == 8'h01);
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            shift_reg <= '0;
            byte_idx <= '0;
            payload_count <= '0;
            payload_buffer <= '0;
            nal_start <= 1'b0;
            nal_end <= 1'b0;
            nal_payload <= '0;
            nal_payload_size <= '0;
            chunk_done <= 1'b0;
        end else begin
            nal_start <= 1'b0;
            nal_end <= 1'b0;
            chunk_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (chunk_valid) begin
                        state <= PROCESS_CHUNK;
                        byte_idx <= 0;
                        shift_reg <= '0;
                        payload_count <= 0;
                    end
                end
                
                PROCESS_CHUNK: begin
                    if (byte_idx < 384) begin
                        shift_reg <= {shift_reg[15:0], chunk_data[byte_idx*8 +:8]};
                        
                        if (start_code_found || (byte_idx >= 1 && long_start_code)) begin
                            if (payload_count > 0) begin
                                nal_end <= 1'b1;
                                nal_payload <= payload_buffer;
                                nal_payload_size <= payload_count;
                            end
                            
                            state <= START_FOUND;
                            nal_start <= 1'b1;
                            payload_count <= 0;
                            payload_buffer <= '0;
                            
                            if (long_start_code) begin
                                byte_idx <= byte_idx + 1;
                            end
                        end else begin
                            if (!(shift_reg[23:16] == 8'h00 && shift_reg[15:8] == 8'h00 && shift_reg[7:0] == 8'h03)) begin
                                if (payload_count < 384) begin
                                    payload_buffer[payload_count*8 +:8] <= chunk_data[byte_idx*8 +:8];
                                    payload_count <= payload_count + 1;
                                end
                            end
                        end
                        byte_idx <= byte_idx + 1;
                    end else begin
                        chunk_done <= 1'b1;
                        state <= IDLE;
                        if (payload_count > 0) begin
                            nal_end <= 1'b1;
                            nal_payload <= payload_buffer;
                            nal_payload_size <= payload_count;
                        end
                    end
                end
                
                START_FOUND: begin
                    shift_reg <= '0;
                    state <= PROCESS_CHUNK;
                end
            endcase
        end
    end
endmodule