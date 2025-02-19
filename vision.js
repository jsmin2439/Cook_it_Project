const vision = require("@google-cloud/vision");
const { getBucket } = require("./firebase");

let visionClient;

function initializeVision() {
    const visionCredentials = require("./vision-key.json");
    // Vision API 클라이언트 생성
    visionClient = new vision.ImageAnnotatorClient({
        credentials: visionCredentials,
    });
}

function getVisionClient() {
    if (!visionClient) {
        throw new Error('Vision API가 초기화되지 않았습니다.');
    }
    return visionClient;
}

async function detectIngredientLabels(fileName, ingredientMap) {
    const bucket = getBucket();
    if (!bucket) {
        throw new Error('Firebase Storage가 초기화되지 않았습니다.');
    }

    const [result] = await visionClient.labelDetection(`gs://${bucket.name}/${fileName}`);
    const labels = result.labelAnnotations;

    // 🔹 기존 필터링 방식에서 맵핑 테이블을 이용한 필터링으로 수정
    const topLabel = labels
        .filter((label) => label.score > 0.7 && ingredientMap[label.description.toLowerCase()])
        .sort((a, b) => b.score - a.score)[0];

    if (!topLabel) {
        throw new Error("식재료를 인식하지 못했습니다.");
    }

    // Vision API가 인식한 식재료 (영어) → 소문자 변환
    const ingredientEnglish = topLabel.description.toLowerCase();

    // 만약 매핑 테이블에 없는 식재료라면 에러 반환
    if (!ingredientMap[ingredientEnglish]) {
        throw new Error("맵핑 테이블에 없는 식재료라 인식 결과를 출력할 수 없습니다.");
    }

    // 매핑 테이블에 있다면 한글 식재료명을 가져옴
    return ingredientMap[ingredientEnglish];
}

module.exports = {
    initializeVision,
    getVisionClient,
    detectIngredientLabels,
};