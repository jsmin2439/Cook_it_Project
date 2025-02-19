const express = require("express");
const routes = require("./routes");
const { initializeFirebase } = require("./firebase");
const { initializeOpenAI } = require("./openai");
const { initializeVision } = require("./vision");

require("dotenv").config();

// Express 앱 생성 및 미들웨어 설정
const app = express();

app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// CORS 미들웨어
app.use((req, res, next) => {
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET, POST");
        res.set("Access-Control-Allow-Headers", "Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        res.status(204).send("");
    } else {
        next();
    }
});

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

        app.use("/", routes);
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