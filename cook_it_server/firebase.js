const admin = require("firebase-admin");
const { calculateMatchScore } = require("./utils");
// Firebase 서비스 계정 및 키 파일 불러오기
const serviceAccount = require("./serviceAccountKey.json");
require('dotenv').config();  // .env 파일 사용

let db;
let bucket;
let isInitialized = false;

// Firebase Admin 초기화
function initializeFirebase() {
    if (isInitialized) {
        return { db, bucket };
    }

    try {
        if (!admin.apps.length) {
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
                storageBucket: process.env.FIREBASE_STORAGE_BUCKET
            });
        }

        db = admin.firestore();  // 초기화 후 설정
        bucket = admin.storage().bucket();

        // bucket이 제대로 초기화되었는지 확인
        if (!bucket) {
            throw new Error('Storage bucket 초기화 실패');
        }
        console.log("Firebase initialized successfully");
        console.log("Storage bucket initialized:", bucket.name);

        isInitialized = true;
        return { db, bucket };
    } catch (error) {
        console.error("Error initializing Firebase:", error);
        throw error;
    }
}

// Firebase에서 ingredients 컬렉션을 읽어 ingredientMap 생성
async function loadIngredientMap() {
    const ingredientMap = {};
    try {
        const snapshot = await db.collection('ingredients').get();
        snapshot.forEach((doc) => {
            const data = doc.data();
            if (data.english && data.식재료) {
                ingredientMap[data.english.toLowerCase()] = data.식재료;
            }
        });
    } catch (error) {
        console.error('Error loading ingredientMap from Firebase:', error);
    }
    return ingredientMap;
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

module.exports = {
    initializeFirebase,
    getDb: () => db,
    getBucket: () => bucket,
    loadIngredientMap,
    saveIngredients,
    getUserIngredients,
    findTopRecipes
};