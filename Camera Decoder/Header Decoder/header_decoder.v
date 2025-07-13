module header_decoder (
    input  logic        clk,
    input  logic        reset,
    input  logic [3071:0] nal_unit,
    input  logic        start,
    output logic        valid,
    output logic        done,
    output logic        error,
    // SPS Parameters
    output logic [7:0]  profile,
    output logic [15:0] width,
    output logic [15:0] height,
    output logic [7:0]  fps,
    output logic [1:0]  chroma_format,
    output logic [3:0]  bit_depth,
    // PPS Parameters
    output logic [5:0]  qp,
    output logic        tiles_enabled,
    output logic [3:0]  tile_cols,
    output logic [3:0]  tile_rows
);

    // Internal signals
    logic sps_done, pps_done, sps_error, pps_error;
    logic validator_valid;
    
    // Control FSM
    typedef enum {IDLE, DECODE_SPS, DECODE_PPS, VALIDATE, DONE} state_t;
    state_t state;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
        end else begin
            case(state)
                IDLE: if (start) state <= nal_unit[7:0] == 8'h42 ? DECODE_SPS : DECODE_PPS;
                
                DECODE_SPS: if (sps_done) begin
                    if (sps_error) begin
                        error <= 1;
                        state <= DONE;
                    end else state <= DECODE_PPS;
                end
                
                DECODE_PPS: if (pps_done) begin
                    if (pps_error) begin
                        error <= 1;
                        state <= DONE;
                    end else state <= VALIDATE;
                end
                
                VALIDATE: begin
                    valid <= validator_valid;
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // SPS Decoder instance
    sps_decoder sps_dec (
        .clk(clk),
        .reset(reset),
        .sps_bitstream(nal_unit),
        .start(state == DECODE_SPS),
        .profile(profile),
        .width(width),
        .height(height),
        .fps(fps),
        .chroma_format(chroma_format),
        .bit_depth(bit_depth),
        .done(sps_done),
        .error(sps_error)
    );

    // PPS Decoder instance
    pps_decoder pps_dec (
        .clk(clk),
        .reset(reset),
        .pps_bitstream(nal_unit),
        .start(state == DECODE_PPS),
        .qp(qp),
        .tiles_enabled(tiles_enabled),
        .tile_cols(tile_cols),
        .tile_rows(tile_rows),
        .done(pps_done),
        .error(pps_error)
    );

    // Parameter Validator
    parameter_validator validator (
        .clk(clk),
        .reset(reset),
        .profile(profile),
        .width(width),
        .height(height),
        .fps(fps),
        .chroma_format(chroma_format),
        .bit_depth(bit_depth),
        .qp(qp),
        .tiles_enabled(tiles_enabled),
        .tile_cols(tile_cols),
        .tile_rows(tile_rows),
        .valid(validator_valid),
        .done()
    );

endmodule