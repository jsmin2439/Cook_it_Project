import uvicorn
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import tempfile
import shutil
import os
import logging
from ultralytics import YOLO
from typing import Dict, List, Optional
from pathlib import Path

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["POST", "OPTIONS"],
    allow_headers=["*"],
)

# YOLO 모델 로드 함수
def load_model():
    model_path = 'yolov8m.pt'
    if not Path(model_path).exists():
        raise FileNotFoundError(f"모델 파일을 찾을 수 없습니다: {model_path}")
    try:
        return YOLO(model_path)
    except Exception as e:
        logger.error(f"모델 로드 실패: {e}")
        raise HTTPException(status_code=500, detail="YOLO 모델 로드 실패")

# 모델 로드
model = load_model()

@app.post("/detect/")
async def detect_objects(file: UploadFile = File(...)):
    """객체 감지 API"""
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(status_code=400, detail="지원되지 않는 이미지 형식입니다")

    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
            temp_path = temp_file.name
            content = await file.read()
            temp_file.write(content)

        results = model(temp_path)

        # 결과가 없거나 boxes가 없는 경우 체크
        if not hasattr(results[0], "boxes") or results[0].boxes is None:
            return {
                "success": False,
                "error": "감지된 객체가 없습니다."
            }

        boxes = results[0].boxes
        names = results[0].names  # 클래스 이름 사전

        detections = []
        for i in range(len(boxes)):
            confidence = float(boxes.conf[i].item())
            if confidence >= 0.2:  # 신뢰도 0.2 이상만 포함
                class_id = int(boxes.cls[i].item())
                class_name = names[class_id]  # 클래스 ID를 이름으로 변환
                detections.append({
                    "class_name": class_name,  # 클래스 이름
                    "confidence": confidence   # 신뢰도
                })

        # 신뢰도 순으로 정렬
        detections = sorted(detections, key=lambda x: x["confidence"], reverse=True)

        if not detections:  # 감지된 객체가 없을 경우
            return {
                "success": False,
                "error": "감지된 객체가 없습니다."
            }

        return {
            "success": True,
            "detections": detections
        }

    except Exception as e:
        logger.error(f"객체 감지 오류: {e}")
        return {
            "success": False,
            "error": str(e)
        }

    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)