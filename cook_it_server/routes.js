const express = require("express");
const multer = require("multer");
const { getBucket, initializeFirebase, loadIngredientMap, saveIngredients, getUserIngredients, findTopRecipes } = require("./firebase");
const { recommendTop3Recipes } = require("./openai");
const { getVisionClient } = require("./vision");
const { authMiddleware } = require('./auth');

const router = express.Router();

// Multer 설정 (메모리 저장소 사용)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 30 * 1024 * 1024 }
});

let ingredientMap = {};

initializeFirebase();  // 먼저 Firebase 초기화
loadIngredientMap().then(map => {
    ingredientMap = map;
});

async function deleteImageAfterAnalysis(bucket, fileName) {
    try {
        // 이미지 삭제 전 약간의 대기 시간 설정 (Vision API 처리 완료 보장)
        await new Promise(resolve => setTimeout(resolve, 2000));
        await bucket.file(fileName).delete();
        console.log(`Deleted temporary image: ${fileName}`);
    } catch (error) {
        console.error(`Error deleting image ${fileName}:`, error);
    }
}

// 이미지 업로드 및 Vision API 분석 라우트
router.post("/upload-ingredient", authMiddleware, upload.single("image"), async (req, res) => {
    let fileName = '';
    // userId를 토큰에서 가져옴
    const userId = req.user.uid;
    try {
        const bucket = getBucket();
        if (!bucket) {
            throw new Error('Firebase Storage가 초기화되지 않았습니다.');
        }

        if (!bucket.name) {
            throw new Error('Storage bucket 이름이 유효하지 않습니다.');
        }

        const visionClient = getVisionClient();

        if (!req.file || !req.file.buffer) {
            return res.status(400).json({ error: "이미지가 필요합니다." });
        }

        const userId = req.body.userId || "default";
        const fileName = `ingredients/${Date.now()}-${req.file.originalname}`;
        const file = bucket.file(fileName);

        await file.save(req.file.buffer, {
            metadata: { contentType: req.file.mimetype },
        });

        // Vision API 호출 전에 업로드 완료 대기
        await new Promise((resolve) => setTimeout(resolve, 1000));

        const [result] = await visionClient.labelDetection(`gs://${bucket.name}/${fileName}`);
        const labels = result.labelAnnotations;

        // 🔹 기존 필터링 방식에서 맵핑 테이블을 이용한 필터링으로 수정
        const topLabel = labels
            .filter((label) => label.score > 0.7 && ingredientMap[label.description.toLowerCase()]) // 🔹 맵핑 테이블에 있는 항목만 필터링
            .sort((a, b) => b.score - a.score)[0];

        if (!topLabel) {
            return res.status(404).json({ error: "식재료를 인식하지 못했습니다." });
        }
        // Vision API가 인식한 식재료 (영어) → 소문자 변환
        const ingredientEnglish = topLabel.description.toLowerCase();

        // 만약 매핑 테이블에 없는 식재료라면 에러 반환
        if (!ingredientMap[ingredientEnglish]) {
            // 매핑 실패 시에도 이미지 삭제
            await deleteImageAfterAnalysis(bucket, fileName);
            return res.status(404).json({
                error: "맵핑 테이블에 없는 식재료라 인식 결과를 출력할 수 없습니다.",
            });
        }

        // 매핑 테이블에 있다면 한글 식재료명을 가져옴
        const translatedIngredient = ingredientMap[ingredientEnglish];

        // Firebase에 저장할 때는 한글 식재료 이름 사용
        await saveIngredients(userId, [translatedIngredient]);

        // 이미지 분석이 완료되면 삭제
        await deleteImageAfterAnalysis(bucket, fileName);

        // 클라이언트로도 한글 식재료를 응답
        res.json({ success: true, detectedIngredient: translatedIngredient });


    } catch (error) {
        console.error("Error processing image:", error);
        // 에러 발생 시에도 이미지 삭제 시도
        if (fileName) {
            const bucket = getBucket();
            await deleteImageAfterAnalysis(bucket, fileName);
        }
        res.status(500).json({ error: "이미지 처리 중 오류가 발생했습니다." });
    }
});

// 레시피 추천 라우트
router.post("/recommend-recipes", authMiddleware,async (req, res) => {
    // userId를 토큰에서 가져옴
    const userId = req.user.uid;
    try {
        const { userId } = req.body;
        if (!userId) {
            return res.status(400).json({ error: "사용자 ID가 필요합니다." });
        }
        const userIngredients = await getUserIngredients(userId);
        if (!userIngredients || userIngredients.length === 0) {
            return res.status(404).json({ error: "등록된 식재료가 없습니다." });
        }
        const topRecipes = await findTopRecipes(userIngredients);
        const recommendedRecipes = await recommendTop3Recipes(userIngredients, topRecipes);

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
async function initializeRoutes() {
    try {
        ingredientMap = await loadIngredientMap();
        console.log('IngredientMap loaded successfully');
    } catch (error) {
        console.error('Error loading ingredientMap:', error);
    }
}

module.exports = router;  // router 객체만 내보내기