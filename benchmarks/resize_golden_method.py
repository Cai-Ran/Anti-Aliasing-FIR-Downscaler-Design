import os
import sys
import struct
import shutil
import logging
import multiprocessing
from PIL import Image
import cv2
# from skimage import io, transform

from tqdm import tqdm
from typing import Tuple, List



# -------------------------------------------------------------------
# Global Config
# -------------------------------------------------------------------

NUM_CPU = max(1, os.cpu_count() or 8)
LIB = "pillow"    

INPUT_IMG_DIR   = f"../test_pictures_{LIB}/"
OUTPUT_IMG_DIR  = f"../output_goldmethod_{LIB}/"
BASENAME_TXT    = f"../tool/picture_basename.txt"
LOG_FILE        = "../log/run_goldenmethod.log" 


# -------------------------------------------------------------------
# Resize
# -------------------------------------------------------------------

def validate_bmp(output_path:str) -> bool:
    """
    Validate whether the given BMP file is a valid 24-bit BMP.
    """

    try:
        # Verify BMP bit depth
        with open(output_path, "rb") as f:
            header = f.read(128)

        if header[0:2] != b"BM":
            raise ValueError(f"Error: Incorrect BMP signature - {output_path}")

        info_size = struct.unpack("<i", header[14:18])[0]
        if info_size not in [40, 52, 56, 108, 124]:
            raise ValueError(
                f"Unexpected DIB header size {info_size} - {output_path}")

        bpp = struct.unpack("<H", header[28:30])[0]
        if bpp != 24:
            raise ValueError(f"Error: Expected 24-bit BMP, but got {bpp}-bit - {output_path}")
        
        return True
        
    except Exception as e:
        logging.error(f"Error: BMP file {e} - {output_path}")
        return False


def resize_image(lib: str, input_path: str, output_path: str,
                 width: int, height: int, validate: bool = True) -> bool:
    """
    Resize the image to given dimensions and save it as BMP.
    """
    if not os.path.exists(input_path):
        return False

    try:
        if lib=="pillow":
            with Image.open(input_path) as img:
                resized_img = img.resize((width, height), Image.LANCZOS)
                resized_img.save(output_path, format="BMP")
                    
        elif lib=="opencv":
            img = cv2.imread(input_path, cv2.IMREAD_UNCHANGED)
            resized_img = cv2.resize(img, (width, height), interpolation=cv2.INTER_LANCZOS4)
            cv2.imwrite(output_path, resized_img)

        else:
            raise ValueError(f"Error: Invalid library specified - {lib}")
        
        if validate:
            return validate_bmp(output_path)
        else:
            return True
        
    except Exception as e:
        logging.error(f"Error: resizing image: {e}")
        return False



def create_golden_images(src_dir: str, dst_dir: str, lib: str,
                         basename_txt: str,
                         input_sizes: List[Tuple[int, int]],
                         output_sizes: List[Tuple[int, int]]) -> None:
    with open(basename_txt, "r", encoding="utf-8") as f:
        basenames = [line.strip() for line in f]

    tasks = []
    for base in tqdm(basenames, desc="process_lanczos"):
        for (old_w, old_h) in input_sizes:
            input_path = os.path.join(src_dir, f"test_{old_w}x{old_h}_{base}.bmp")
            for (new_w, new_h) in output_sizes:
                if (old_w, old_h) == (new_w, new_h):
                    continue
                if not ((old_w / new_w) > 2 and (old_h / new_h) > 2):
                    # logging.info(f"[skip] {old_w}x{old_h} -> {new_w}x{new_h}")
                    continue
                output_path = os.path.join(
                    dst_dir, f"Lanczos_{old_w}x{old_h}_{new_w}x{new_h}_{base}.bmp"
                )
                tasks.append((lib, input_path, output_path, new_w, new_h, True))

    with multiprocessing.Pool(NUM_CPU) as pool:
        pool.starmap(resize_image, tasks)

    return




if __name__ == "__main__":
    os.makedirs("../log/", exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stdout)],
    )


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
        (1360, 768),
        (1440, 900),
        (1600, 900),
    ]

    os.makedirs(OUTPUT_IMG_DIR, exist_ok=True)
    create_golden_images(INPUT_IMG_DIR, OUTPUT_IMG_DIR, LIB,
                         BASENAME_TXT, input_sizes, output_sizes)
