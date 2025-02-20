from fastapi import FastAPI, UploadFile, File
from ultralytics import YOLO
import cv2
import numpy as np
import torch

app = FastAPI()

# YOLO 모델 로드
model = YOLO("best.pt")

@app.post("/detect")
async def detect_objects(file: UploadFile = File(...)):
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    results = model(img)
    detected_items = []

    for result in results:
        for box in result.boxes:
            cls = int(box.cls[0])  # 클래스 ID
            conf = float(box.conf[0])  # 신뢰도
            label = model.names[cls]  # 클래스 이름

            detected_items.append({"label": label, "confidence": conf})

    return {"detected": detected_items}
