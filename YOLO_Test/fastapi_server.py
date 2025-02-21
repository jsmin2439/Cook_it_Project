from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import tempfile
import shutil
import os
import logging
from ultralytics import YOLO
from typing import Dict, List, Optional

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# YOLO 모델 전역 변수로 설정
try:
    model = YOLO('best.pt')
    logger.info("YOLO 모델 로드 완료")
except Exception as e:
    logger.error(f"모델 로드 실패: {e}")
    raise


def process_detections(result) -> List[Dict]:
    """결과 처리를 위한 헬퍼 함수"""
    detections = []
    if hasattr(result, "boxes") and result.boxes is not None:
        boxes = result.boxes.xyxy.cpu().numpy()
        confs = result.boxes.conf.cpu().numpy()
        classes = result.boxes.cls.cpu().numpy()

        for box, conf, cls in zip(boxes, confs, classes):
            detection = {
                "bbox": box.tolist(),
                "confidence": float(conf),
                "label": result.names.get(int(cls), str(int(cls))),
                "class_id": int(cls)
            }
            detections.append(detection)
    return detections


@app.post("/detect/")
async def detect_image(
        file: UploadFile = File(...),
        conf_threshold: Optional[float] = 0.25
):
    """
    이미지에서 객체를 감지하는 엔드포인트
    :param file: 업로드된 이미지 파일
    :param conf_threshold: 신뢰도 임계값 (기본값: 0.25)
    """
    if not file.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="이미지 파일만 허용됩니다")

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            shutil.copyfileobj(file.file, tmp)
            tmp_path = tmp.name

        try:
            # 모델 추론 실행
            results = model(tmp_path, conf=conf_threshold)
            result = results[0]

            # 결과 처리
            response = {
                "detections": process_detections(result),
                "inference_time": {
                    "preprocess": result.speed.get('preprocess', 0),
                    "inference": result.speed.get('inference', 0),
                    "postprocess": result.speed.get('postprocess', 0)
                },
                "image_info": {
                    "size": result.orig_shape,
                    "filename": file.filename
                }
            }

            return response

        except Exception as e:
            logger.error(f"객체 검출 중 오류: {e}")
            raise HTTPException(status_code=500, detail=f"객체 검출 실패: {str(e)}")

    except Exception as e:
        logger.error(f"파일 처리 중 오류: {e}")
        raise HTTPException(status_code=500, detail=f"파일 처리 실패: {str(e)}")

    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("fastapi_server:app", host="0.0.0.0", port=8000, reload=True)