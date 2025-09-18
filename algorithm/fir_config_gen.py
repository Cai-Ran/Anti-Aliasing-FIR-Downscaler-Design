import math 
import os
import shutil
from typing import List, Tuple, Set, Optional
from contextlib import ExitStack
from pathlib import Path

INVALID_NUM = -1000

'''
Algorithm
'''

def not_symmetry_window(tar_list: List[int], Swindow: int, Lwindow: int, s_block_size: int) -> List[int]:
    window_start = 0
    record_window_list = []
    for t in tar_list:
        Swindow_center = window_start + Swindow/2.0
        dif_Swindow_center = abs(t-(Swindow_center))
        Lwindow_center = window_start + Lwindow/2.0
        dif_Lwindow_center = abs(t-(Lwindow_center))

        window_found = -1
        if (dif_Swindow_center > dif_Lwindow_center):
            window_found = Lwindow
        elif (dif_Swindow_center < dif_Lwindow_center):
            window_found = Swindow
        else:
            window_found = Lwindow #Lwindow==Swindow

        record_window_list.append(window_found)
        window_start += window_found

    if (sum(record_window_list)!=s_block_size):
        print("Error: window calculation wrong")
    
    return record_window_list


def find_num(S: int, x: int) -> Optional[List[int]]:
    #solve: S = a*(x) + b*(x+1) = (a+b)*x + b
    max_a = math.floor(S/x)
    max_b = math.floor(S/(x+1))
    found_list = []
    for a in range(0, max_a+1):
        if ((S-a*x)%(x+1)==0):
            b = int((S-a*x)/(x+1))
            found_list.append((a,b))

    return found_list if (len(found_list)!=0) else None


def find_window(tar_list: List[int], Swindow: int, Lwindow: int, s_block_size: int) -> List[int]:
    even_tar = (len(tar_list)%2 == 0)
    even_src = (s_block_size%2 == 0)
    flag_not_sym = False
    S = INVALID_NUM
    # 如果tar_list_len是奇數，最中間的tar_p一定會落在s_block的正中間
    # 如果tar_list_len是偶數，則s_block_len必定是奇數 (否則就不是最小block了)。tar_list_len跟s_block_len不可能同時偶數
    #even_src & odd_tar   odd_src & odd_tar
    if even_src or (not even_src and not even_tar):    # even src MUST odd_tar
        # if ((s_block_size-Lwindow)%2 == 0) and ((s_block_size-Swindow)%2 == 0):       //select small
        if ((s_block_size-Swindow)%2 == 0):
            S = int((s_block_size - Swindow)/2) 
            midle_window = Swindow
        elif ((s_block_size-Lwindow)%2 == 0):
            S = int((s_block_size - Lwindow)/2)
            midle_window = Lwindow

        tar_range = int((len(tar_list)-1)/2)
        
    else:   #not even_src and even_tar: #odd_src & even_tar 這種情況不會對稱
        flag_not_sym = True
        S = int((s_block_size-Lwindow-Swindow)/2)
        if S==0:
            return [Lwindow, Swindow]
        tar_range = int((len(tar_list)-1)/2)
    
    reverse_half_tar_list = list(reversed(tar_list[0:tar_range]))

    x = Swindow

    record_window_list  = []
    window_start = S

    for i in range(0, tar_range):
        Swindow_center = window_start - Swindow/2.0
        Lwindow_center = window_start - Lwindow/2.0

        if (Lwindow_center < 0 or Swindow_center < 0):
            break

        dif_Swindow_center = abs(reverse_half_tar_list[i]-(Swindow_center))
        dif_Lwindow_center = abs(reverse_half_tar_list[i]-(Lwindow_center))

        window_found = INVALID_NUM
        if (dif_Swindow_center > dif_Lwindow_center):
            window_start -= Lwindow
            ab_pair_list = find_num(window_start, x)
            if not ab_pair_list:
                window_found = Swindow
                window_start = (window_start+Lwindow)-Swindow
            else:
                window_found = Lwindow

        elif (dif_Swindow_center < dif_Lwindow_center):
            window_start -= Swindow
            ab_pair_list = find_num(window_start, x)
            if not ab_pair_list:
                window_found = Lwindow
                window_start = (window_start+Swindow)-Lwindow
            else:
                window_found = Swindow

        else:
            window_found = Lwindow #Lwindow==Swindow
            window_start -= Lwindow

        record_window_list.append(window_found)

    window_list = list(reversed(record_window_list))
    if (flag_not_sym):
        window_list.extend([Lwindow, Swindow])
    else:
        window_list.extend([midle_window])
    
    window_list.extend(record_window_list)

    return window_list


def windows_for_fir(tar_set: Set[Tuple[int, int]], res_minimum: List[int]) -> Tuple[List[int], List[int]]:

    min_src_x, min_src_y, min_tar_x, min_tar_y = res_minimum

    x_down_ratio = min_src_x/min_tar_x
    y_down_ratio = min_src_y/min_tar_y

    tar_list = list(tar_set)

    tar_x_tuple, tar_y_tuple = zip(*tar_list)

    tar_x_list = sorted(set(tar_x_tuple))
    tar_y_list = sorted(set(tar_y_tuple))

    x_Swindow = math.floor(x_down_ratio)
    y_Swindow = math.floor(y_down_ratio)
    x_Lwindow = math.ceil(x_down_ratio)
    y_Lwindow = math.ceil(y_down_ratio)
    
    x_block_size = min_src_x
    y_block_size = min_src_y

    x_record_window_list = find_window(tar_x_list, x_Swindow, x_Lwindow, x_block_size)
    if (sum(x_record_window_list)!=x_block_size):
        print(f"Error: Xwindow calculation wrong, x_block_size={x_block_size}, sum(x_record_window_list)={sum(x_record_window_list)}")

    y_record_window_list = find_window(tar_y_list, y_Swindow, y_Lwindow, y_block_size)
    if (sum(y_record_window_list)!=y_block_size):
        print(f"Error: Ywindow calculation wrong, y_block_size={y_block_size}, sum(y_record_window_list)={sum(y_record_window_list)}")
                    
    return (x_record_window_list, y_record_window_list)



def calculate_coordinates(srcX_block: int, srcY_block: int, tarX_block: int, tarY_block: int, draw_src: Set, draw_tar: Set) \
    -> Tuple[Tuple[int, int], Tuple[Tuple[int, int]]]:

    if ([srcX_block, srcY_block, tarX_block, tarY_block]==[1,1,1,1]): return

    HSR = tarX_block/srcX_block
    VSR = tarY_block/srcY_block

    if (srcX_block==1):
        tarX_block = tarX_block*2
        srcX_block = srcX_block*2

    if (srcY_block==1):
        tarY_block = tarY_block*2
        srcY_block = srcY_block*2    

    # scaling-UP: considering the blank area between repeating block
    srcX_bound = srcX_block if (tarX_block <=  srcX_block) else (srcX_block+1)
    srcY_bound = srcY_block if (tarY_block <=  srcY_block) else (srcY_block+1)
    tarX_bound = tarX_block if (tarX_block <=  srcX_block) else (tarX_block*2)
    tarY_bound = tarY_block if (tarY_block <=  srcY_block) else (tarY_block*2)

    for srcY in range(0, srcY_bound):
        for srcX in range(0, srcX_bound):

            srcX_co = (srcX+0.5)
            srcY_co = (srcY+0.5)
            
            draw_src.add((srcX_co, srcY_co))
            
            if (srcX!=0) and (srcY!=0):
                p5X_co,p5Y_co = srcX_co  , srcY_co
                p4X_co,p4Y_co = srcX_co-1, srcY_co
                p2X_co,p2Y_co = srcX_co  , srcY_co-1
                p1X_co,p1Y_co = srcX_co-1, srcY_co-1
                p3X_co,p3Y_co = srcX_co+1, srcY_co-1
                p7X_co,p7Y_co = srcX_co-1, srcY_co+1

            for tarY in range (0, tarY_bound):
                for tarX in range (0, tarX_bound):
                    tarX_co = (tarX+0.5) / HSR
                    tarY_co = (tarY+0.5) / VSR

                    if (srcX!=0) and (srcY!=0) \
                        and (tarX_co>=p1X_co) and (tarX_co<p5X_co) and (tarY_co>=p1Y_co) and (tarY_co<p5Y_co):
                            draw_tar.add((tarX_co, tarY_co))

                    elif (tarX_co <= srcX_bound) and (tarY_co <= srcY_bound): 
                        draw_tar.add((tarX_co, tarY_co))
                        
    return (draw_src, draw_tar)

    
def minimum_of_resolution(in_res_list: List[Tuple[int, int]], out_res_list: List[Tuple[int, int]]) \
    -> Tuple[List[Tuple[int, int, int, int]], List[Tuple[int, int, int, int]], List[Tuple[int, int]]]:

    res_minimum, res_original, GCD = [], [], []
    
    for i in reversed(in_res_list):
        for j in reversed(out_res_list):
            gcdX = math.gcd(i[0], j[0])
            gcdY = math.gcd(i[1], j[1])

            res_minimum.append([int(i[0]/gcdX), int(i[1]/gcdY), int(j[0]/gcdX), int(j[1]/gcdY)])
            res_original.append([i[0],i[1],j[0],j[1]])

            GCDx, GCDy = gcdX, gcdY
            if gcdX == 0 or gcdY == 0:
                print("original is MRB")
                continue

            if (int(i[0]/gcdX)==1) or (int(j[0]/gcdX)==1):
                GCDx = int(gcdX/2)
            if (int(i[1]/gcdY)==1) or (int(j[1]/gcdY)==1):
                GCDy = int(gcdY/2)

            GCD.append([GCDx, GCDy])
                                   
    return (res_minimum, res_original, GCD)

'''
Utils
'''

def prepare_dirs(fir_window_dir: str, rom_dir: str, golden_c_dir: str) -> None:

    if (os.path.exists(fir_window_dir)):
        shutil.rmtree(fir_window_dir)
    os.makedirs(fir_window_dir, exist_ok=False)

    keep_files = {"H_rom.mem", "N_rom.mem"}
    for filename in os.listdir(rom_dir):
        filepath = os.path.join(rom_dir, filename)
        if filename not in keep_files:
            if os.path.isfile(filepath) or os.path.islink(filepath):
                os.remove(filepath)
            elif os.path.isdir(filepath):
                shutil.rmtree(filepath)

    if (os.path.exists(golden_c_dir)):
        shutil.rmtree(golden_c_dir)
    os.makedirs(golden_c_dir, exist_ok=False)


def prepare_golden_c_windows(golden_c_dir: str, repeatX_double: bool, repeatY_double: bool, \
    x_record_window_list: List[int], y_record_window_list: List[int], \
    res_original_i: Tuple[int, int, int, int], gcd_i: Tuple[int, int]) -> None:

    golden_xwindow_path = golden_c_dir / f"{res_original_i[0]}x{res_original_i[1]}_{res_original_i[2]}x{res_original_i[3]}_Xwindow.txt"
    golden_ywindow_path = golden_c_dir / f"{res_original_i[0]}x{res_original_i[1]}_{res_original_i[2]}x{res_original_i[3]}_Ywindow.txt"

    with open(golden_xwindow_path, "w") as fx, open(golden_ywindow_path, "w") as fy:
        fx.write(f"{len(x_record_window_list)}\n")
        fx.write(f"{gcd_i[0] if not repeatX_double else gcd_i[0]*2}\n")
        fy.write(f"{len(y_record_window_list)}\n")
        fy.write(f"{gcd_i[1] if not repeatY_double else gcd_i[1]*2}\n")
        for xw in x_record_window_list:
            fx.write(f"{xw}\n")
        for yw in y_record_window_list:
            fy.write(f"{yw}\n")

    return


def load_spec_content(fr_config_path: str) -> List[Tuple]:
    spec_content=[]

    with open(fr_config_path, "r") as fr_config:
        for line in fr_config:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            contents = line.split()
            for idx, v in enumerate(contents):
                if (idx==3):
                    contents[idx] = float(contents[idx])
                else:
                    contents[idx] = int(contents[idx])
            spec_content.append(contents)

    return spec_content


def organize_timing_data(srcx:int, srcy:int, spec_content:List[Tuple]) \
    -> Optional[Tuple[int, int, int, int, int, int, int, int]]:
    frame_rate, pixel_clk, hfront, hsync, hback = 0, 0, 0, 0, 0
    for content in spec_content:
        if (srcx==content[0] and srcy==content[1]):
            frame_rate, pixel_clk, hfront, hsync, hback, vfront, vsync, vback = \
                content[2], content[3], content[4], content[5], content[6], content[7], content[8], content[9]
        else:
            continue
    
    if (pixel_clk!=0):
        half_period = math.floor(1/pixel_clk * (10**6) /2)      #ps
    else:
        return None
    
    return (frame_rate, half_period, hfront, hsync, hback, vfront, vsync, vback)


def prepare_rtl_config(fir_window_dir: str, repeatX_double: bool, repeatY_double: bool, X_down_ratio:int, Y_down_ratio:int,
        res_original_i: Tuple[int, int, int, int], res_minimum_i: Tuple[int, int, int, int], gcd_i: Tuple[int, int], \
        frame_rate:int, half_period:int, hfront:int, hsync:int, hback:int, vfront:int, vsync:int, vback:int,\
        MAP_IDX:int) -> None:
    
    defines = {
        "SRC_WIDTH":        res_original_i[0],
        "SRC_HEIGHT":       res_original_i[1],
        "TAR_WIDTH":        res_original_i[2],
        "TAR_HEIGHT":       res_original_i[3],
        "M_SRC_WIDTH":      res_minimum_i[0],
        "M_SRC_HEIGHT":     res_minimum_i[1],
        "M_TAR_WIDTH":      res_minimum_i[2],
        "M_TAR_HEIGHT":     res_minimum_i[3],
        "REPEAT_X":         gcd_i[0] if not repeatX_double else gcd_i[0]*2,
        "REPEAT_Y":         gcd_i[1] if not repeatY_double else gcd_i[1]*2,
        "X_DECIMATION_FACTOR":    math.ceil(X_down_ratio),
        "Y_DECIMATION_FACTOR":    math.ceil(Y_down_ratio),
        "FRAME_RATE":       frame_rate,
        "HALF_PERIOD":      half_period,
        "HFRONT":           hfront,
        "HSYNC":            hsync,
        "HBACK":            hback,
        "VFRONT":           vfront,
        "VSYNC":            vsync,
        "VBACK":            vback,
        "RESOLUTION_PAIR_IDX":      MAP_IDX
    }

    define_file_name = "{}x{}-{}x{}_define.v".format(res_original_i[0], res_original_i[1], res_original_i[2], res_original_i[3])
    with open(fir_window_dir / define_file_name, "w") as fd:
        for key, value in defines.items():
            fd.write(f"`define {key}\t\t\t\t\t\t\t{value}\n")

    return


def main(rom_dir:str, fir_window_dir:str, golden_c_dir:str,\
         res_minimum: List[Tuple[int, int, int, int]], res_original: List[Tuple[int, int, int, int]], GCD: List[Tuple[int, int]], 
         spec_content:List[Tuple]) -> None:

    X_ROM_IDX, Y_ROM_IDX = 0, 0
    MAP_IDX = 0
    # use ExitStack so we can keep *all* persistent files open in one context
    with ExitStack() as stack:
        X_rom_file = stack.enter_context(open(rom_dir/"Xwindow_rom.mem", "w"))
        Y_rom_file = stack.enter_context(open(rom_dir/"Ywindow_rom.mem", "w"))
        X_start_table_file = stack.enter_context(open(rom_dir/"X_start_table.mem", "w"))
        Y_start_table_file = stack.enter_context(open(rom_dir/"Y_start_table.mem", "w"))

        for i in range(0, len(res_minimum)):
            # skip 1:1 scaling or upscale pairs
            if (res_original[i][0],res_original[i][1]) == (res_original[i][2], res_original[i][3]):
                continue
            # skip up scale pairs
            X_down_ratio = res_minimum[i][0]/res_minimum[i][2]
            Y_down_ratio = res_minimum[i][1]/res_minimum[i][3]
            if (X_down_ratio<=2) or (Y_down_ratio<=2):
                continue
            
            # ---------------------------------- mapping target to source coordinate
            draw_src, draw_tar = set(), set()
            draw_src, draw_tar = calculate_coordinates(res_minimum[i][0],res_minimum[i][1],res_minimum[i][2],res_minimum[i][3], draw_src, draw_tar)
            # ---------------------------------- find windows
            x_record_window_list, y_record_window_list = windows_for_fir(draw_tar, res_minimum[i])
            if not x_record_window_list or not y_record_window_list:
                continue
            
            # ------------------------------------------- prepare rom data for rtl 
            # 1. rom start address table
            X_start_table_file.write(f"{X_ROM_IDX:X}\n")
            Y_start_table_file.write(f"{Y_ROM_IDX:X}\n")
            # 2. store window values in rom
            for xw in x_record_window_list:
                X_rom_file.write(f"{xw:X}\n")
            for yw in y_record_window_list:
                Y_rom_file.write(f"{yw:X}\n")
            
            # ------------------------------------------- 
            # if record_window_list contains only one element, the REPEAT should be double
            repeatX_double, repeatY_double = False, False
            if (len(x_record_window_list)*GCD[i][0] != res_original[i][2]):
                repeatX_double=True
            if (len(y_record_window_list)*GCD[i][1] != res_original[i][3]):
                repeatY_double=True

            # ------------------------------------------- prepare window data for c golden model
            prepare_golden_c_windows(golden_c_dir, repeatX_double, repeatY_double, \
                    x_record_window_list, y_record_window_list, \
                    res_original[i], GCD[i])
        
            # ------------------------------------------ prepare configs for rtl
            timing_config \
                = organize_timing_data(res_original[i][0], res_original[i][1], spec_content)
            if timing_config is None:
                raise RuntimeError(f"Error: SPEC RESOLUTION NOT FOUND: {res_original[i][0]}x{res_original[i][1]}")

            (frame_rate, half_period, hfront, hsync, hback, vfront, vsync, vback) = timing_config
            
            prepare_rtl_config(fir_window_dir, repeatX_double, repeatY_double, X_down_ratio, Y_down_ratio, \
                                res_original[i], res_minimum[i], GCD[i], \
                                frame_rate, half_period, hfront, hsync, hback, vfront, vsync, vback, \
                                MAP_IDX)
            
            X_ROM_IDX += len(x_record_window_list)
            Y_ROM_IDX += len(y_record_window_list)
            MAP_IDX += 1


        X_start_table_file.write(f"{X_ROM_IDX:X}\n")
        Y_start_table_file.write(f"{Y_ROM_IDX:X}\n")
        # record window value start idx in rom;
        #   rtl will read two value:
        #   start value= idx in config
        #   end value= (next value in start table)-1
        # the last value in start table is (last start_idx+corresponding length)

    return




if __name__ == "__main__":

    in_res_list = [
        [1920, 1080],
        [2560, 1440],
        [3840, 2160],
        [4096, 2160]
    ]

    out_res_list = [
        [640, 480], 
        [720, 480], 
        [720, 576], 
        [800, 600], 
        [1024, 768], 
        [1152, 864],
        [1280, 720], 
        [1280, 800], 
        [1280, 960],
        [1360, 768], 
        [1440, 900], 
        [1600, 900], 
    ]

    
    res_minimum, res_original, GCD = minimum_of_resolution(in_res_list, out_res_list)

    fir_window_dir = Path("../rtl_configs")
    rom_dir = Path("../rom_data")
    golden_c_dir = Path("../prepare_data/window")
    prepare_dirs(fir_window_dir, rom_dir, golden_c_dir)

    fr_config_path="./frame_rate_config.txt"
    spec_content = load_spec_content(fr_config_path)

    main(rom_dir, fir_window_dir, golden_c_dir,\
         res_minimum, res_original, GCD, spec_content)
