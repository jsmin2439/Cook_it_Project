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
async function recommendTop3Recipes(userIngredients, topRecipes, userFMBT) {
    if (!userIngredients || !userIngredients.ingredients || !topRecipes) {
        throw new Error('유효하지 않은 입력 데이터입니다.');
    }
    const db = getDb();  // db 객체 가져오기
    if (!db) {
        throw new Error('Firebase가 초기화되지 않았습니다.');
    }
    try {
        const { ingredients, disliked_ingredients, allergic_ingredients } = userIngredients;

        const simplifiedRecipes = topRecipes.map((recipe) => ({
            id: recipe.id,
            name: recipe.name,
            matchScore: recipe.matchScore,
            matchedIngredients: recipe.ingredients.filter((ingredient) =>
                ingredients.some((userIngredient) =>
                    ingredient.includes(userIngredient.toLowerCase())
                )
            ),
            containsDisliked: recipe.ingredients.some(ingredient =>
                disliked_ingredients.some(disliked =>
                    ingredient.includes(disliked.toLowerCase())
                )
            ),
            containsAllergic: recipe.ingredients.some(ingredient =>
                allergic_ingredients.some(allergic =>
                    ingredient.includes(allergic.toLowerCase())
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
                        "상위 50개 레시피 중에서 다음 기준으로 최적의 3개 레시피를 추천하세요:\n" +
                        "1. 알레르기 식재료가 포함된 레시피는 제외\n" +
                        "2. 싫어하는 식재료가 포함된 레시피는 가능한 제외\n" +
                        "3. 재료 매칭도를 우선적으로 고려\n" +
                        "4. 사용자의 FMBT 취향을 고려\n" +
                        "5. 카테고리 다양성 고려"
                },
                {
                    role: "user",
                    content: `
                    사용자 선호도:
                    - 보유 식재료: ${ingredients.join(", ")}
                    - 싫어하는 식재료: ${disliked_ingredients.join(", ")}
                    - 알레르기 식재료: ${allergic_ingredients.join(", ")}
                    - FMBT 유형: ${userFMBT}

                    레시피 목록:
                    ${JSON.stringify(simplifiedRecipes, null, 1)}

                    다음 형식으로 응답해주세요:
                    {
                        "recommendedRecipes": [
                            {
                                "id": "레시피ID",
                                "reason": "추천 이유"
                            },
                            {
                                "id": "레시피ID",
                                "reason": "추천 이유"
                            },
                            {
                                "id": "레시피ID",
                                "reason": "추천 이유"
                            }
                        ]
                    }`,
                },
            ],
            temperature: 0.7,
            max_tokens: 500,
        });

        const recommendations = JSON.parse(gptResponse.choices[0].message.content);

        const recommendedRecipesData = await Promise.all(
            recommendations.recommendedRecipes.map(async (recommendation) => {
                const doc = await db.collection("recipes").doc(recommendation.id).get();
                if (!doc.exists) return null;

                return {
                    id: doc.id,
                    ...doc.data(),
                    fmbtInfo: userFMBT, // FMBT 정보 추가
                    recommendReason: recommendation.reason // 추천 이유 추가
                };
            })
        );

        const validRecommendedRecipes = recommendedRecipesData.filter(Boolean);

        if (validRecommendedRecipes.length < 3) {
            console.log("추천된 레시피가 충분치 않아 상위 3개를 반환합니다.");
            return topRecipes.slice(0, 3).map((recipe) => ({
                ...recipe.fullData,
                fmbtInfo: userFMBT,
                recommendReason: "재료 매칭도 기준 상위 레시피"
            }));
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