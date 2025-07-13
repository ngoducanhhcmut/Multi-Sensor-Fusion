// Slice Header Parser Module (Optimized)
module slice_header_parser (
    input  logic             clk,
    input  logic             reset,
    input  logic             start,                // Signal to begin parsing
    input  logic [3071:0]    nal_unit,             // Input NAL unit (slice RBSP)
    output logic [1:0]       slice_type,           // 00: I, 01: P, 10: B
    output logic [2:0]       num_ref_idx_l0_active_minus1, // Ref list 0 count
    output logic [2:0]       num_ref_idx_l1_active_minus1, // Ref list 1 count (B only)
    output logic [5:0]       slice_qp_delta,       // QP delta
    output logic             valid,                // Header parsing complete
    output logic             error,                // Invalid slice type detected
    output logic [11:0]      bit_pos               // Position after header
);

    // State machine states
    typedef enum logic [2:0] {
        IDLE             = 3'd0,
        READ_SLICE_TYPE  = 3'd1,
        READ_NUM_REF_L0  = 3'd2,
        READ_NUM_REF_L1  = 3'd3,
        READ_QP_DELTA    = 3'd4,
        DONE             = 3'd5,
        ERROR            = 3'd6,
        INVALID_STATE    = 3'd7
    } state_t;

    state_t state, next_state;
    logic [11:0] bit_pos_reg;  // Internal bit position tracker
    logic [1:0]  reg_slice_type; // Registered slice type

    // Sequential logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state                   <= IDLE;
            bit_pos_reg             <= 0;
            valid                   <= 0;
            error                   <= 0;
            slice_type              <= 0;
            reg_slice_type          <= 0;
            num_ref_idx_l0_active_minus1 <= 0;
            num_ref_idx_l1_active_minus1 <= 0;
            slice_qp_delta          <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid  <= 0;
                    error  <= 0;
                    bit_pos_reg <= 0;
                end
                
                READ_SLICE_TYPE: begin
                    if (bit_pos_reg <= 3070) begin
                        reg_slice_type <= nal_unit[bit_pos_reg +: 2];
                        slice_type <= nal_unit[bit_pos_reg +: 2];
                        bit_pos_reg <= bit_pos_reg + 2;
                    end
                end
                
                READ_NUM_REF_L0: begin
                    if (bit_pos_reg <= 3069) begin
                        num_ref_idx_l0_active_minus1 <= nal_unit[bit_pos_reg +: 3];
                        bit_pos_reg <= bit_pos_reg + 3;
                    end
                end
                
                READ_NUM_REF_L1: begin
                    if (bit_pos_reg <= 3069) begin
                        num_ref_idx_l1_active_minus1 <= nal_unit[bit_pos_reg +: 3];
                        bit_pos_reg <= bit_pos_reg + 3;
                    end
                end
                
                READ_QP_DELTA: begin
                    if (bit_pos_reg <= 3066) begin
                        slice_qp_delta <= nal_unit[bit_pos_reg +: 6];
                        bit_pos_reg <= bit_pos_reg + 6;
                    end
                end
                
                DONE: begin
                    valid <= 1;
                end
                
                ERROR: begin
                    error <= 1;
                end
                
                default: begin
                    // Recovery mechanism
                    state <= IDLE;
                    error <= 1;
                end
            endcase
        end
    end

    // Next state logic with enhanced error checking
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = (bit_pos_reg < 3072) ? READ_SLICE_TYPE : ERROR;
                end
            end
            
            READ_SLICE_TYPE: begin
                if (bit_pos_reg > 3070) begin
                    next_state = ERROR;
                end else begin
                    case (nal_unit[bit_pos_reg +: 2])
                        2'b00: next_state = READ_QP_DELTA;  // I slice
                        2'b01: next_state = READ_NUM_REF_L0; // P slice
                        2'b10: next_state = READ_NUM_REF_L0; // B slice
                        default: next_state = ERROR;         // Invalid slice type
                    endcase
                end
            end
            
            READ_NUM_REF_L0: begin
                if (bit_pos_reg > 3069) begin
                    next_state = ERROR;
                end else begin
                    // Additional slice type validation
                    if (!(reg_slice_type inside {2'b01, 2'b10})) begin
                        next_state = ERROR;
                    end else if (reg_slice_type == 2'b01) begin
                        next_state = READ_QP_DELTA;  // P slice
                    end else begin
                        next_state = READ_NUM_REF_L1; // B slice
                    end
                end
            end
            
            READ_NUM_REF_L1: begin
                if (bit_pos_reg > 3069) novices
                    next_state = ERROR;
                end else begin
                    // Validate slice type must be B
                    next_state = (reg_slice_type == 2'b10) ? READ_QP_DELTA : ERROR;
                end
            end
            
            READ_QP_DELTA: begin
                if (bit_pos_reg > 3066) begin
                    next_state = ERROR;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE, ERROR: begin
                // Auto-reset for continuous processing
                if (start) next_state = IDLE;
            end
            
            default: next_state = ERROR;
        endcase
    end

    assign bit_pos = bit_pos_reg;

endmodule