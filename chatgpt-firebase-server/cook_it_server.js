const express = require("express");
const multer = require("multer");
const vision = require("@google-cloud/vision");
const admin = require("firebase-admin");
const OpenAI = require("openai");
const path = require("path");
const dotenv = require("dotenv");
const spellchecker = require('spellchecker');
const levenshtein = require('fast-levenshtein');

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
  return (1 - distance / maxLength); // 0 ~ 1 사이의 유사도 값 반환
}

// 사용자의 재료와 레시피의 재료를 비교하는 함수
function calculateMatchScore(userIngredients, recipeIngredients) {
  let matchedCount = 0;

  // 레시피의 재료들과 사용자 재료들 간의 유사도 계산
  recipeIngredients.forEach(recipeIngredient => {
    userIngredients.forEach(userIngredient => {
      const similarity = getStringSimilarity(recipeIngredient, userIngredient);
      if (similarity > 0.8) { // 유사도 80% 이상을 매칭으로 처리
        matchedCount += 1;
      }
    });
  });

  return matchedCount / recipeIngredients.length; // 매칭률을 비율로 계산
}

// 사용자의 식재료 저장
async function saveIngredients(userId, ingredients) {
  const userRef = db.collection("user_ingredients").doc(userId);
  try {
    await userRef.set(
      { ingredients },
      { merge: true }
    );
  } catch (error) {
    console.error("Error saving ingredients:", error);
    throw error; // 상위에서 처리하도록 에러 전파
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
      const ingredients = data.RCP_PARTS_DTLS.split(",").map(ingredient =>
        ingredient.trim().toLowerCase()
      );

      const correctedUserIngredients = userIngredients.map(ingredient =>
        ingredient.toLowerCase()
      );

      const matchScore = calculateMatchScore(correctedUserIngredients, ingredients);

      return {
        id: doc.id,
        name: data.RCP_NM,
        ingredients: ingredients,
        matchScore: matchScore,
        category: data.RCP_PAT2,
        fullData: {
          ...data,
          matchedIngredients: ingredients.filter(ingredient =>
            correctedUserIngredients.some(userIngredient =>
              ingredient.includes(userIngredient)
            )
          ),
          matchScore
        }
      };
    });

    return recipes
      .sort((a, b) => b.matchScore - a.matchScore)
      .slice(0, 50); // 상위 50개 레시피로 제한
  } catch (error) {
    console.error("레시피 검색 오류:", error);
    throw error;
  }
}

// GPT-4로 최종 레시피 3개 추천
async function recommendTop3Recipes(userIngredients, topRecipes) {
  try {
    // 데이터 최적화: 필수 정보만 포함
    const simplifiedRecipes = topRecipes.map(recipe => ({
      id: recipe.id,
      name: recipe.name,
      matchScore: recipe.matchScore,
      matchedIngredients: recipe.ingredients.filter(ingredient =>
        userIngredients.some(userIngredient =>
          ingredient.includes(userIngredient.toLowerCase())
        )
      ),
      category: recipe.category
    }));

    const gptResponse = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: "상위 50개 레시피 중에서 재료 매칭도를 우선적으로 고려하고, 카테고리 다양성을 판단하여 최적의 3개 레시피를 추천하세요."
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
}`
        }
      ],
      temperature: 0.7,
      max_tokens: 150,
    });

    const recommendations = JSON.parse(gptResponse.choices[0].message.content);

    // 추천된 레시피의 전체 정보 조회
    const recommendedRecipes = recommendations.recommendedRecipes
      .map(recipeId => topRecipes.find(r => r.id === recipeId))
      .filter(Boolean)
      .map(recipe => recipe.fullData);

    // 추천 결과가 없거나 3개 미만인 경우
    if (!recommendedRecipes || recommendedRecipes.length < 3) {
      console.log("추천된 레시피가 충분하지 않아 상위 3개를 반환합니다.");
      return topRecipes.slice(0, 3).map(recipe => recipe.fullData);
    }

    return recommendedRecipes;

  } catch (error) {
    console.error("GPT 레시피 추천 오류:", error);
    if (error.code === 'rate_limit_exceeded') {
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
    const [result] = await visionClient.labelDetection(req.file.path);  // 'objectLocalization' 대신 'labelDetection' 사용
    const labels = result.labelAnnotations;

    const topLabels = labels
      .filter(label => label.score > 0.7 && label.description !== "Food")
      .sort((a, b) => b.score - a.score)[0];

    if (!topLabels) {
      return res.status(404).json({ error: "식재료를 인식하지 못했습니다." });
    }

    await saveIngredients(userId, [topLabels.description]);

    res.json({ success: true, detectedIngredient: topLabels.description });
  } catch (error) {
    console.error("Error processing image:", error);
    res.status(500).json({ error: "이미지 처리 중 오류가 발생했습니다." });
  }
});

// 레시피 추천 API 엔드포인트
app.post('/recommend-recipes', async (req, res) => {
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
      recommendedRecipes: recommendedRecipes.map(recipe => ({
        id: recipe.id,
        name: recipe.RCP_NM,
        category: recipe.RCP_PAT2,
        ingredients: recipe.RCP_PARTS_DTLS,
        method: recipe.RCP_WAY2,
        tip: recipe.RCP_NA_TIP,
        nutritionalInfo: {
          calories: recipe.INFO_ENG,
          protein: recipe.INFO_PRO,
          fat: recipe.INFO_FAT,
          carbs: recipe.INFO_CAR,
          sodium: recipe.INFO_NA
        },
        cookingSteps: {
          step1: recipe.MANUAL01,
          step2: recipe.MANUAL02,
          step3: recipe.MANUAL03,
          step4: recipe.MANUAL04,
          step5: recipe.MANUAL05
        }
      }))
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
