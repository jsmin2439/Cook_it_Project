import firebase_admin
from firebase_admin import credentials, firestore

# Firebase 서비스 계정 키 로드
cred = credentials.Certificate("../cook_it_server/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# Firestore 클라이언트 생성
db = firestore.client()

def rename_collection(old_collection_name, new_collection_name):
    try:
        # 기존 컬렉션의 모든 문서 가져오기
        old_collection_ref = db.collection(old_collection_name)
        docs = old_collection_ref.stream()

        # 카운터 초기화
        doc_count = 0

        # 새 컬렉션에 데이터 복사
        for doc in docs:
            data = doc.to_dict()
            new_doc_ref = db.collection(new_collection_name).document(doc.id)
            new_doc_ref.set(data)
            doc_count += 1

            # 진행상황 출력
            if doc_count % 100 == 0:
                print(f"{doc_count}개 문서 복사 완료")

        print(f"총 {doc_count}개 문서를 '{old_collection_name}'에서 '{new_collection_name}'로 복사 완료.")

        # 삭제 확인
        confirmation = input(f"'{old_collection_name}' 컬렉션의 문서를 삭제하시겠습니까? (y/n): ")

        if confirmation.lower() == 'y':
            delete_count = 0
            for doc in old_collection_ref.stream():
                doc.reference.delete()
                delete_count += 1

                if delete_count % 100 == 0:
                    print(f"{delete_count}개 문서 삭제 완료")

            print(f"'{old_collection_name}' 컬렉션의 총 {delete_count}개 문서 삭제 완료.")
        else:
            print("삭제 작업이 취소되었습니다.")

    except Exception as e:
        print("컬렉션 이름 변경 중 오류 발생:", e)

# recipes 컬렉션을 recipes2로 이름 변경
rename_collection("recipes", "recipes2")