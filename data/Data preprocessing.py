import json
import re
import pandas as pd
import itertools
import networkx as nx
from konlpy.tag import Komoran, Okt, Kkma

# JSON 파일 로드
file_path = "recipes.json"  # 로컬에서 JSON 파일을 직접 지정
with open(file_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# 레시피 데이터 가져오기
recipes = data["COOKRCP01"]["row"]

# 형태소 분석기 초기화
komoran = Komoran()
okt = Okt()
kkma = Kkma()

# 불용어 리스트 (불필요한 단어 제거)
stopwords = [ "양념", "소스", "고명", "조림", "줄기", "칵테일", "무염", "계란찜", "요리", "인분", "양념장", "봉지", "마리", "해장국", "된장국", "가닥", "국물", "아가", "청홍", "레드", "리", "칩", "재래", "뒤", "제철",
              "기둥", "육수", "채소", "구이" ,"빨강", "펀치", "핑크", "근대", "숙성" , "몸통", "다크", "다이스", "빨간색", "반죽", "인치", "디종", "골드", "선택", "박력", "해독", "아기", "식용", "토믹", "사미", "백일",
              "껍질", "청색", "무가당", "뿌리", "페이퍼", "소량", "분말", "건조", "필수", "페스트", "천연", "멕시코", "떡국", "적채", "우민", "화이트", "팔각", "지중해", "손질", "치자", "호상", "냉", "염", "빗살", "스톡",
              "약간", "정향", "볶음", "기호", "중간", "각종", "사방", "건강", "혼합", "피자", "호떡", "페스", "원종", "엑스트라", "검정", "백태", "비타민" , "주황", "마산", "알파벳", "라이스버거", "진액", "초", "컵", "링",
              "이브", "초록", "첨가", "인스턴트", "크기", "버전", "가정", "기준", "타이거", "부위", "포기", "냉동", "발효", "조각", "씨드", "황금", "그린", "우리", "다리", "주머니", "소개", "잔", "밑동", "디", "추후", "정육",
              "두절", "흰색", "영양", "믹서", "쓴맛", "머리", "겉절이", "삼계탕", "노랑", "비빔밥", "무게", "베이비", "수제", "베트남", "부분", "노란색", "자색", "추가", "소프트", "김밥", "믹", "전립", "컴", "벗", "관자",
              "조선", "재료", "기름기", "유기농", "일식", "사각", "제거", "대왕", "어린이", "아귀찜", "장식", "미니", "삼색", "블랙", "절임", "일본", "포항", "가루", "정사각형", "분량", "분홍", "볶음밥", "소", "과육", "육",
             "작은술", "큰술", "나트륨", "칼륨", "넣고", "끓여", "준비", "만들기", "다진", "자른", "자숙", "레디", "시판", "글라스", "주먹밥", "케이", "타임", "김장", "비름", "파트", "다이브", "홀", "다짐", "맛", "앤", "유",
              "포", "맥", "밑", "쌈", "봄", "향", "액", "호", "순", "면", "태", "발", "찌", "톨", "청", "적", "돈", "술", "훈", "실", "론", "노", "피", "캔", "꽃", "장", "편", "통", "등", "개", "색", "홍", "미술","말", "내장",
              "생", "국", "판", "토", "베", "볼", "채", "건", "살", "알", "황", "봉", "종", "로스", "장국", "해물", "포리", "잡채", "돈까스", "네이션", "찜", "즙", "잎", "씨", "양장", "파스", "샤브샤브" , "팩", "비" ,"때", "가람"]

ingredient_mapping = {
    "공기" : "공기밥", "카레 " : "카레가루", "콘" : "옥수수", "페페" : "페페로니", "송이": "송이버섯", "꽈리": "꽈리고추", "양송이": "양송이버섯", "대패" : "대패삼겹살", "커리" : "카레가루", "기름" : "식용유",
    "우동" : "우동면", "그라스" : "레몬그라스", "무우" : "무", "팽이" : "팽이버섯", "파스타" : "파스타면", "플레인" : "플레인요거트", "라이스" : "쌀", "밀크" : "우유", "베리" : "블루베리", "떡볶이" : "떡볶이떡",
    "피시" : "생선", "드라이" : "드라이아이스", "천도" : "천도복숭아", "라즈베리" :  "산딸기", "미소" : "된장", "오리" : "오리고기", "표고" : "표고버섯", "날개" : "닭날개", "파우더" :  "베이킹파우더",
    "흰자" : "계란", "반장" : "두반장", "스리" : "스리라차", "레디" : "무", "스파게티" : "스파게티면", "애플" : "사과", "워터" : "물", "메추리" : "메추리알"
 }

# 단어를 표준화하는 함수
def standardize_ingredient(word):
    return ingredient_mapping.get(word, word)  # 매핑된 단어가 있으면 변환, 없으면 그대로 반환

# 정규 표현식을 사용하여 한글만 추출하는 함수
def extract_korean(text):
    return " ".join(re.findall(r"[가-힣]+", text))


# 형태소 분석 후 명사만 추출하는 함수 (Komoran, Okt, Kkma 결과 비교 후 최적 선택)
def extract_ingredients(text):
    korean_text = extract_korean(text)

    # 각 형태소 분석기에서 명사 추출
    words_komoran = set(komoran.nouns(korean_text))
    words_okt = set(okt.nouns(korean_text))
    words_kkma = set(kkma.nouns(korean_text))

    # 3개 분석기에서 모두 등장한 단어를 신뢰 (교집합 활용)
    common_words = words_komoran & words_okt & words_kkma

    # 불용어 제거
    filtered_words = [standardize_ingredient(word) for word in common_words if word not in stopwords and len(word) > 0]
    return filtered_words


# 모든 레시피에서 식재료 리스트 추출
recipe_ingredients = []
for recipe in recipes:
    ingredients_text = recipe["RCP_PARTS_DTLS"]
    ingredients_list = extract_ingredients(ingredients_text)
    recipe_ingredients.append(" ".join(ingredients_list))

# 결과를 데이터프레임으로 정리
df = pd.DataFrame({"레시피명": [recipe["RCP_NM"] for recipe in recipes],
                   "전처리된 식재료": recipe_ingredients})

# 결과 CSV 파일로 저장
df.to_csv("recipes_ingredients.csv", index=False, encoding="utf-8-sig")

# 상위 10개 샘플 출력
print(df.head(10))

# 중복값 없이 식재료만 뽑아내는 코드
unique_ingredients = set()

# 모든 레시피에서 중복 없는 식재료 추출
for recipe in recipe_ingredients:
    ingredients_list = recipe.split()  # 공백 기준으로 단어 분리
    unique_ingredients.update(ingredients_list)  # 중복 없이 추가

# 결과를 데이터프레임으로 정리
df_unique = pd.DataFrame({"식재료": list(unique_ingredients)})

df_unique.to_csv("ingredients.csv", index=False, encoding="utf-8-sig")
