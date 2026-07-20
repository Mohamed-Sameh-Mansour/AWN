import os
import base64
import io
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from groq import Groq
from PIL import Image

app = FastAPI(title="AWN - Spatial Awareness Service")

# هنا يقرأ المفتاح تلقائياً من إعدادات سيرفر Koyeb السحابي بأمان أو يستخدم رمز أمان مؤقت
client = Groq(api_key=os.environ.get("GROQ_API_KEY", "YOUR_API_KEY_HERE"))

@app.post("/analyze-image/")
async def analyze_image(file: UploadFile = File(...)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File provided is not an image.")

    try:
        image_bytes = await file.read()

        with Image.open(io.BytesIO(image_bytes)) as img:
            rgb_img = img.convert("RGB")
            buffer = io.BytesIO()
            rgb_img.save(buffer, format="JPEG")
            base64_image = base64.b64encode(buffer.getvalue()).decode('utf-8')

        prompt = (
            "أنت مساعد ذكي مخصص لمساعدة الأشخاص المكفوفين. انظر إلى هذه الصورة واشرح ما يوجد فيها "
            "بدقة وبساطة شديدة في جملتين أو ثلاث جمل كحد أقصى. ركز تماماً على الأشياء القريبة من المستخدم "
            "والعوائق المحتملة. يجب أن تكون الإجابة باللغة العربية الفصحى المبسطة."
        )

        completion = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}
                        }
                    ]
                }
            ],
            temperature=0.5,
            max_completion_tokens=1024,
        )

        ai_description = completion.choices[0].message.content
        return JSONResponse(content={"description": ai_description}, status_code=200)

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)