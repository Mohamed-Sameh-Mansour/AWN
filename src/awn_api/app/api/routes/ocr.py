"""
OCR Routes
مسارات استخراج النصوص
"""

from fastapi import APIRouter, File, UploadFile, HTTPException
from io import BytesIO
from app.config import settings
from app.services.azure_ocr_service import extract_text_with_confidence
from app.services.gemini_service import format_ocr_text_for_blind
from app.api.schemas.responses import AzureOCRResponse

router = APIRouter(prefix="/api/v1", tags=["OCR"])


@router.post("/extract-text", response_model=dict)
async def extract_text(image: UploadFile = File(...)):
    """
    استخراج النصوص من الصورة باستخدام Azure OCR
    Extract text from image using Azure Computer Vision
    
    Parameters:
    - image: Image file (multipart/form-data)
    
    Returns:
    - extracted_text: The recognized text
    - confidence: Average confidence score (0-1)
    - line_count: Number of text lines detected
    """
    
    # Check if Azure credentials are configured
    if not settings.AZURE_OCR_KEY or not settings.AZURE_OCR_ENDPOINT:
        raise HTTPException(
            status_code=503,
            detail="Azure OCR service not configured. Please set AZURE_OCR_KEY and AZURE_OCR_ENDPOINT in .env"
        )
    
    # Validate file format
    if image.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(
            status_code=400,
            detail="Invalid image format. Supported formats: JPEG, PNG"
        )
    
    try:
        # Read image bytes
        image_bytes = await image.read()
        
        # Validate file size
        if len(image_bytes) > settings.MAX_IMAGE_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"File size exceeds maximum limit of {settings.MAX_IMAGE_SIZE / 1024 / 1024:.0f}MB"
            )
        
        # Process with Azure OCR
        result = extract_text_with_confidence(
            image_bytes=image_bytes,
            azure_key=settings.AZURE_OCR_KEY,
            azure_endpoint=settings.AZURE_OCR_ENDPOINT,
            timeout=settings.AZURE_OCR_TIMEOUT
        )
        
        # Format the raw text for blind users using Gemini
        raw_text = result["extracted_text"]
        formatted_text = format_ocr_text_for_blind(raw_text)
        
        # Return response
        return {
            "success": True,
            "data": {
                "extracted_text": raw_text,
                "formatted_audio_text": formatted_text,
                "confidence": result["confidence"],
                "line_count": result["line_count"]
            },
            "message_ar": "تم استخراج النصوص بنجاح من الصورة",
            "message_en": "Text successfully extracted from image"
        }
    
    except Exception as e:
        error_message = str(e)
        
        # Return error response
        return {
            "success": False,
            "data": None,
            "message_ar": f"فشل استخراج النصوص: {error_message}",
            "message_en": f"Failed to extract text: {error_message}"
        }
