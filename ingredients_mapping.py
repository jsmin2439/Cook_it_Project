import asyncio
import time
from googletrans import Translator
from tqdm import tqdm
import pandas as pd


async def main():
    df = pd.read_csv('unique_ingredients.csv')
    translator = Translator()
    translated_list = []

    for ingredient in tqdm(df['식재료'], desc='Translating', unit='item'):
        # 번역 시도
        translation = await translator.translate(ingredient, src='ko', dest='en')
        translated_list.append(translation.text)

        # 매 요청 후 잠깐 대기 (예: 0.5초)
        time.sleep(0.5)

    df['영어재료'] = translated_list
    df.to_csv('mapped_ingredients_translated.csv', index=False)


if __name__ == '__main__':
    asyncio.run(main())
