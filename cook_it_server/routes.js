const express = require("express");
const multer = require("multer");
const { initializeFirebase, loadIngredientMap, getUserIngredients, findTopRecipes } = require("./firebase");
const { recommendTop3Recipes } = require("./openai");
const { authMiddleware } = require('./auth');
const { verifyLogin } = require('./auth');
const { calculateMatchScore, getQuestionsAndResponses, calculateFMBT, saveFMBTResult } = require("./utils");
const axios = require('axios');
const FormData = require('form-data');
const FASTAPI_URL = process.env.FASTAPI_URL || 'http://localhost:8000';


const router = express.Router();

// Multer 설정 (메모리 저장소 사용)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 30 * 1024 * 1024 }
});

let ingredientMap = {};

// 식재료 등록 라우트
router.post("/upload-ingredient", authMiddleware, upload.single("image"), async (req, res) => {
    const userId = req.user.uid;

    try {
        const imageProcessing = async () => {
            if (!req.file || !req.file.buffer) {
                return res.status(400).json({error: "이미지가 필요합니다."});
            }

            const formData = new FormData();
            formData.append('file', req.file.buffer, {
                filename: req.file.originalname,
                contentType: req.file.mimetype
            });

            const response = await axios.post(`${FASTAPI_URL}/detect/`, formData, {
                headers: {
                    ...formData.getHeaders(),
                    'Accept': 'application/json'
                }
            });

            if (!response.data.success) {
                throw new Error('식재료 인식 실패');
            }

            // 중복 제거된 한글 식재료명 목록 생성
            const uniqueIngredients = [...new Set(
                response.data.detections
                    .map(detection => ingredientMap[detection.class_name])
                    .filter(name => name)  // undefined나 null 제거
            )];

            if (uniqueIngredients.length === 0) {
                throw new Error('인식된 식재료가 없습니다.');
            }

            return uniqueIngredients;
        };

        const detectedIngredients = await Promise.race([
            imageProcessing(),
            new Promise((_, reject) =>
                setTimeout(() => reject(new Error('이미지 처리 시간이 초과되었습니다.')), 30000)
            )
        ]);

        res.json({
            success: true,
            detectedIngredients: detectedIngredients,
            message: '식재료가 성공적으로 저장되었습니다.'
        });

    } catch (error) {
        console.error("이미지 처리 오류:", error);
        res.status(error.response?.status || 500).json({
            error: error.message || "이미지 처리 중 오류가 발생했습니다."
        });
    }
});

// 레시피 추천 라우트
router.post("/recommend-recipes", authMiddleware,async (req, res) => {
    try {
        // userId를 토큰에서 가져옴
        const userId = req.user.uid;
        const userIngredients = await getUserIngredients(userId);


        if (!userIngredients || !userIngredients.ingredients || userIngredients.ingredients.length === 0) {
            return res.status(404).json({ error: "등록된 식재료가 없습니다." });
        }
        const topRecipes = await findTopRecipes(userIngredients);
        if (!topRecipes || topRecipes.length === 0) {
            return res.status(404).json({ error: "매칭되는 레시피가 없습니다." });
        }

        const recommendedRecipes = await recommendTop3Recipes(userIngredients, topRecipes);
        if (!recommendedRecipes || recommendedRecipes.length === 0) {
            return res.status(404).json({ error: "추천 레시피를 찾을 수 없습니다." });
        }

        res.json({
            success: true,
            userIngredients,
            recommendedRecipes: recommendedRecipes.map((recipe) => ({
                id: recipe.id,
                ATT_FILE_NO_MAIN: recipe.ATT_FILE_NO_MAIN,
                ATT_FILE_NO_MK: recipe.ATT_FILE_NO_MK,
                HASH_TAG: recipe.HASH_TAG,
                INFO_CAR: recipe.INFO_CAR,
                INFO_ENG: recipe.INFO_ENG,
                INFO_FAT: recipe.INFO_FAT,
                INFO_NA: recipe.INFO_NA,
                INFO_PRO: recipe.INFO_PRO,
                INFO_WGT: recipe.INFO_WGT,
                MANUAL01: recipe.MANUAL01,
                MANUAL02: recipe.MANUAL02,
                MANUAL03: recipe.MANUAL03,
                MANUAL04: recipe.MANUAL04,
                MANUAL05: recipe.MANUAL05,
                MANUAL06: recipe.MANUAL06,
                MANUAL07: recipe.MANUAL07,
                MANUAL08: recipe.MANUAL08,
                MANUAL09: recipe.MANUAL09,
                MANUAL10: recipe.MANUAL10,
                MANUAL11: recipe.MANUAL11,
                MANUAL12: recipe.MANUAL12,
                MANUAL13: recipe.MANUAL13,
                MANUAL14: recipe.MANUAL14,
                MANUAL15: recipe.MANUAL15,
                MANUAL16: recipe.MANUAL16,
                MANUAL17: recipe.MANUAL17,
                MANUAL18: recipe.MANUAL18,
                MANUAL19: recipe.MANUAL19,
                MANUAL20: recipe.MANUAL20,
                MANUAL_IMG01: recipe.MANUAL_IMG01,
                MANUAL_IMG02: recipe.MANUAL_IMG02,
                MANUAL_IMG03: recipe.MANUAL_IMG03,
                MANUAL_IMG04: recipe.MANUAL_IMG04,
                MANUAL_IMG05: recipe.MANUAL_IMG05,
                MANUAL_IMG06: recipe.MANUAL_IMG06,
                MANUAL_IMG07: recipe.MANUAL_IMG07,
                MANUAL_IMG08: recipe.MANUAL_IMG08,
                MANUAL_IMG09: recipe.MANUAL_IMG09,
                MANUAL_IMG10: recipe.MANUAL_IMG10,
                MANUAL_IMG11: recipe.MANUAL_IMG11,
                MANUAL_IMG12: recipe.MANUAL_IMG12,
                MANUAL_IMG13: recipe.MANUAL_IMG13,
                MANUAL_IMG14: recipe.MANUAL_IMG14,
                MANUAL_IMG15: recipe.MANUAL_IMG15,
                MANUAL_IMG16: recipe.MANUAL_IMG16,
                MANUAL_IMG17: recipe.MANUAL_IMG17,
                MANUAL_IMG18: recipe.MANUAL_IMG18,
                MANUAL_IMG19: recipe.MANUAL_IMG19,
                MANUAL_IMG20: recipe.MANUAL_IMG20,
                RCP_NA_TIP: recipe.RCP_NA_TIP,
                RCP_NM: recipe.RCP_NM,
                RCP_PARTS_DTLS: recipe.RCP_PARTS_DTLS,
                RCP_PAT2: recipe.RCP_PAT2,
                RCP_SEQ: recipe.RCP_SEQ,
                RCP_WAY2: recipe.RCP_WAY2,
            })),
        });
    } catch (error) {
        console.error("레시피 추천 오류:", error);
        // 상세 에러 메시지 숨기기
        res.status(500).json({ error: "레시피 추천 중 오류가 발생했습니다." });
    }
});

// 로그인 검증 라우트 추가
router.post("/verify-login", async (req, res) => {
    const { idToken } = req.body;

    if (!idToken) {
        return res.status(400).json({ error: '토큰이 필요합니다.' });
    }

    const result = await verifyLogin(idToken);
    if (result.success) {
        res.json(result);
    } else {
        res.status(401).json(result);
    }
});

// ingredientMap 초기화는 서버 시작 후에 수행
let isRoutesInitialized = false;

async function initializeRoutes() {
    if (isRoutesInitialized) {
        return;
    }

    try {
        console.log('라우트 초기화 시작...');
        const { db } = await initializeFirebase();

        if (!db) {
            throw new Error('Firestore 초기화 실패');
        }

        console.log('ingredientMap 로드 시작...');
        ingredientMap = await loadIngredientMap();
        console.log('ingredientMap 로드 완료');

        isRoutesInitialized = true;
    } catch (error) {
        console.error('Error loading ingredientMap:', error);
        throw error;
    }
}

// FMBT 계산 라우트 수정
router.get("/calculate-fmbt", authMiddleware, async (req, res) => {
    try {
        // authMiddleware에서 설정된 user 객체에서 uid 가져오기
        const userId = req.user.uid;

        const { questions, responses } = await getQuestionsAndResponses(userId);
        const fmbtResult = calculateFMBT(questions, responses);
        await saveFMBTResult(userId, fmbtResult);

        return res.json({ success: true, fmbt: fmbtResult });
    } catch (error) {
        console.error("FMBT 계산 중 오류 발생:", error);
        return res.status(500).json({ error: "FMBT 계산 중 오류 발생" });
    }
});

module.exports = {
    router,
    initializeRoutes
};