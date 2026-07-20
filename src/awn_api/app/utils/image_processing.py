"""
Image Processing Utilities
دوال معالجة الصور
"""

import cv2
import numpy as np
from PIL import Image
from typing import Tuple

def resize_image(image: Image.Image, max_width: int = 640, max_height: int = 480) -> Image.Image:
    """
    تغيير حجم الصورة مع الحفاظ على النسبة
    """
    width, height = image.size
    
    if width > max_width or height > max_height:
        ratio = min(max_width/width, max_height/height)
        new_width = int(width * ratio)
        new_height = int(height * ratio)
        image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    return image

def enhance_image(image: Image.Image) -> Image.Image:
    """
    تحسين جودة الصورة
    """
    img_array = np.array(image)
    
    # Convert to LAB
    lab = cv2.cvtColor(img_array, cv2.COLOR_RGB2LAB)
    l, a, b = cv2.split(lab)
    
    # Apply CLAHE
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
    l = clahe.apply(l)
    
    # Merge and convert back
    enhanced = cv2.merge([l, a, b])
    enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2RGB)
    
    return Image.fromarray(enhanced)

def validate_image(image: Image.Image) -> Tuple[bool, str]:
    """
    التحقق من صلاحية الصورة
    """
    try:
        if image.size[0] < 50 or image.size[1] < 50:
            return False, "Image too small"
        
        if image.mode not in ['RGB', 'RGBA', 'L']:
            return False, "Invalid image mode"
        
        return True, "Valid"
    
    except Exception as e:
        return False, str(e)
