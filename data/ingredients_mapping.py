import time
import os
from deep_translator import GoogleTranslator
from tqdm import tqdm
import pandas as pd

def main():
    # 현재 파일의 디렉토리 경로 가져오기
    current_dir = os.path.dirname(os.path.abspath(__file__))
    # CSV 파일 경로 생성
    csv_path = os.path.join(current_dir, 'ingredients_category.csv')

    # CSV 파일 로드
    df = pd.read_csv(csv_path, encoding='utf-8')
    translator = GoogleTranslator(source='ko', target='en')
    translated_list = []

    print(f"총 {len(df['식재료'])}개의 식재료 번역을 시작합니다...")

    # 각 식재료에 대해 번역 수행
    for ingredient in tqdm(df['식재료'], desc='번역 중'):
        try:
            # 번역 수행
            translation = translator.translate(ingredient)
            translated_list.append(translation)

            # API 제한을 피하기 위한 지연
            time.sleep(0.5)
        except Exception as e:
            print(f"'{ingredient}' 번역 중 오류 발생: {e}")
            translated_list.append(ingredient)
            time.sleep(1)

    # 번역 결과를 데이터프레임에 추가
    df['영어재료'] = translated_list

    # 결과를 새 CSV 파일로 저장
    df.to_csv('mapped_ingredients_translated.csv', index=False, encoding='utf-8')
    print("번역 완료! 결과가 'mapped_ingredients_translated.csv'에 저장되었습니다.")

if __name__ == '__main__':
    main()