// Firebase Functions에서 환경변수를 안전하게 로드하고, 필요한 라이브러리를 가져옵니다.
const { https } = require("firebase-functions/v2");
const express = require("express");
const multer = require("multer");
const vision = require("@google-cloud/vision");
const admin = require("firebase-admin");
const { Storage } = require("@google-cloud/storage");
const OpenAI = require("openai");
const levenshtein = require("fast-levenshtein");

// Firebase Admin - Application Default Credentials 사용
admin.initializeApp();

// Firestore DB
const db = admin.firestore();

// Cloud Storage 클라이언트
const storage = new Storage();
const projectId = process.env.GCLOUD_PROJECT;
const bucketName = `${projectId}.appspot.com`;
const bucket = storage.bucket(bucketName);

// OpenAI API 키를 환경변수에서 로드 (예: firebase functions:config:set openai.key="YOUR_KEY" 대신 Cloud Run 환경변수 사용)
const openaiKey = process.env.OPENAI_KEY;
const openai = new OpenAI({ apiKey: openaiKey });

// Vision API 클라이언트 생성
const visionClient = new vision.ImageAnnotatorClient();

// Express 앱 생성
const app = express();
app.use(express.json());

// 헬스 체크 라우트
app.get("/", (req, res) => {
  res.status(200).send("Server is running");
});

// Multer 설정 (메모리 저장소 사용)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 30 * 1024 * 1024 }
});

// 스펠링 유사도 계산 함수
function getStringSimilarity(str1, str2) {
  const distance = levenshtein.get(str1, str2);
  const maxLength = Math.max(str1.length, str2.length);
  return 1 - distance / maxLength;
}

// 사용자의 재료와 레시피 재료 매칭도 계산 함수
function calculateMatchScore(userIngredients, recipeIngredients) {
  let matchedCount = 0;
  recipeIngredients.forEach((recipeIngredient) => {
    userIngredients.forEach((userIngredient) => {
      const similarity = getStringSimilarity(recipeIngredient, userIngredient);
      if (similarity > 0.8) {
        matchedCount += 1;
      }
    });
  });
  return matchedCount / recipeIngredients.length;
}

// 사용자 식재료 저장 함수
async function saveIngredients(userId, ingredients) {
  const userRef = db.collection("user_ingredients").doc(userId);
  try {
    await userRef.set({ ingredients }, { merge: true });
  } catch (error) {
    console.error("Error saving ingredients:", error);
    throw error;
  }
}

// 사용자 식재료 가져오기 함수
async function getUserIngredients(userId) {
  try {
    const userRef = db.collection("user_ingredients").doc(userId);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      console.log("사용자 식재료가 없습니다.");
      return [];
    }
    return userDoc.data().ingredients || [];
  } catch (error) {
    console.error("사용자 식재료 가져오기 오류:", error);
    throw error;
  }
}

// 레시피 데이터 검색 및 매칭도 계산 함수
async function findTopRecipes(userIngredients) {
  try {
    const recipesSnapshot = await db.collection("recipes").get();
    const recipes = recipesSnapshot.docs.map((doc) => {
      const data = doc.data();
      // 재료 목록에서 공백 제거 및 소문자 처리
      const ingredients = data.RCP_PARTS_DTLS.split(",").map((ingredient) =>
          ingredient.trim().toLowerCase()
      );
      const correctedUserIngredients = userIngredients.map((ing) =>
          ing.toLowerCase()
      );
      const matchScore = calculateMatchScore(correctedUserIngredients, ingredients);
      return {
        id: doc.id,
        name: data.RCP_NM,
        ingredients,
        matchScore,
        category: data.RCP_PAT2,
        fullData: {
          ...data,
          matchedIngredients: ingredients.filter((ingredient) =>
              correctedUserIngredients.some((userIngredient) =>
                  ingredient.includes(userIngredient)
              )
          ),
          matchScore,
        },
      };
    });
    return recipes.sort((a, b) => b.matchScore - a.matchScore).slice(0, 50);
  } catch (error) {
    console.error("레시피 검색 오류:", error);
    throw error;
  }
}

// GPT-4를 사용하여 최종 레시피 3개 추천 함수
async function recommendTop3Recipes(userIngredients, topRecipes) {
  try {
    const simplifiedRecipes = topRecipes.map((recipe) => ({
      id: recipe.id,
      name: recipe.name,
      matchScore: recipe.matchScore,
      matchedIngredients: recipe.ingredients.filter((ingredient) =>
          userIngredients.some((userIngredient) =>
              ingredient.includes(userIngredient.toLowerCase())
          )
      ),
      category: recipe.category,
    }));

    const gptResponse = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content:
              "상위 50개 레시피 중에서 재료 매칭도를 우선적으로 고려하고, 카테고리 다양성을 판단하여 최적의 3개 레시피를 추천하세요.",
        },
        {
          role: "user",
          content: `
식재료: ${userIngredients.join(", ")}

레시피 목록:
${JSON.stringify(simplifiedRecipes, null, 1)}

다음 형식으로 응답해주세요:
{
  "recommendedRecipes": ["레시피ID1", "레시피ID2", "레시피ID3"]
}`,
        },
      ],
      temperature: 0.7,
      max_tokens: 150,
    });

    const recommendations = JSON.parse(gptResponse.choices[0].message.content);

    const recommendedRecipesData = await Promise.all(
        recommendations.recommendedRecipes.map(async (recipeId) => {
          const doc = await db.collection("recipes").doc(recipeId).get();
          return doc.exists ? { id: doc.id, ...doc.data() } : null;
        })
    );

    const validRecommendedRecipes = recommendedRecipesData.filter(Boolean);

    if (validRecommendedRecipes.length < 3) {
      console.log("추천된 레시피가 충분치 않아 상위 3개를 반환합니다.");
      return topRecipes.slice(0, 3).map((recipe) => recipe.fullData);
    }
    return validRecommendedRecipes;
  } catch (error) {
    console.error("GPT 레시피 추천 오류:", error);
    if (error.code === "rate_limit_exceeded") {
      console.log("Rate limit 초과, 상위 3개 레시피를 반환합니다.");
      return topRecipes.slice(0, 3).map((recipe) => recipe.fullData);
    }
    throw error;
  }
}

// 이미지 업로드 및 Vision API 분석 라우트
app.post("/upload-ingredient", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
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

    const [result] = await visionClient.labelDetection(`gs://${bucketName}/${fileName}`);
    const labels = result.labelAnnotations;
    const topLabel = labels
        .filter((label) => label.score > 0.7 && label.description !== "Food")
        .sort((a, b) => b.score - a.score)[0];

    if (!topLabel) {
      return res.status(404).json({ error: "식재료를 인식하지 못했습니다." });
    }
    await saveIngredients(userId, [topLabel.description]);
    res.json({ success: true, detectedIngredient: topLabel.description });
  } catch (error) {
    console.error("Error processing image:", error);
    res.status(500).json({ error: "이미지 처리 중 오류가 발생했습니다." });
  }
});

// 레시피 추천 라우트
app.post("/recommend-recipes", async (req, res) => {
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

// 에러 핸들링 미들웨어
app.use((err, req, res, next) => {
  console.error("Error:", err);
  res.status(500).json({
    error: "서버 내부 오류가 발생했습니다.",
    message: err.message
  });
});

// CORS 설정 미들웨어
app.use((req, res, next) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "GET, POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Max-Age", "3600");
    res.status(204).send("");
  } else {
    next();
  }
});

// 런타임 옵션 및 Gen2 함수 내보내기
const runtimeOpts = {
  region: "us-central1",
  memory: "2Gi",
  timeoutSeconds: 540,
  minInstances: 0,
  maxInstances: 10,
};

exports.api = https.onRequest(runtimeOpts, app);
