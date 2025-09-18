# create clock constraints      unit of period: ns
create_clock -name PixelClock -period 13.468 -waveform {0 6.734} [get_ports {clk}]      
set_clock_uncertainty -from [get_clocks {PixelClock}] -to [get_clocks {PixelClock}] -setup 0.2          
set_clock_uncertainty -from [get_clocks {PixelClock}] -to [get_clocks {PixelClock}] -hold 0.05

# asynchronous reset / static config
set_false_path -from [get_ports {rst_n {resolution_pair_idx[*]} {X_factor[*]} {Y_factor[*]} {tar_width[*]} {tar_height[*]}}]

# the timing constraint from input component for DUT input register; default -max                              DUT INPUT REGISTER
set_input_delay -clock PixelClock -max 2.2             [get_ports {vsync hsync data_enable {cur_R[*]} {cur_G[*]} {cur_B[*]}}]
set_input_delay -clock PixelClock -min 1.0  -add_delay [get_ports {vsync hsync data_enable {cur_R[*]} {cur_G[*]} {cur_B[*]}}]

# the timing constraint of output component input register                                           NEXT COMPONENT INPUT REGISTER
set_output_delay -clock PixelClock -max 4             [get_ports {en_output frame_done {out_R[*]} {out_G[*]} {out_B[*]}}]
set_output_delay -clock PixelClock -min 1  -add_delay [get_ports {en_output frame_done {out_R[*]} {out_G[*]} {out_B[*]}}]
