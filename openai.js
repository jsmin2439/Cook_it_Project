const OpenAI = require("openai");
const { getDb } = require('./firebase');

let openai;

function initializeOpenAI() {
    const openaiKey = process.env.OPENAI_KEY;
    if (!openaiKey) {
        throw new Error("OPENAI_KEY 환경 변수가 설정되지 않았습니다.");
    }
    openai = new OpenAI({ apiKey: openaiKey });
}

// GPT-4를 사용하여 최종 레시피 3개 추천 함수
async function recommendTop3Recipes(userIngredients, topRecipes) {
    const db = getDb();  // db 객체 가져오기
    if (!db) {
        throw new Error('Firebase가 초기화되지 않았습니다.');
    }
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

module.exports = {
    initializeOpenAI,
    recommendTop3Recipes,
};