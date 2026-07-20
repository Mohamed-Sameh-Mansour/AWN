"""
Azure OCR Service
خدمة استخراج النصوص من الصور باستخدام Azure
"""

import requests
import time
from typing import Optional


def extract_text_with_azure(
    image_bytes: bytes,
    azure_key: str,
    azure_endpoint: str,
    timeout: int = 10
) -> Optional[str]:
    """
    استخراج النصوص من الصورة باستخدام Azure Computer Vision
    Extract text from image using Azure Computer Vision
    
    Args:
        image_bytes: Binary image data
        azure_key: Azure OCR API key
        azure_endpoint: Azure OCR endpoint URL
        timeout: Maximum polling time in seconds (default: 10)
    
    Returns:
        Extracted text or None if failed
    
    Raises:
        Exception: If Azure service returns error
    """
    
    if not azure_key or not azure_endpoint:
        raise Exception("Azure credentials not configured")
    
    # Step 1: Send image to Azure for analysis
    analyze_url = f"{azure_endpoint}/vision/v3.2/read/analyze"
    headers = {
        "Ocp-Apim-Subscription-Key": azure_key,
        "Content-Type": "application/octet-stream"
    }
    
    try:
        response = requests.post(analyze_url, headers=headers, data=image_bytes)
    except requests.RequestException as e:
        raise Exception(f"Azure connection failed: {str(e)}")
    
    if response.status_code != 202:
        raise Exception(f"Azure error: {response.text}")
    
    # Step 2: Get operation result URL for polling
    result_url = response.headers.get("Operation-Location")
    if not result_url:
        raise Exception("Azure response missing Operation-Location header")
    
    poll_headers = {"Ocp-Apim-Subscription-Key": azure_key}
    
    # Step 3: Poll for results with 10-second timeout
    start_time = time.time()
    max_attempts = 10
    attempt = 0
    
    while attempt < max_attempts:
        elapsed_time = time.time() - start_time
        
        # Check timeout
        if elapsed_time > timeout:
            raise Exception("Azure connection timeout: Operation did not complete within 10 seconds")
        
        try:
            result = requests.get(result_url, headers=poll_headers).json()
        except requests.RequestException as e:
            raise Exception(f"Azure polling failed: {str(e)}")
        
        status = result.get("status", "").lower()
        
        if status == "succeeded":
            # Successfully processed - extract text
            lines = []
            
            analyze_result = result.get("analyzeResult", {})
            read_results = analyze_result.get("readResults", [])
            
            for page in read_results:
                page_lines = page.get("lines", [])
                for line in page_lines:
                    text = line.get("text", "")
                    if text:
                        lines.append(text)
            
            return "\n".join(lines)
        
        elif status == "failed":
            raise Exception("Azure failed to process image")
        
        elif status == "notstarted" or status == "running":
            # Still processing, wait before polling again
            time.sleep(1)
            attempt += 1
        
        else:
            raise Exception(f"Unknown Azure status: {status}")
    
    # Timeout reached after max attempts
    raise Exception("Azure connection timeout: Maximum polling attempts exceeded")


def extract_text_with_confidence(
    image_bytes: bytes,
    azure_key: str,
    azure_endpoint: str,
    timeout: int = 10
) -> dict:
    """
    Extract text and calculate average confidence score
    استخراج النصوص مع حساب درجة الثقة
    
    Args:
        image_bytes: Binary image data
        azure_key: Azure OCR API key
        azure_endpoint: Azure OCR endpoint URL
        timeout: Maximum polling time in seconds
    
    Returns:
        Dictionary with 'text' and 'confidence' keys
    """
    
    if not azure_key or not azure_endpoint:
        raise Exception("Azure credentials not configured")
    
    # Send image for analysis
    analyze_url = f"{azure_endpoint}/vision/v3.2/read/analyze"
    headers = {
        "Ocp-Apim-Subscription-Key": azure_key,
        "Content-Type": "application/octet-stream"
    }
    
    try:
        response = requests.post(analyze_url, headers=headers, data=image_bytes)
    except requests.RequestException as e:
        raise Exception(f"Azure connection failed: {str(e)}")
    
    if response.status_code != 202:
        raise Exception(f"Azure error: {response.text}")
    
    result_url = response.headers.get("Operation-Location")
    if not result_url:
        raise Exception("Azure response missing Operation-Location header")
    
    poll_headers = {"Ocp-Apim-Subscription-Key": azure_key}
    
    # Poll for results
    start_time = time.time()
    max_attempts = 10
    attempt = 0
    
    while attempt < max_attempts:
        elapsed_time = time.time() - start_time
        
        if elapsed_time > timeout:
            raise Exception("Azure connection timeout: Operation did not complete within 10 seconds")
        
        try:
            result = requests.get(result_url, headers=poll_headers).json()
        except requests.RequestException as e:
            raise Exception(f"Azure polling failed: {str(e)}")
        
        status = result.get("status", "").lower()
        
        if status == "succeeded":
            lines = []
            total_confidence = 0.0
            word_count = 0
            
            for page in result["analyzeResult"]["readResults"]:
                for line in page["lines"]:
                    lines.append(line.get("text", ""))
                    # Calculate total confidence from words
                    for word in line.get("words", []):
                        total_confidence += word.get("confidence", 0.0)
                        word_count += 1
            
            # Calculate the average confidence
            avg_confidence = round(total_confidence / word_count, 2) if word_count > 0 else 0.0
            
            return {
                "extracted_text": "\n".join(lines),
                "confidence": avg_confidence,
                "line_count": len(lines)
            }
        
        elif status == "failed":
            raise Exception("Azure failed to process image")
        
        elif status == "notstarted" or status == "running":
            time.sleep(1)
            attempt += 1
        
        else:
            raise Exception(f"Unknown Azure status: {status}")
    
    raise Exception("Azure connection timeout: Maximum polling attempts exceeded")
