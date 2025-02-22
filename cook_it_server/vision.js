/*const vision = require("@google-cloud/vision");
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

    try {
        const [result] = await getVisionClient().labelDetection(`gs://${bucket.name}/${fileName}`);
        if (!result || !result.labelAnnotations) {
            throw new Error('Vision API 응답이 올바르지 않습니다.');
        }
        return processVisionResult(result.labelAnnotations, ingredientMap);
    } catch (error) {
        console.error('Vision API 처리 중 오류:', error);
        throw new Error('이미지 분석 중 오류가 발생했습니다.');
    }
}

function processVisionResult(labels, ingredientMap) {
    const topLabel = labels
        .filter((label) => label.score > 0.7 && ingredientMap[label.description.toLowerCase()])
        .sort((a, b) => b.score - a.score)[0];

    if (!topLabel) {
        throw new Error("식재료를 인식하지 못했습니다.");
    }

    const ingredientEnglish = topLabel.description.toLowerCase();
    if (!ingredientMap[ingredientEnglish]) {
        throw new Error("맵핑 테이블에 없는 식재료입니다.");
    }

    return ingredientMap[ingredientEnglish];
}

module.exports = {
    initializeVision,
    getVisionClient,
    detectIngredientLabels,
};*/