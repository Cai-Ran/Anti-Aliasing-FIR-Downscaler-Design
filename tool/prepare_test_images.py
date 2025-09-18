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
TOLERANCE = 0.35        # Allow up to 35% size difference when checking closeness
LIB = "pillow"          #["pyvips", "opencv", "skimage", "pillow"]
PREFIX = "batch"

YOUR_PIC_FOLDER = "../your_picture_folder"
SOURCE_PIC_FOLDER = "../source_pictures/"
TEST_OUTPUT_DIR = f"../test_pictures_{LIB}/"

BASENAME_TXT = f"../tool/picture_basename.txt"

# -------------------------------------------------------------------
# Utilities
# -------------------------------------------------------------------

def rename_images_by_size(prefix: str, src_dir: str, dst_dir: str) -> Tuple[List[str], List[str]]:
    """
    Rename image files to a formated naming style by file size order and move them to a new folder.
    """

    files = [f for f in os.listdir(src_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
    files.sort(key=lambda f: os.path.getsize(os.path.join(src_dir, f)))

    renamed_files, basenames = [], []
    for idx, filename in enumerate(files, start=1):
        ext = os.path.splitext(filename)[-1]
        basename = f"{prefix}_{idx}"
        new_name = f"{basename}{ext}"

        shutil.copy(os.path.join(src_dir, filename),
                    os.path.join(dst_dir, new_name))

        renamed_files.append(new_name)
        basenames.append(basename)

    return renamed_files, basenames


def get_file_names(new_folder_path:str) -> Tuple[List[str], List[str]]:
    """
    Get the full names and base names of all files in a folder.
    (use this when your already created the test image set, but you lost basename_txt)
    """

    file_names, base_names = [], []
    for fname in os.listdir(new_folder_path):
        base, _ = os.path.splitext(fname)
        file_names.append(fname)   
        base_names.append(base)    
    return file_names, base_names

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
                 width: int, height: int,
                 validate: bool = True, check_tolerance: bool = False) -> bool:
    """
    Resize the image to given dimensions and save it as BMP.
    """
    if not os.path.exists(input_path):
        return False

    try:
        if lib=="pillow":
            with Image.open(input_path) as img:
                if check_tolerance:
                    if img.width==width and img.height==height:
                        img.save(output_path, format="BMP")

                    else:
                        if abs(width-img.width)<=img.width*TOLERANCE and abs(height-img.height)<=img.height*TOLERANCE:
                            resized_img = img.resize((width, height), Image.LANCZOS)
                            resized_img.save(output_path, format="BMP")
                        else:
                            return False

                else:
                    resized_img = img.resize((width, height), Image.LANCZOS)
                    resized_img.save(output_path, format="BMP")
                    
        elif lib=="opencv":
            img = cv2.imread(input_path, cv2.IMREAD_UNCHANGED)
            if check_tolerance:
                h, w = img.shape[:2]
                if abs(width-w)<=w*TOLERANCE and abs(height-h)<=h*TOLERANCE:
                    resized_img = cv2.resize(img, (width, height), interpolation=cv2.INTER_LANCZOS4)
                    cv2.imwrite(output_path, resized_img)
                else:
                    return False
                    
            else:
                resized_img = cv2.resize(img, (width, height), interpolation=cv2.INTER_LANCZOS4)
                cv2.imwrite(output_path, resized_img)
                
        # elif lib=="skimage":
        #     img = io.imread(input_path)
        #     resized_image = transform.resize(img, (height, width), order=3,  
        #                                         mode='reflect',  
        #                                         preserve_range=True,  
        #                                         anti_aliasing=True,  
        #                                         anti_aliasing_sigma=None  
        #                                     )
        #     io.imsave(output_path, (resized_image * 255).astype("uint8"))

        else:
            raise ValueError(f"Error: Invalid library specified - {lib}")
        
        if validate:
            return validate_bmp(output_path)
        else:
            return True
        
    except Exception as e:
        logging.error(f"Error: resizing image: {e}")
        return False


# -------------------------------------------------------------------
# Pipeline Steps
# ------------------------------------------------------------------- 

def create_test_images(src_dir: str, dst_dir: str, lib: str,
                       basenames: List[str], filenames: List[str],
                       sizes: List[Tuple[int, int]], basename_txt_path: str):
    """
    Generate test images at multiple sizes and record valid basenamees.
    """

    valid_basename_set = set()
    tasks, order = [], []

    for i in tqdm(range(len(basenames)), desc="gen_test_img"):
        input_path = os.path.join(src_dir, filenames[i])
        for w, h in sizes:
            output_path = os.path.join(dst_dir, f"test_{w}x{h}_{basenames[i]}.bmp")
            tasks.append((lib, input_path, output_path, w, h, True, True))
            order.append(basenames[i])

    with multiprocessing.Pool(NUM_CPU) as pool:
        results = pool.starmap(resize_image, tasks)

    for i, success in enumerate(results):
        if success:
            valid_basename_set.add(order[i])
    with open(basename_txt_path, "w", encoding="utf-8") as txt_file:     
        for basename in valid_basename_set:
            txt_file.write(basename + "\n")
    
    return



if __name__ == "__main__":
    os.makedirs("../log/", exist_ok=True)
    logfile = f"../log/prepare_test_img.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[logging.FileHandler(logfile), logging.StreamHandler(sys.stdout)],
    )

    ''' rename & create test images '''
    os.makedirs(SOURCE_PIC_FOLDER, exist_ok=True)
    name_list, basename_list = rename_images_by_size(PREFIX, YOUR_PIC_FOLDER, SOURCE_PIC_FOLDER)

    os.makedirs(TEST_OUTPUT_DIR, exist_ok=True)
    all_sizes = [
        (1920, 1080),
        (2560, 1440),
        (3840, 2160),
        (4096, 2160)
    ]
    if os.path.exists(BASENAME_TXT):
        os.remove(BASENAME_TXT)

    create_test_images(SOURCE_PIC_FOLDER, TEST_OUTPUT_DIR, LIB,
                       basename_list, name_list, all_sizes, BASENAME_TXT)
