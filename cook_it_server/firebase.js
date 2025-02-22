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
    try {
        if (!admin.apps.length) {
            throw new Error('Firebase가 초기화되지 않았습니다');
        }

        const db = admin.firestore();
        console.log('Firestore 연결 확인...');

        const snapshot = await db.collection('ingredients').get();
        console.log('컬렉션 데이터 조회:', snapshot.size, '개의 문서');

        const ingredientMap = {};
        snapshot.forEach((doc) => {
            const data = doc.data();

            // english 필드를 class ID로 사용
            if (data.english && data.식재료) {
                ingredientMap[data.english] = data.식재료;
            }
        });

        if (Object.keys(ingredientMap).length === 0) {
            throw new Error('ingredientMap이 비어있습니다');
        }

        return ingredientMap;
    } catch (error) {
        console.error('ingredientMap 로드 오류:', error);
        throw new Error('ingredientMap 로드 실패');
    }
}

// 사용자 식재료 저장 함수 (기존 데이터에 추가)
async function saveIngredients(userId, newIngredients) {
    const userRef = db.collection("user").doc(userId);
    try {
        // 트랜잭션으로 안전하게 데이터 업데이트
        await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(userRef);
            let currentIngredients = [];

            // 기존 데이터가 있으면 가져오기
            if (doc.exists) {
                currentIngredients = doc.data().ingredients || [];
            }

            // 중복 제거하면서 새로운 재료 추가
            const updatedIngredients = [...new Set([...currentIngredients, ...newIngredients])];

            // 데이터 업데이트
            transaction.set(userRef, { ingredients: updatedIngredients }, { merge: true });
        });

        console.log("식재료가 성공적으로 추가되었습니다.");
    } catch (error) {
        console.error("식재료 저장 중 오류:", error);
        throw error;
    }
}

// 사용자 식재료 가져오기 함수
async function getUserIngredients(userId) {
    try {
        const userRef = db.collection("user").doc(userId);
        const userDoc = await userRef.get();

        if (!userDoc.exists) {
            return {
                ingredients: [],
                disliked_ingredients: [],
                allergic_ingredients: []
            };
        }

        const userData = userDoc.data();
        return {
            ingredients: userData.ingredients || [],
            disliked_ingredients: userData.disliked_ingredients || [],
            allergic_ingredients: userData.allergic_ingredients || []
        };

    } catch (error) {
        console.error("사용자 식재료 가져오기 오류:", error);
        throw error;
    }
}


// 레시피 데이터 검색 및 매칭도 계산 함수
async function findTopRecipes(userIngredients) {
    if (!userIngredients || !userIngredients.ingredients) {
        throw new Error("유효하지 않은 사용자 식재료 데이터입니다.");
    }

    if (!Array.isArray(userIngredients.ingredients)) {
        throw new Error("ingredients는 배열이어야 합니다.");
    }

    try {
        const recipesSnapshot = await db.collection("recipes").get();
        if (recipesSnapshot.empty) {
            throw new Error("레시피 데이터가 없습니다.");
        }
        const recipes = recipesSnapshot.docs.map((doc) => {
            const data = doc.data();
            // 재료 목록에서 공백 제거 및 소문자 처리
            const ingredients = data.RCP_PARTS_DTLS.split(",").map((ingredient) =>
                ingredient.trim().toLowerCase()
            );
            const correctedUserIngredients = userIngredients.ingredients.map((ing) =>
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