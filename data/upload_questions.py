import json
import firebase_admin
from firebase_admin import credentials, firestore

# 🔹 Firebase 서비스 계정 키 로드
cred = credentials.Certificate("../cook_it_server/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# 🔹 Firestore 연결
db = firestore.client()

# 🔹 JSON 파일 로드
with open("questions.json", "r", encoding="utf-8") as file:
    questions_data = json.load(file)

# 🔹 Firestore에 데이터 저장 함수
def upload_questions():
    collection_ref = db.collection("questions")  # Firestore 컬렉션

    try:
        for index, section in enumerate(questions_data, start=1):  # 문서 이름 1부터 시작
            doc_ref = collection_ref.document(str(index))  # 숫자를 문자열로 변환하여 문서 이름 설정
            doc_ref.set({
                "category": section["category"],
                "questions": section["questions"]
            })
            print(f"✅ {index}번 문서 저장 완료: {section['category']}")

        print("🎉 모든 설문지 데이터가 Firestore에 업로드되었습니다!")
    except Exception as e:
        print("❌ Firestore 저장 중 오류 발생:", e)

# 🔹 실행
upload_questions()
