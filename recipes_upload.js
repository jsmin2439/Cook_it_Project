const admin = require("firebase-admin");
const fs = require("fs");

// Firebase 초기화
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// JSON 파일 Firestore에 업로드
async function uploadRecipes(jsonFilePath, collectionName) {
  try {
    // JSON 파일 읽기
    const rawData = fs.readFileSync(jsonFilePath, "utf-8");
    const jsonData = JSON.parse(rawData);

    // 레시피 데이터 추출
    const recipes = jsonData.COOKRCP01.row; // 'row' 배열에서 데이터 가져오기

    // Firestore에 데이터 추가
    const batch = db.batch(); // 배치 작업 시작

    recipes.forEach((recipe) => {
      const docRef = db.collection(collectionName).doc(recipe.RCP_SEQ); // 문서 ID를 RCP_SEQ로 설정
      batch.set(docRef, recipe);
    });

    // Firestore 커밋
    await batch.commit();
    console.log(`${recipes.length}개의 레시피가 Firestore에 업로드되었습니다.`);
  } catch (error) {
    console.error("JSON 데이터를 Firestore에 업로드하는 중 오류 발생:", error);
  }
}

// JSON 파일 경로와 Firestore 컬렉션 이름 설정
const jsonFilePath = "./recipes.json"; // 실제 파일 경로
const collectionName = "recipes"; // Firestore 컬렉션 이름

// 실행
uploadRecipes(jsonFilePath, collectionName);