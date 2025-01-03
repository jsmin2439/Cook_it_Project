from typing import Optional, Dict, Any
import json
import os
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv
from openai import OpenAI
from dataclasses import dataclass


class EnvironmentError(Exception):
    """환경 변수 관련 예외"""
    pass


@dataclass
class RecipeResponse:
    """레시피 API 응답을 위한 데이터 클래스"""
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


class RecipeAPI:
    """레시피 API 래퍼 클래스"""

    def __init__(self, model: str = "gpt-3.5-turbo", max_tokens: int = 800):
        # 프로젝트 디렉토리 구조 설정
        self.project_dir = Path('.')
        self.recipes_dir = self.project_dir / 'recipes'
        self._ensure_directory_structure()

        # .env 파일 로드
        self._load_environment()

        # API 키 가져오기
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key:
            raise EnvironmentError("OPENAI_API_KEY가 환경 변수에 설정되지 않았습니다.")

        self.client = OpenAI(api_key=api_key)
        self.model = model
        self.max_tokens = max_tokens

    def _ensure_directory_structure(self):
        """필요한 디렉토리 구조 생성"""
        self.recipes_dir.mkdir(exist_ok=True)

    def _load_environment(self):
        """환경 변수 로드"""
        env_path = self.project_dir / '.env'

        if not env_path.exists():
            raise EnvironmentError(
                ".env 파일을 찾을 수 없습니다. "
                "프로젝트 루트 디렉토리에 .env 파일을 생성하고 "
                "OPENAI_API_KEY를 설정해주세요."
            )

        load_dotenv(env_path)

    def _save_recipe_to_file(self, recipe_data: Dict) -> Path:
        """레시피를 JSON 파일로 저장"""
        # 파일명 생성 (요리 이름 + 타임스탬프)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        recipe_name = recipe_data.get('요리이름', 'unknown')
        filename = f"{recipe_name}_{timestamp}.json"

        # 특수문자 제거 및 공백을 언더스코어로 변경
        filename = "".join(c if c.isalnum() or c in ['_', '.'] else '_' for c in filename)

        # 파일 경로 설정
        file_path = self.recipes_dir / filename

        # JSON 파일로 저장
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(recipe_data, f, ensure_ascii=False, indent=4)

        return file_path

    def get_recipe(self, prompt: str) -> RecipeResponse:
        """
        ChatGPT API를 사용하여 레시피를 가져오고 파일로 저장합니다.

        Args:
            prompt (str): 레시피 요청을 위한 프롬프트

        Returns:
            RecipeResponse: API 응답 결과를 포함하는 객체
        """
        system_prompt = """You are a helpful chef assistant. Please provide recipes in valid JSON format.
        Follow these rules strictly:
        1. Use complete, well-formed JSON
        2. Keep all text in a single line within JSON strings
        3. Ensure all strings are properly terminated
        4. Use the following structure:
        {
            "요리이름": "string",
            "난이도": "string",
            "소요시간": "string",
            "재료": {},
            "조리과정": []
        }"""

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=self.max_tokens,
                temperature=0.7,
            )

            recipe_text = response.choices[0].message.content

            try:
                recipe_json = json.loads(recipe_text)
                # 레시피를 파일로 저장
                saved_path = self._save_recipe_to_file(recipe_json)
                print(f"\n레시피가 저장된 경로: {saved_path}")
                return RecipeResponse(success=True, data=recipe_json)
            except json.JSONDecodeError as e:
                return RecipeResponse(
                    success=False,
                    error=f"JSON 파싱 오류: {str(e)}\n원본 텍스트: {recipe_text}"
                )

        except Exception as e:
            return RecipeResponse(
                success=False,
                error=f"OpenAI API 오류: {str(e)}"
            )


def main():
    """메인 실행 함수"""
    try:
        # API 클라이언트 초기화
        recipe_api = RecipeAPI()

        # 레시피 요청
        prompt = "요리 레시피를 추천해주세요. 재료와 조리 단계를 상세히 포함해주세요. (한국어)"
        response = recipe_api.get_recipe(prompt)

        if response.success:
            print("=== 레시피 정보 ===")
            print(json.dumps(response.data, indent=4, ensure_ascii=False))
        else:
            print("=== 오류 발생 ===")
            print(response.error)

    except EnvironmentError as e:
        print(f"환경 설정 오류: {e}")
    except Exception as e:
        print(f"예상치 못한 오류 발생: {e}")


if __name__ == "__main__":
    main()