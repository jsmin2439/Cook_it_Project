const express = require("express");
const multer = require("multer");
const vision = require("@google-cloud/vision");
const admin = require("firebase-admin");
const OpenAI = require("openai");
const path = require("path");
const dotenv = require("dotenv");
const spellchecker = require("spellchecker");
const levenshtein = require("fast-levenshtein");

dotenv.config();

// Firebase 초기화
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// OpenAI 설정
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// Google Vision API 클라이언트 생성
const visionClient = new vision.ImageAnnotatorClient({
  keyFilename: path.join(__dirname, "vision-key.json"),
});

const app = express();
app.use(express.json());

// 파일 업로드를 위한 multer 설정
const upload = multer({ dest: "uploads/" });

// 스펠링 교정 함수
function correctSpelling(ingredient) {
  const corrected = spellchecker.getCorrectionsForMisspelling(ingredient);
  return corrected.length > 0 ? corrected[0] : ingredient;
}

// 스펠링 유사도를 계산하여 매칭도 평가하는 함수
function getStringSimilarity(str1, str2) {
  const distance = levenshtein.get(str1, str2);
  const maxLength = Math.max(str1.length, str2.length);
  return 1 - distance / maxLength; // 0 ~ 1 사이의 유사도 값 반환
}

// 사용자의 재료와 레시피의 재료를 비교하는 함수
function calculateMatchScore(userIngredients, recipeIngredients) {
  let matchedCount = 0;
  recipeIngredients.forEach(recipeIngredient => {
    userIngredients.forEach(userIngredient => {
      const similarity = getStringSimilarity(recipeIngredient, userIngredient);
      if (similarity > 0.8) { // 유사도 80% 이상이면 매칭 처리
        matchedCount += 1;
      }
    });
  });
  return matchedCount / recipeIngredients.length;
}

// 사용자의 식재료 저장
async function saveIngredients(userId, ingredients) {
  const userRef = db.collection("user_ingredients").doc(userId);
  try {
    await userRef.set({ ingredients }, { merge: true });
  } catch (error) {
    console.error("Error saving ingredients:", error);
    throw error;
  }
}

// 사용자의 식재료 가져오기
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

// 레시피 데이터를 가져오고 사용자의 식재료와 매칭하여 점수 계산
async function findTopRecipes(userIngredients) {
  try {
    const recipesSnapshot = await db.collection("recipes").get();
    const recipes = recipesSnapshot.docs.map(doc => {
      const data = doc.data();
      // 재료 목록을 소문자 및 공백 제거 처리
      const ingredients = data.RCP_PARTS_DTLS.split(",").map(ingredient =>
        ingredient.trim().toLowerCase()
      );
      const correctedUserIngredients = userIngredients.map(ing => ing.toLowerCase());
      const matchScore = calculateMatchScore(correctedUserIngredients, ingredients);
      return {
        id: doc.id,
        name: data.RCP_NM,
        ingredients,
        matchScore,
        category: data.RCP_PAT2,
        // firebase의 전체 데이터 + 매칭된 재료 정보를 추가합니다.
        fullData: {
          ...data,
          matchedIngredients: ingredients.filter(ingredient =>
            correctedUserIngredients.some(userIngredient =>
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

// GPT-4를 사용하여 최종 레시피 3개 추천 (firebase에서 추천된 ID로 직접 조회)
async function recommendTop3Recipes(userIngredients, topRecipes) {
  try {
    // GPT에 전달할 데이터는 간략화된 형태로 전달합니다.
    const simplifiedRecipes = topRecipes.map(recipe => ({
      id: recipe.id,
      name: recipe.name,
      matchScore: recipe.matchScore,
      matchedIngredients: recipe.ingredients.filter(ingredient =>
        userIngredients.some(userIngredient =>
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

    // GPT가 추천한 레시피 ID 3개를 기반으로 firebase에서 전체 레시피 데이터를 조회합니다.
    const recommendedRecipesData = await Promise.all(
      recommendations.recommendedRecipes.map(async recipeId => {
        const doc = await db.collection("recipes").doc(recipeId).get();
        return doc.exists ? { id: doc.id, ...doc.data() } : null;
      })
    );

    const validRecommendedRecipes = recommendedRecipesData.filter(Boolean);

    // 추천된 레시피가 3개 미만이면 fallback: 상위 3개 레시피 반환
    if (validRecommendedRecipes.length < 3) {
      console.log("추천된 레시피가 충분하지 않아 상위 3개를 반환합니다.");
      return topRecipes.slice(0, 3).map(recipe => recipe.fullData);
    }
    return validRecommendedRecipes;
  } catch (error) {
    console.error("GPT 레시피 추천 오류:", error);
    if (error.code === "rate_limit_exceeded") {
      console.log("Rate limit 초과, 상위 3개 레시피를 반환합니다.");
      return topRecipes.slice(0, 3).map(recipe => recipe.fullData);
    }
    throw error;
  }
}

// Vision API를 활용한 식재료 분석
app.post("/upload-ingredient", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "이미지가 필요합니다." });
    }
    const userId = req.body.userId || "default";
    const [result] = await visionClient.labelDetection(req.file.path);
    const labels = result.labelAnnotations;
    const topLabel = labels
      .filter(label => label.score > 0.7 && label.description !== "Food")
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

// 레시피 추천 API 엔드포인트
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

    // firebase의 레시피 데이터에 포함된 모든 필드를 응답 객체에 포함합니다.
    res.json({
      success: true,
      userIngredients,
      recommendedRecipes: recommendedRecipes.map(recipe => ({
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

// 서버 실행
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
