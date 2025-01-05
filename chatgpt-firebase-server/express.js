const express = require("express");
const admin = require("firebase-admin");
const bodyParser = require("body-parser");
const OpenAI = require("openai");
require("dotenv").config();

// Firebase 초기화
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// OpenAI 설정
const openaiClient = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Express 설정
const app = express();
app.use(bodyParser.json());

// 재료 매칭 점수 계산 함수
function calculateIngredientMatchScore(recipeParts, searchIngredients) {
  const recipeIngredients = recipeParts.split(',').map(item => {
    return item.replace(/\d+([.,]\d+)?[a-zA-Z]*\s*/, '').trim();
  });

  let matchCount = 0;
  searchIngredients.forEach(searchIngredient => {
    const searchTerm = searchIngredient.toLowerCase();
    if (recipeIngredients.some(ingredient =>
      ingredient.toLowerCase().includes(searchTerm) ||
      searchTerm.includes(ingredient.toLowerCase())
    )) {
      matchCount++;
    }
  });

  return (matchCount / searchIngredients.length) * 100;
}

// 레시피의 모든 조리 단계를 가져오는 함수
function getAllCookingSteps(recipe) {
  const steps = [];
  for (let i = 1; i <= 20; i++) {
    const stepKey = `MANUAL${i.toString().padStart(2, '0')}`;
    if (recipe[stepKey] && recipe[stepKey].trim()) {
      steps.push(recipe[stepKey].trim());
    }
  }
  return steps;
}

// 레시피 추천 API
app.post("/recommend", async (req, res) => {
  const { ingredients, cookingMethod } = req.body;

  try {
    let query = db.collection("recipes");
    if (cookingMethod) {
      query = query.where("RCP_WAY2", "==", cookingMethod);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      return res.status(404).json({
        success: false,
        message: "조건에 맞는 레시피가 없습니다."
      });
    }

    let recipes = [];
    snapshot.forEach((doc) => {
      const recipeData = doc.data();
      if (ingredients && ingredients.length > 0) {
        const matchScore = calculateIngredientMatchScore(
          recipeData.RCP_PARTS_DTLS || "",
          ingredients
        );
        if (matchScore >= 30) {
          recipes.push({
            ...recipeData,
            matchScore: matchScore
          });
        }
      } else {
        recipes.push(recipeData);
      }
    });

    // 매칭 점수 기준으로 정렬하고 상위 3개만 선택
    if (ingredients && ingredients.length > 0) {
      recipes.sort((a, b) => b.matchScore - a.matchScore);
    }
    recipes = recipes.slice(0, 3);

    if (recipes.length === 0) {
      return res.status(404).json({
        success: false,
        message: "조건에 맞는 레시피가 없습니다."
      });
    }

    // ChatGPT로 추천 메시지 생성
    let gptMessage = '';
    try {
      const recipeDescriptions = recipes.map((r) => {
        const matchScoreText = r.matchScore ? ` (재료 일치도: ${r.matchScore.toFixed(1)}%)` : '';
        return `${r.RCP_NM}${matchScoreText}: ${r.RCP_PARTS_DTLS}`;
      }).join("\n");

      const gptResponse = await openaiClient.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "user",
            content: `사용자가 찾는 재료: ${ingredients.join(", ")}\n\n다음 3개의 레시피 중에서 사용자의 재료와 가장 잘 맞는 순서대로 설명해주세요:\n${recipeDescriptions}`,
          },
        ],
        temperature: 0.7,
        max_tokens: 500,
      });

      gptMessage = gptResponse.choices?.[0]?.message?.content || '레시피 추천을 생성하지 못했습니다.';
    } catch (error) {
      console.error("GPT API 호출 중 오류:", error);
      gptMessage = '레시피 추천 생성 중 오류가 발생했습니다.';
    }

    // 응답 반환
    res.json({
      success: true,
      message: "레시피 추천이 완료되었습니다.",
      data: {
        recipes: recipes.map(recipe => ({
          name: recipe.RCP_NM,
          summary: recipe.RCP_SUMMARY,
          ingredients: recipe.RCP_PARTS_DTLS,
          cookingMethod: recipe.RCP_WAY2,
          category: recipe.RCP_PAT2,
          calories: recipe.INFO_ENG,
          servings: recipe.RCP_PAT3,
          cookingTime: recipe.RCP_PAT4,
          difficulty: recipe.RCP_NA_TIP,
          image: recipe.ATT_FILE_NO_MAIN,
          cookingSteps: getAllCookingSteps(recipe),
          matchScore: recipe.matchScore ? recipe.matchScore.toFixed(1) : null,
          nutrition: {
            calories: recipe.INFO_ENG,
            carbs: recipe.INFO_CAR,
            protein: recipe.INFO_PRO,
            fat: recipe.INFO_FAT,
            sodium: recipe.INFO_NA
          }
        })),
        recommendation: gptMessage,
        searchCriteria: {
          ingredients: ingredients || [],
          cookingMethod: cookingMethod || "전체"
        }
      }
    });

  } catch (error) {
    console.error("서버 오류:", error);
    res.status(500).json({
      success: false,
      message: "서버에서 오류가 발생했습니다.",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// CORS 미들웨어
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  next();
});

// 에러 핸들러
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: "서버에서 예기치 않은 오류가 발생했습니다.",
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// 서버 실행
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`서버가 http://localhost:${PORT} 에서 실행 중입니다.`);
}).on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`포트 ${PORT}가 이미 사용 중입니다. 다른 포트를 사용하거나 해당 포트를 사용 중인 프로세스를 종료하세요.`);
  } else {
    console.error('서버 시작 중 오류 발생:', error);
  }
  process.exit(1);
});