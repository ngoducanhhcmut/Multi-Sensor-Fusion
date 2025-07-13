// ==========================================================
// Data Assembler
// ==========================================================
module data_assembler (
    input [511:0] lidar_data,
    input lidar_valid,
    input [3071:0] camera_data,
    input camera_valid,
    input [127:0] radar_data,
    input radar_valid,
    input [63:0] imu_data,
    input imu_valid,
    output logic [3839:0] fused_data,
    output logic valid
);

    always_comb begin
        valid = lidar_valid & camera_valid & radar_valid & imu_valid;
        if (valid) {
            fused_data[3839:3328] = lidar_data;
            fused_data[3327:256] = camera_data;
            fused_data[255:128] = radar_data;
            fused_data[127:64] = imu_data;
        } else {
            fused_data = '0;
        }
    end
endmodule