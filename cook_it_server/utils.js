const levenshtein = require("fast-levenshtein");
const admin = require("firebase-admin");

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

async function getQuestionsAndResponses(userId) {
    const db = admin.firestore();
    const questionsRef = db.collection("questions");
    const usersRef = db.collection("user").doc(userId);

    const questionsSnapshot = await questionsRef.get();
    const questions = {};
    questionsSnapshot.forEach(doc => {
        questions[doc.id] = doc.data().questions.length;
    });

    const userDoc = await usersRef.get();
    if (!userDoc.exists) {
        throw new Error("사용자 응답 데이터를 찾을 수 없습니다.");
    }
    const responses = userDoc.data().responses;

    return { questions, responses };
}

function calculateFMBT(questions, responses) {
    const categoryMapping = {
        "1": "E_C",
        "2": "F_S",
        "3": "S_G",
        "4": "B_M"
    };

    const scores = { E_C: 0, F_S: 0, S_G: 0, B_M: 0 };

    Object.keys(questions).forEach(questionId => {
        const category = categoryMapping[questionId];
        if (responses[questionId]) {
            scores[category] += responses[questionId].reduce((sum, score) => sum + score, 0);
        }
    });

    const fmbt = [
        scores.E_C >= 15 ? "E" : "C",
        scores.F_S >= 15 ? "F" : "S",
        scores.S_G >= 15 ? "S" : "G",
        scores.B_M >= 15 ? "B" : "M"
    ].join("");

    return fmbt;
}

async function saveFMBTResult(userId, fmbtResult) {
    const db = admin.firestore();
    await db.collection("user").doc(userId).set(
        {
            fmbt: fmbtResult
        },
        { merge: true }
    );
}

module.exports = {
    calculateMatchScore,
    getQuestionsAndResponses,
    calculateFMBT,
    saveFMBTResult
};
