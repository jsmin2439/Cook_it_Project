const levenshtein = require("fast-levenshtein");

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

module.exports = {
    getStringSimilarity,
    calculateMatchScore,
};
