const express = require("express");
const routes = require("./routes");
const { initializeFirebase } = require("./firebase");
const { initializeOpenAI } = require("./openai");
const { initializeVision } = require("./vision");
const { authMiddleware } = require('./auth');

require("dotenv").config();

// Express 앱 생성 및 미들웨어 설정
const app = express();

app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// CORS 미들웨어
app.use((req, res, next) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");

    if (req.method === "OPTIONS") {
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send(""); // OPTIONS 요청은 204 응답 후 종료
    } else {
        next(); // 다음 미들웨어로 넘어가기
    }
});

// 라우터 설정
app.use("/verify-login", routes); // 인증 없이 접근 가능한 로그인 라우트
app.use("/api", authMiddleware); // 인증이 필요한 라우트에만 미들웨어 적용
app.use("/api", routes);

// 헬스 체크 라우트
app.get("/", (req, res) => {
    res.status(200).send("Server is running");
});

let isServerInitialized = false;

// 서버 초기화 및 시작
async function startServer() {
    if (isServerInitialized) return;

    try {
        const { db, bucket } = await initializeFirebase();
        console.log('Firebase initialized with bucket:', bucket.name);

        await initializeOpenAI();
        console.log('OpenAI initialized');

        await initializeVision();
        console.log('Vision initialized');

        isServerInitialized = true;

        const PORT = process.env.PORT || 3000;
        app.listen(PORT, () => {
            console.log(`Server is running on port ${PORT}`);
        });
    } catch (error) {
        console.error('Initialization error:', error);
        process.exit(1);
    }
}

startServer();