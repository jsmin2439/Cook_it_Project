const express = require("express");
const multer = require("multer");
const vision = require("@google-cloud/vision");
const dotenv = require("dotenv");
const path = require("path");

dotenv.config(); // .env 파일 사용

// Google Vision API 클라이언트 생성
const client = new vision.ImageAnnotatorClient({
  keyFilename: path.join(__dirname, "vision-key.json"), // JSON 키 파일 경로
});

const app = express();
const upload = multer({ dest: "uploads/" }); // 파일 저장 경로

// 이미지 업로드 및 Vision API 호출
app.post("/upload", upload.single("image"), async (req, res) => {
  try {
    const filePath = req.file.path;

    // Vision API로 이미지 분석
    const [result] = await client.labelDetection(filePath);
    const labels = result.labelAnnotations.map(label => label.description);

    res.json({ labels });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 서버 실행
app.listen(3000, () => {
  console.log("Server running on http://localhost:3000");
});

