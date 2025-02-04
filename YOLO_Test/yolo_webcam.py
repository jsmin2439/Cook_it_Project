import cv2
from ultralytics import YOLO

# YOLOv8 모델 로드
model = YOLO("yolov8n.pt")  # 가벼운 Nano 모델 사용

# 웹캠 열기 (Mac은 기본적으로 0번 카메라 사용)
cap = cv2.VideoCapture(0)

while cap.isOpened():
    ret, frame = cap.read()  # 프레임 읽기
    if not ret:
        break

    # YOLOv8을 이용한 객체 탐지 수행
    results = model(frame)

    # 결과를 화면에 표시
    for result in results:
        for box in result.boxes.xyxy:  # 바운딩 박스 좌표
            x1, y1, x2, y2 = map(int, box[:4])  # 좌표값 변환
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)  # 초록색 박스

    # 화면에 출력
    cv2.imshow("YOLOv8 Real-Time Detection", frame)

    # 'q' 키를 누르면 종료
    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()
