import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# 1. Firebase 인증 정보 로드 (serviceAccountKey.json 파일 필요)
cred = credentials.Certificate("../serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# 2. Firestore 클라이언트 생성
db = firestore.client()

# 3. CSV 파일 로드
file_path = "../data/mapped_ingredients_translated.csv"
df = pd.read_csv(file_path)

# 4. Firestore에 데이터 업로드 (문서 ID를 1부터 숫자로 설정)
collection_name = "ingredients"

for index, row in df.iterrows():
    ingredient_data = {
        "식재료": row["식재료"],  # 한국어 식재료명
        "english": row["English"]  # 영어 번역명
    }
    doc_id = str(index + 1)  # 문서 ID를 1번부터 숫자로 설정
    db.collection(collection_name).document(doc_id).set(ingredient_data)

print("Firebase Firestore에 데이터 업로드 완료!")
