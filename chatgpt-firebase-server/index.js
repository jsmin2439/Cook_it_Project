const admin = require("firebase-admin");

// 서비스 계정 키 파일 경로
const serviceAccount = require("./serviceAccountKey.json");

// Firebase 초기화
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://chatgpt-project-d580f.firebaseio.com",
});

const db = admin.firestore();

console.log("Firebase initialized!");

async function addTestData() {
  const docRef = db.collection("questions").doc("testQuestion");
  await docRef.set({
    question: "What is Firebase?",
    timestamp: new Date().toISOString(),
  });
  console.log("Test data added!");
}

addTestData();

async function getTestData() {
  const docRef = db.collection("questions").doc("testQuestion");
  const doc = await docRef.get();
  if (!doc.exists) {
    console.log("No such document!");
  } else {
    console.log("Document data:", doc.data());
  }
}

getTestData();
