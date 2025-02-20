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
// server.js
app.use((req, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header(
        "Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept, Authorization"
    );
    res.header(
        "Access-Control-Allow-Methods",
        "GET, POST, PUT, DELETE, OPTIONS"
    );

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    next();
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