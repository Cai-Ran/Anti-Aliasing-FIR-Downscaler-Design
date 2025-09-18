/*
    check X scale-down results with Golden X scales-down results
*/
    LoadFrameFile goldenX_frame;
    WriteFrameFile tarX_frame;
    string goldenX_name = $sformatf("%s/%0dx%0d-%0dx%0d_%s", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);
    string tarX_name =$sformatf("%s/%0dx%0d-%0dx%0d_%s", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `SRC_HEIGHT, `PIC_NAME);

    task Xgolden_load_data();
        goldenX_frame = new(`TAR_WIDTH, `SRC_HEIGHT);
        goldenX_frame.read_file(goldenX_name);
        tarX_frame = new();
        tarX_frame.open_file(tarX_name);
    endtask

    int unsigned Xp_cnt;
    task Xmonitor_and_check();
        Xp_cnt = 0;
        @(done_reset);
        @(posedge inf.hsync);
        while(inf.data_enable) begin
            @(posedge inf.clk);
            if (tb.dut.Xout_rdy) begin
                if (tb.dut.outX_B!==goldenX_frame.B_frame[Xp_cnt] || tb.dut.outX_R!==goldenX_frame.R_frame[Xp_cnt] || tb.dut.outX_G!==goldenX_frame.G_frame[Xp_cnt])
                    $warning("Error: FIRX output not match at Xp_cnt= %0d", Xp_cnt);
                Xp_cnt <= Xp_cnt + 1;
            end
        end
    endtask

    int unsigned Xout_cnt;
    task Xwrite_output();
        @(done_reset);
        while (Xout_cnt+1 == Xp_cnt) begin
            @(posedge inf.clk);
            tarX_frame.write_pixel("R", tb.dut.outX_R);
            tarX_frame.write_pixel("G", tb.dut.outX_G);
            tarX_frame.write_pixel("B", tb.dut.outX_B);
            
            if ((Xout_cnt+1)%`TAR_WIDTH == 0)
                target_frame.write_string("\n");

            Xout_cnt <= Xout_cnt + 1;
        end
    endtask

/*
    check read ROM consistency
*/

    LoadROM rom;


    logic [`X_ROM_LEN_LOG2-1:0] Xstart_addr, Xend_addr; 
    logic [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] Xwindow_val;
    logic [`Y_ROM_LEN_LOG2-1:0] Ystart_addr, Yend_addr; 
    logic [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] Ywindow_val;

    logic [`X_ROM_LEN_LOG2-1:0] Xwindow_addr;
    logic [`Y_ROM_LEN_LOG2-1:0] Ywindow_addr;

    always_comb begin
        Xstart_addr = rom.Xstart_table_rom[`RESOLUTION_PAIR_IDX];
        Xend_addr   = rom.Xstart_table_rom[`RESOLUTION_PAIR_IDX+1]-1;
        Xwindow_val = rom.Xwindow_rom[Xwindow_addr];

        Ystart_addr = rom.Ystart_table_rom[`RESOLUTION_PAIR_IDX];
        Yend_addr   = rom.Ystart_table_rom[`RESOLUTION_PAIR_IDX+1]-1;
        Ywindow_val = rom.Ywindow_rom[Ywindow_addr];
    end


    task load_rom_content();
        static string xrom_name = $sformatf("%s/Xwindow_rom.mem", `IN_ROM_DIR);
        static string yrom_name = $sformatf("%s/Ywindow_rom.mem", `IN_ROM_DIR);
        static string xtable_name = $sformatf("%s/X_start_table.mem", `IN_ROM_DIR);
        static string ytable_name = $sformatf("%s/Y_start_table.mem", `IN_ROM_DIR);
        rom = new();
        rom.load(xrom_name, yrom_name, xtable_name, ytable_name);
    endtask


    task ref_Xrom_address();
        static int unsigned cnt_load_x = 0;
        static int unsigned x_addr_move_cnt = 0;

        while (!inf.frame_done) begin
            @(posedge inf.clk);
            if (!inf.rst_n)
                Xwindow_addr <= Xstart_addr;
            else if (inf.data_enable) begin
                if (cnt_load_x == Xwindow_val-1) begin
                    if (x_addr_move_cnt == Xend_addr-Xstart_addr) begin      
                        Xwindow_addr <= Xstart_addr;
                        x_addr_move_cnt <= 0;               //LHS in non-blocking assignment may not be an automatic variable
                    end else begin
                        Xwindow_addr <= Xwindow_addr+1;
                        x_addr_move_cnt <= x_addr_move_cnt + 1;
                    end
                    cnt_load_x <= 0;
                end
                else 
                    cnt_load_x <= cnt_load_x + 1;
            end
        end       

    endtask

    task ref_Yrom_address();
        static int unsigned cnt_load_y = 0;
        static int unsigned y_addr_move_cnt = 0;
        static int unsigned output_pixel_cnt = 0;
        static int unsigned input_row_cnt = 0;

        while (!inf.frame_done) begin
            @(posedge inf.clk);
            if (!inf.rst_n)
                Ywindow_addr <= Ystart_addr;
            else begin
                if (output_pixel_cnt == `TAR_WIDTH) begin
                    output_pixel_cnt <= 0;
                    if (y_addr_move_cnt == Yend_addr-Ystart_addr) begin
                        Ywindow_addr <= Ystart_addr;
                        y_addr_move_cnt <= 0;
                    end else begin
                        Ywindow_addr <= Ywindow_addr + 1;
                        y_addr_move_cnt <= y_addr_move_cnt + 1;
                    end
                end else if (inf.en_output) begin
                    output_pixel_cnt <= output_pixel_cnt + 1;
                end
            end
        end
    endtask


    task check_rom_address();
        while (!inf.frame_done) begin
            @(posedge inf.clk);
            assert (tb.dut.xw === Xwindow_addr) else $display("Error: xwindow_rom address not match. RTL: %0h, VAL: %0h", tb.dut.xw, Xwindow_addr);
            assert (tb.dut.yw === Ywindow_addr) else $display("Error: ywindow_rom address not match. RTL: %0h, VAL: %0h", tb.dut.yw, Ywindow_addr);
        end
    endtask
