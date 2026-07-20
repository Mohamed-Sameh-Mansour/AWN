"""
Pydantic Response Models
نماذج الردود
"""

from pydantic import BaseModel
from typing import List, Optional

class ObjectDetected(BaseModel):
    """نموذج كائن مكتشف"""
    name_ar: str
    name_en: str
    confidence: float
    distance: str
    position: str

class ObjectDetectionResponse(BaseModel):
    """نموذج رد التعرف على الأشياء"""
    objects: List[ObjectDetected]
    count: int
    scene_description_ar: str
    scene_description_en: str

class TextReaderResponse(BaseModel):
    """نموذج رد قراءة النصوص"""
    text: str
    confidence: float
    language: str
    word_count: int

class DistanceResponse(BaseModel):
    """نموذج رد تقدير المسافات"""
    type: str
    distance_meters: float
    warning: bool
    message_ar: str
    message_en: str

class AzureOCRResponse(BaseModel):
    """نموذج رد استخراج النصوص من Azure"""
    success: bool
    extracted_text: str
    confidence: float
    line_count: int
    message_ar: str
    message_en: str

