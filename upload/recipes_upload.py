import firebase_admin
from firebase_admin import credentials, firestore
import json

# Firebase 서비스 계정 키 로드
cred = credentials.Certificate("../serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# Firestore 클라이언트 생성
db = firestore.client()

# JSON 파일 Firestore에 업로드하는 함수
def upload_recipes(json_file_path, collection_name):
    try:
        # JSON 파일 읽기
        with open(json_file_path, "r", encoding="utf-8") as file:
            json_data = json.load(file)

        # 레시피 데이터 추출
        recipes = json_data["COOKRCP01"]["row"]  # 'row' 배열에서 레시피 데이터 가져오기

        # Firestore에 데이터 추가 (배치 처리)
        batch = db.batch()

        for recipe in recipes:
            doc_ref = db.collection(collection_name).document(recipe["RCP_SEQ"])  # 문서 ID를 RCP_SEQ로 설정
            batch.set(doc_ref, recipe)

        # Firestore에 데이터 커밋
        batch.commit()

        print(f"{len(recipes)}개의 레시피가 Firestore에 업로드되었습니다.")

    except Exception as e:
        print("JSON 데이터를 Firestore에 업로드하는 중 오류 발생:", e)

# 실행 예제
upload_recipes("../data/recipes.json", "recipes")  # "recipes.json" 파일을 "recipes" 컬렉션에 업로드
