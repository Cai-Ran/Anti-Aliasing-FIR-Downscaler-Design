import os
import sys
import time
import logging
from logging.handlers import QueueHandler, QueueListener
# from tqdm import tqdm
from typing import Tuple, Optional
import numpy as np
import cv2
import pandas as pd
from skimage.metrics import structural_similarity 

import multiprocessing
from multiprocessing import Queue


# -------------------------------------------------------------------
# Global Config
# -------------------------------------------------------------------

NUM_CPU = max(1, os.cpu_count() or 8)
LIB = "pillow"          #["pyvips", "opencv", "skimage", "pillow"]

BASENAME_TXT = "../tool/picture_basename.txt"
GOLDEN_DIR   = f"../output_goldmethod_{LIB}/"
BILINEAR_DIR = f"../output_bilinear_{LIB}/"
NEAREST_DIR  = f"../output_nearest_{LIB}/"
FIR_DIR      = f"../output_FIR_{LIB}/"
RESULT_DIR   = "../results/"


# -------------------------------------------------------------------
# Metrics
# -------------------------------------------------------------------

def calculate_psnr(original_img:np.ndarray, test_image:np.ndarray) -> float:
    
    mse = np.mean((original_img - test_image)**2)
    if (mse==0):
        # return float('inf')       #inf effects the dataset to follow normal distribution
        return 100
    
    max_pixel_value = 255.0
    psnr = 20 * np.log10(max_pixel_value / np.sqrt(mse))
    
    return psnr


def calculate_ssim(original_img:np.ndarray, test_image:np.ndarray) -> Tuple[float, float]:
    gray_original_img = cv2.cvtColor(original_img, cv2.COLOR_BGR2GRAY)
    gray_test_image   = cv2.cvtColor(test_image, cv2.COLOR_BGR2GRAY)
    ssim_gray = structural_similarity(gray_original_img, gray_test_image, data_range=255)
    
    ssim_rgb = structural_similarity(original_img, test_image, data_range=255, channel_axis=-1)
    
    return ssim_gray, ssim_rgb



def load_image(image_path:str) -> Optional[np.ndarray]:
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Skip: {image_path}")

    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(f"Error: Cannot read image {image_path}")
    return image


def task_unit(OLD_X:int, OLD_Y:int, NEW_X:int, NEW_Y:int, basename:str, lib:str, 
              gold_img_dir:str, nea_output_dir:str, bil_output_dir:str, FIR_output_dir:str) -> Optional[Tuple[list, list]]:


    if OLD_X>0 and OLD_Y>0 and NEW_X>0 and NEW_Y>0:
        scaleX = NEW_X/OLD_X
        scaleY = NEW_Y/OLD_Y
    else:
        logging.error(f"Error: invalid resolution, {OLD_X}x{OLD_Y} -> {NEW_X}x{NEW_Y}")
        return None

    src_name = f"test_{OLD_X}x{OLD_Y}_" + basename + ".bmp"
    test_name = f"{OLD_X}x{OLD_Y}_"+f"{NEW_X}x{NEW_Y}_"+ basename + ".bmp"

    goldmethod_name     = "Lanczos_"+test_name
    Nearest_name        = "Nearest_"+test_name
    Bilinear_name       = "Bilinear_"+test_name
    FIR_name            = test_name
    Nearest_path        = os.path.join(nea_output_dir, Nearest_name)
    Bilinear_path   =   os.path.join(bil_output_dir, Bilinear_name)
    goldmethod_path     = os.path.join(gold_img_dir, goldmethod_name)
    FIR_path            = os.path.join(FIR_output_dir, FIR_name)

    try:
        goldmethod_img      = load_image(goldmethod_path)
        FIR_img             = load_image(FIR_path)
        Nearest_img     = load_image(Nearest_path)
        Bilinear_img    = load_image(Bilinear_path)          
    except FileNotFoundError as e:
        logging.info(f"[Info]: {e}")
        return None
    except ValueError as e:
        logging.error(e)
        return None
   
    Nearest_psnr = calculate_psnr(goldmethod_img, Nearest_img)
    ssim_nearest_gray, ssim_nearest_rgb = calculate_ssim(goldmethod_img, Nearest_img)
   
    Bilinear_psnr = calculate_psnr(goldmethod_img, Bilinear_img)
    ssim_bilinear_gray, ssim_bilinear_rgb = calculate_ssim(goldmethod_img, Bilinear_img)
    
    FIR_psnr = calculate_psnr(goldmethod_img, FIR_img)
    ssim_FIR_gray, ssim_FIR_rgb = calculate_ssim(goldmethod_img, FIR_img)

    task_result = [
                src_name, goldmethod_name, 
                OLD_X, OLD_Y, NEW_X, NEW_Y, 
                scaleX, scaleY,
                Nearest_psnr,       Bilinear_psnr,      FIR_psnr,    
                ssim_nearest_gray,  ssim_bilinear_gray, ssim_FIR_gray,
                ssim_nearest_rgb,   ssim_bilinear_rgb,  ssim_FIR_rgb,
                basename, 
                Nearest_name, Bilinear_name, FIR_path
            ]
    
    subject = f"{scaleX:.8f}_{scaleY:.8f}_" + basename

                                
    return task_result



def calculate_metrics(input_sizes:list, output_sizes:list, basename_list:list, lib:str,
                      golden_img_dir:str, nea_output_dir:str, bil_output_dir:str, FIR_output_dir:str,
                      result_path:str, log_queue: Queue) -> pd.DataFrame:
    
    results = []
    task_param_list = []

    for OLD_X, OLD_Y in input_sizes:
        for NEW_X, NEW_Y in output_sizes:
            if ((OLD_X, OLD_Y)==(NEW_X, NEW_Y)):
                continue
            if not ((OLD_X/NEW_X)>2 and (OLD_Y/NEW_Y)>2):
                    logging.info(f"[Info]: skipping {OLD_X}x{OLD_Y} -> {NEW_X}x{NEW_Y}")
                    continue
            for basename in basename_list:
                task_param = (OLD_X, OLD_Y, NEW_X, NEW_Y, basename, lib, golden_img_dir, nea_output_dir, bil_output_dir, FIR_output_dir)
                task_param_list.append(task_param)
            

    ## slower
    # with multiprocessing.Pool(processes=NUM_CPU) as multiprocess_pool:
    #     for task_return in tqdm(multiprocess_pool.imap_unordered(task_unit, task_param_list), total=len(task_param_list), desc="imap_unordered"):
    #         if task_return is not None:
    #             result_row, statistic_row = task_return
    #             results.append(result_row)
    #             statistic.extend(statistic_row)
    ## 23% faster 
    with multiprocessing.Pool(
        processes=NUM_CPU,
        initializer=setup_logger_queue,
        initargs=(log_queue,)
    ) as pool:
        task_return_list = pool.starmap_async(task_unit, task_param_list).get()

    for task_return in task_return_list:
        if task_return is not None:
            result_row = task_return
            results.append(result_row)
       
 
    df = pd.DataFrame(results, columns=[
        "source_file", "golden_file", 
        "OLD_X", "OLD_Y", "NEW_X", "NEW_Y", 
        "scaleX", "scaleY",
        "nearest_PSNR",       "bilinear_PSNR",       "FIR_PSNR",        
        "nearest_SSIM_gray",  "bilinear_SSIM_gray",  "FIR_SSIM_gray",     
        "nearest_SSIM_rgb",   "bilinear_SSIM_rgb",   "FIR_SSIM_rgb",    
        "basename",  
        "Nearest_file", "Bilinear_file", "FIR_file"
    ])
    df.to_excel(result_path, index=False, engine="openpyxl")
    

    return df


def setup_logger_queue(log_queue):
    queue_handler = QueueHandler(log_queue)
    root = logging.getLogger()
    root.setLevel(logging.DEBUG)
    root.handlers = []  
    root.addHandler(queue_handler)


def start_logger_listener(log_queue, logfile_path):
    stream_handler = logging.StreamHandler(sys.stdout) 
    file_handler = logging.FileHandler(logfile_path)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

    stream_handler.setFormatter(formatter)
    file_handler.setFormatter(formatter)

    listener = QueueListener(log_queue, stream_handler, file_handler)
    listener.start()
    return listener


if __name__ == "__main__":
    

    os.makedirs("../log/", exist_ok=True)
    logfile = f"../log/run_benchmark.log"

    log_queue = multiprocessing.Queue(-1)
    listener = start_logger_listener(log_queue, logfile)

    queue_handler = QueueHandler(log_queue)
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    root_logger.addHandler(queue_handler)

    start_run_time = time.time()
    logging.warning(f"Start running benchmark at {start_run_time}s")
    
    input_sizes = [
        (1920, 1080),
        (2560, 1440),
        (3840, 2160),
        (4096, 2160)
    ]

    output_sizes = [
        (640, 480),
        (720, 480),
        (720, 576),
        (800, 600),
        (1024, 768),
        (1152, 864),
        (1280, 720),
        (1280, 800),
        (1280, 960),
        (1280, 1024),
        (1360, 768),
        (1440, 900),
        (1600, 900),
    ]
    

    basename_list = []
    with open(BASENAME_TXT, "r", encoding="utf-8") as txt_file:     
        for line in txt_file:
            clean_line = line.strip()
            basename_list.append(clean_line)

    os.makedirs(RESULT_DIR, exist_ok=True)
    result_path     = os.path.join(RESULT_DIR, f"metric_results_{LIB}.xlsx")  

    df = calculate_metrics(input_sizes, output_sizes, basename_list, LIB,
                                    GOLDEN_DIR, NEAREST_DIR, BILINEAR_DIR, FIR_DIR,
                                    result_path, log_queue)           
                
     
    end_run_time = time.time()
    
    logging.warning(f"Total run time: {end_run_time-start_run_time}s")

    listener.stop()   
    