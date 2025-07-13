// Enhanced Top-Level Slice Decoder Module
module slice_decoder (
    input  logic             clk,
    input  logic             reset,
    input  logic             start,
    input  logic [3071:0]    nal_unit,
    output logic [1:0]       slice_type,
    output logic [2:0]       num_ref_idx_l0_active_minus1,
    output logic [2:0]       num_ref_idx_l1_active_minus1,
    output logic [5:0]       slice_qp_delta,
    output logic [3071:0]    slice_data,
    output logic             valid,
    output logic             error
);

    logic [11:0] bit_pos;
    logic header_valid;
    logic data_valid;

    // Instantiate Slice Header Parser
    slice_header_parser header_parser (
        .clk(clk),
        .reset(reset),
        .start(start),
        .nal_unit(nal_unit),
        .slice_type(slice_type),
        .num_ref_idx_l0_active_minus1(num_ref_idx_l0_active_minus1),
        .num_ref_idx_l1_active_minus1(num_ref_idx_l1_active_minus1),
        .slice_qp_delta(slice_qp_delta),
        .valid(header_valid),
        .error(error),
        .bit_pos(bit_pos)
    );

    // Instantiate Slice Data Extractor
    slice_data_extractor data_extractor (
        .nal_unit(nal_unit),
        .bit_pos(bit_pos),
        .valid_in(header_valid),
        .slice_data(slice_data),
        .valid_out(data_valid)
    );

    // Output control with error masking
    assign valid = data_valid && !error;

endmodule