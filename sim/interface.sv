
    interface dut_interface();
        logic clk, rst_n;
        logic vsync, hsync, data_enable;
        logic [7:0] cur_R, cur_G, cur_B;
        logic [`RESOLUTION_PAIR_LOG2-1:0] resolution_pair_idx;
        logic [2:0] X_factor, Y_factor;
        logic [`MAX_ROW_LOG2-1:0] tar_width;
        logic [`MAX_COL_LOG2-1:0] tar_height;
        logic [7:0] out_R, out_G, out_B;
        logic en_output, frame_done;

        modport DUT(input clk, rst_n, vsync, hsync, data_enable, cur_R, cur_G, cur_B, resolution_pair_idx, X_factor, Y_factor, tar_width, tar_height,
                    output out_R, out_G, out_B, en_output, frame_done);

        modport INF(output clk, rst_n, vsync, hsync, data_enable, cur_R, cur_G, cur_B, resolution_pair_idx, X_factor, Y_factor, tar_width, tar_height,
                    input out_R, out_G, out_B, en_output, frame_done);

    endinterface
