module validate();

`ifdef VALIDATION_MODE

/*
    check X scale-down results with Golden X scales-down results
*/
    reg [7:0] goldenX_frame_R [0: `TAR_WIDTH*`SRC_HEIGHT-1];
    reg [7:0] goldenX_frame_G [0: `TAR_WIDTH*`SRC_HEIGHT-1];
    reg [7:0] goldenX_frame_B [0: `TAR_WIDTH*`SRC_HEIGHT-1];

    reg [64*8-1:0] goldenX_filename;
    initial begin
        $sformat(goldenX_filename, "%s/%0dx%0d-%0dx%0d_%s_R.hex", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        $readmemh(goldenX_filename, goldenX_frame_R);
        $sformat(goldenX_filename, "%s/%0dx%0d-%0dx%0d_%s_G.hex", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        $readmemh(goldenX_filename, goldenX_frame_G);
        $sformat(goldenX_filename, "%s/%0dx%0d-%0dx%0d_%s_B.hex", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        $readmemh(goldenX_filename, goldenX_frame_B);
    end

    integer Xp_cnt;

    reg flag_new_line;
    reg [64*8-1:0] x_filename;
    integer fFIRX_R, fFIRX_G, fFIRX_B;
    initial begin
        $sformat(x_filename, "%s/%0dx%0d-%0dx%0d_%s_R.hex", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        // $display("check fir x output filename: %s", x_filename);
        fFIRX_R = $fopen(x_filename, "w");
        $sformat(x_filename, "%s/%0dx%0d-%0dx%0d_%s_G.hex", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        fFIRX_G = $fopen(x_filename, "w");
        $sformat(x_filename, "%s/%0dx%0d-%0dx%0d_%s_B.hex", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        fFIRX_B = $fopen(x_filename, "w");

        Xp_cnt = 0;
        flag_new_line = 0;
        forever begin
            @(posedge tb.dut.clk);
            while (tb.dut.data_enable) begin
                @(posedge tb.dut.clk)
                if (tb.dut.Xout_rdy) begin
                    @(posedge tb.dut.clk);
                    if (tb.dut.outX_B!==goldenX_frame_B[Xp_cnt] || tb.dut.outX_R!==goldenX_frame_R[Xp_cnt] || tb.dut.outX_G!==goldenX_frame_G[Xp_cnt])
                        $warning("Error: FIRX output not match at Xp_cnt= %0d", Xp_cnt);
                    Xp_cnt <= Xp_cnt + 1;

                    $fwrite(fFIRX_R, "%h ", tb.dut.outX_R);
                    $fwrite(fFIRX_G, "%h ", tb.dut.outX_G);
                    $fwrite(fFIRX_B, "%h ", tb.dut.outX_B);
                end
                flag_new_line <= 1;
            end
            
            if (flag_new_line) begin
                $fwrite(fFIRX_R, "\n");
                $fwrite(fFIRX_G, "\n");
                $fwrite(fFIRX_B, "\n");
                flag_new_line <= 0;
            end
        end
    end

/*
    check read ROM consistency

*/
    reg [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] v_Xwindow_rom [0: `X_ROM_LEN-1];
    reg [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] v_Ywindow_rom [0: `Y_ROM_LEN-1];
    reg [`X_ROM_LEN_LOG2-1:0] v_Xwindow_addr;
    reg [`Y_ROM_LEN_LOG2-1:0] v_Ywindow_addr;

    reg [`X_ROM_LEN_LOG2-1:0] v_Xstart_table_rom [0: `NUM_RESLUTION_PAIR-1];
    reg [`Y_ROM_LEN_LOG2-1:0] v_Ystart_table_rom [0: `NUM_RESLUTION_PAIR-1];

    wire [`X_ROM_LEN_LOG2-1:0] v_Xstart_addr, v_Xend_addr; 
    assign v_Xstart_addr = v_Xstart_table_rom[`RESOLUTION_PAIR_IDX];
    assign v_Xend_addr   = v_Xstart_table_rom[`RESOLUTION_PAIR_IDX+1]-1;

    wire [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] v_Xwindow_val;
    assign v_Xwindow_val = v_Xwindow_rom[v_Xwindow_addr];

    integer v_cnt_load_x;
    integer x_addr_move_cnt;

    reg [64*8-1:0] v_rom_filename;

    initial begin
        $sformat(v_rom_filename, "%s/Xwindow_rom.mem", `IN_ROM_DIR);
        $readmemh(v_rom_filename, v_Xwindow_rom);
        $sformat(v_rom_filename, "%s/X_start_table.mem", `IN_ROM_DIR);
        $readmemh(v_rom_filename, v_Xstart_table_rom);

        v_cnt_load_x = 0;
        x_addr_move_cnt = 0;
        $display("Info: Xrom start addr: %0h, end addr: %0h", v_Xstart_addr, v_Xend_addr);

        forever begin
            @(posedge tb.clk);
            if (!tb.rst_n)
                v_Xwindow_addr <= v_Xstart_addr;
            else if (tb.data_enable) begin
                if (v_cnt_load_x == v_Xwindow_val-1) begin
                    if (x_addr_move_cnt == v_Xend_addr-v_Xstart_addr) begin      
                        v_Xwindow_addr <= v_Xstart_addr;
                        x_addr_move_cnt <= 0; 
                    end else begin
                        v_Xwindow_addr <= v_Xwindow_addr+1;
                        x_addr_move_cnt <= x_addr_move_cnt + 1;
                    end
                    v_cnt_load_x <= 0;
                end
                else 
                    v_cnt_load_x <= v_cnt_load_x + 1;
            end
        end       
    end


    wire [`Y_ROM_LEN_LOG2-1:0] v_Ystart_addr, v_Yend_addr; 
    assign v_Ystart_addr = v_Ystart_table_rom[`RESOLUTION_PAIR_IDX];
    assign v_Yend_addr   = v_Ystart_table_rom[`RESOLUTION_PAIR_IDX+1]-1;

    wire [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] v_Ywindow_val;
    assign v_Ywindow_val = v_Ywindow_rom[v_Ywindow_addr];


    integer y_addr_move_cnt;

    integer v_output_pixel_cnt;
    integer v_input_row_cnt;

    initial begin
        forever begin
            @(posedge tb.clk);
            if (v_output_pixel_cnt == `TAR_WIDTH) 
                v_output_pixel_cnt <= 0;
            else if (tb.en_output)
                v_output_pixel_cnt <= v_output_pixel_cnt + 1;
        end
    end
        

    initial begin
        $sformat(v_rom_filename, "%s/Ywindow_rom.mem", `IN_ROM_DIR);
        $readmemh(v_rom_filename, v_Ywindow_rom);
        $sformat(v_rom_filename, "%s/Y_start_table.mem", `IN_ROM_DIR);
        $readmemh(v_rom_filename, v_Ystart_table_rom);

        $display("Info: Yrom start addr: %0h, end addr: %0h", v_Ystart_addr, v_Yend_addr);

        y_addr_move_cnt = 0;
        v_output_pixel_cnt = 0;
        v_input_row_cnt = 0;

        forever begin
            @(posedge tb.clk);
            if (!tb.rst_n)
                v_Ywindow_addr <= v_Ystart_addr;
            else begin
                if (v_output_pixel_cnt == `TAR_WIDTH) begin
                    if (y_addr_move_cnt == v_Yend_addr-v_Ystart_addr) begin
                        v_Ywindow_addr <= v_Ystart_addr;
                        y_addr_move_cnt <= 0;
                    end else begin
                        v_Ywindow_addr <= v_Ywindow_addr + 1;
                        y_addr_move_cnt <= y_addr_move_cnt + 1;
                    end
                end
            end
        end
    end
        

    always begin
        @(posedge tb.dut.clk);
        if (tb.dut.xw !== v_Xwindow_addr) begin
            $display("Error: xwindow_rom address not match. RTL: %0h, VAL: %0h", tb.dut.xw, v_Xwindow_addr);//$finish;
        end 
        if (tb.dut.yw !== v_Ywindow_addr) begin
            $display("Error: ywindow_rom address not match. RTL: %0h, VAL: %0h", tb.dut.yw, v_Ywindow_addr);
        end
    end


`endif 

endmodule