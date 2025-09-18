`define SIM
// `define DUMP_WAVE
`define VALIDATION_MODE

`include `CONFIG_FILE
`timescale 1ps/1ps

`include "./RTL/downsample_scaler.v"
`include "interface.sv"

module tb;
    import load_file_pkg::*;
    import write_file::*;

    dut_interface inf();

    `ifdef VALIDATION_MODE
        import load_rom_pkg::*;
        `include "validate.sv"
    `endif

    LoadFrameFile source_frame;
    LoadFrameFile golden_frame;
    WriteFrameFile target_frame;


    task load_data();
        static string src_name = $sformatf("%s/%0dx%0d_%s", `IN_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `PIC_NAME);
        static string golden_name = $sformatf("%s/%0dx%0d_%0dx%0d_%s", `GOLDEN_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);
        static string tar_name = $sformatf("%s/%0dx%0d_%0dx%0d_%s", `OUT_HEX_DIR, `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT, `PIC_NAME);

        source_frame = new(`SRC_WIDTH, `SRC_HEIGHT); 
        source_frame.read_file(src_name);
        golden_frame = new(`SRC_WIDTH, `SRC_HEIGHT); 
        golden_frame.read_file(golden_name);

        target_frame = new();
        target_frame.open_file(tar_name);
    endtask

    always_comb begin
        inf.resolution_pair_idx = `RESOLUTION_PAIR_IDX;
        inf.X_factor = `X_DECIMATION_FACTOR;
        inf.Y_factor = `Y_DECIMATION_FACTOR;
        inf.tar_width = `TAR_WIDTH;
        inf.tar_height = `TAR_HEIGHT;
    end


    downsample_scaler dut(
        .clk(inf.clk), .rst_n(inf.rst_n), 
        .vsync(inf.vsync), .hsync(inf.hsync), .data_enable(inf.data_enable), 
        .cur_R(inf.cur_R), .cur_G(inf.cur_G), .cur_B(inf.cur_B),
        .resolution_pair_idx(inf.resolution_pair_idx),
        .X_factor(inf.X_factor), .Y_factor(inf.Y_factor), 
        .tar_width(inf.tar_width), .tar_height(inf.tar_height),
        .out_R(inf.out_R), .out_G(inf.out_G), .out_B(inf.out_B),
        .en_output(inf.en_output), .frame_done(inf.frame_done)
    );


    always #`HALF_PERIOD inf.clk = ~inf.clk;

    event done_reset;

    task automatic do_reset(integer unsigned hold_cycles = 5);
        inf.rst_n = 0;
        repeat(hold_cycles) @(posedge inf.clk);
        inf.rst_n = 1;
        -> done_reset;
    endtask

    
    task automatic gen_hsync();
        int unsigned total_lines = `VFRONT + `VSYNC + `VBACK + `SRC_HEIGHT;
        inf.hsync = '0;
        @(done_reset);

        repeat (total_lines) begin
            repeat(`HFRONT) @(posedge inf.clk);
            inf.hsync <= 'b1;
            repeat(`HSYNC) @(posedge inf.clk);
            inf.hsync <= '0;
            repeat(`HBACK) @(posedge inf.clk);

            repeat(`SRC_WIDTH) @(posedge inf.clk);
        end
    endtask


    semaphore order_lock;
    
    task automatic gen_vsync();
        inf.vsync = 0;
        order_lock.get(1);
        @(done_reset);

        repeat (`VFRONT+1) @(posedge inf.hsync);
        inf.vsync <= 1;
        repeat (`VSYNC) @(posedge inf.hsync);
        inf.vsync <= 0;
        repeat (`VBACK-1) @(posedge inf.hsync);

        order_lock.put(1);
        
    endtask




    task automatic drive_pixels();
        int unsigned sx, sy;
        inf.data_enable = 1'b0;    
        @(done_reset);

        order_lock.get(1);


        for (sy=0; sy<`SRC_HEIGHT; sy=sy+1) begin 
            @(posedge inf.hsync);
            repeat (`HBACK) @(posedge inf.clk);

            inf.data_enable <= 1'b1;
            for (sx=0; sx<`SRC_WIDTH; sx=sx+1) begin
                inf.cur_R <= source_frame.R_frame[sy*`SRC_WIDTH + sx];
                inf.cur_G <= source_frame.G_frame[sy*`SRC_WIDTH + sx];
                inf.cur_B <= source_frame.B_frame[sy*`SRC_WIDTH + sx];
                @(posedge inf.clk);
            end
            inf.data_enable <= 1'b0;
        end

        order_lock.put(1);

    endtask


    logic [7:0] output_buffer_R [0: (`TAR_WIDTH*`TAR_HEIGHT)-1];
    logic [7:0] output_buffer_G [0: (`TAR_WIDTH*`TAR_HEIGHT)-1];
    logic [7:0] output_buffer_B [0: (`TAR_WIDTH*`TAR_HEIGHT)-1];

    time frame_start, frame_end, frame_duration;
    

    bit FAIL_FLAG;
    int unsigned p_cnt;
    logic [7:0] golden_B, golden_G, golden_R;

    always_comb begin
        golden_R = golden_frame.R_frame[p_cnt];
        golden_G = golden_frame.G_frame[p_cnt];
        golden_B = golden_frame.B_frame[p_cnt];
    end


    event dut_done_process;
    event dut_start_output;
    task automatic monitor_and_check();
        p_cnt = 0;
        FAIL_FLAG = 0;
        @(done_reset);

        while (!inf.frame_done) begin
            @(posedge inf.clk);

            if (inf.en_output) begin
                output_buffer_R[p_cnt] <= inf.out_R;
                output_buffer_G[p_cnt] <= inf.out_G;
                output_buffer_B[p_cnt] <= inf.out_B;


                if (inf.out_R!==golden_R || inf.out_G!==golden_G || inf.out_B!==golden_B) begin
                    FAIL_FLAG = 1'b1;
                    $warning("[Error] output of DUT not match golden ref: p_cnt=%0d golden_R=%h, outR=%h, golden_G=%h, outG=%h, golden_B=%h, outB=%h",
                    p_cnt, golden_R, inf.out_R, golden_G, inf.out_G, golden_B, inf.out_B);
                end

                p_cnt <= (p_cnt+1);
                // $display("[Info] polyphase downscaler processed %d pixels", (p_cnt+1));

            end
        end
        if (p_cnt!=`TAR_HEIGHT*`TAR_WIDTH) begin
            $display("[Error] %0dx%0d_%0dx%0d FAILED", `SRC_WIDTH, `SRC_HEIGHT, `TAR_WIDTH, `TAR_HEIGHT);
        end
        -> dut_done_process;
    endtask

    task record_timing();
        real frame_rate;
        fork 
            begin: start_frame
                forever begin
                    @(posedge inf.clk);
                    if (inf.en_output) begin
                        frame_start = $time;
                        $display("[Info] START frame %t", frame_start);
                        disable start_frame;
                    end
                end
            end
        join_any
        
        @(dut_done_process);
        if (p_cnt != `TAR_WIDTH*`TAR_HEIGHT) 
            $warning("[Error] wrong output count ");
        else begin
            frame_end = $time;
            $display("[Info] END frame %t", frame_end);
        end

        frame_duration = frame_end-frame_start;
        frame_rate = 1e12/frame_duration;
        $display("frame duration %t ps", frame_duration);
        $display("frame rate %.3f fps", frame_rate);
    endtask

    int unsigned out_idx;
    task write_outputs();
        out_idx = 0;
        @(done_reset);
    
        while (!inf.frame_done) begin
            @(posedge inf.clk);
            if (p_cnt==out_idx+1) begin
                target_frame.write_pixel("R", output_buffer_R[out_idx]);
                target_frame.write_pixel("G", output_buffer_G[out_idx]);
                target_frame.write_pixel("B", output_buffer_B[out_idx]);
                out_idx <= out_idx+1;
                if ((out_idx+1)%`TAR_WIDTH==0) begin
                    target_frame.write_string("\n");
                    // $display("[Info] Output %0d row to monitor...", (out_idx+1)/`TAR_WIDTH);
                end
            end
        end

        $display("[Info] all pixels in output_buffers has been written to files.");
        target_frame.flush_close();
    endtask


    initial begin
        order_lock = new(1);
        inf.clk = 1'b1;

        load_data();
        `ifdef VALIDATION_MODE
            Xgolden_load_data();
            load_rom_content();
        `endif 

        fork
            do_reset();
            gen_hsync();
            gen_vsync();
            drive_pixels();
            record_timing();
            `ifdef VALIDATION_MODE
                Xmonitor_and_check();
                Xwrite_output();
                ref_Xrom_address();
                ref_Yrom_address();
                check_rom_address();
            `endif 
            monitor_and_check();
            write_outputs();
        join


        if (FAIL_FLAG)
            $display("[Error] VERIFICATION FAILED");
        else
            $display("VERILOG_OUTPUT_DONE");
        $finish;
    end

    `ifdef DUMP_WAVE
        initial begin
            $dumpfile("wave.vcd");
            $dumpvars();
        end
    `endif 


endmodule
