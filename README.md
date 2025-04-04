

![cookit2](https://github.com/user-attachments/assets/333f22b3-f86d-41f3-9a6b-764dd643a9b8)




### 지도교수: 이상호 교수님

**팀원:**
- 2020158024 안병윤
- 2022150048 민종석
- 2022152053 이주석


# 🍳 Cook IT
> **ChatGPT 기반 맞춤형 레시피북 생성 애플리케이션**  




## 📖 프로젝트 소개
**Cook IT**은 AI 기반의 맞춤형 레시피 추천 및 관리 애플리케이션입니다.  
사용자의 **식습관, 보유 식재료, 알레르기 정보**를 분석하여 최적의 레시피를 추천하고,  
손동작 인식 기능을 활용한 **편리한 요리 조작**을 제공합니다.  

이 프로젝트는 **Flutter, Node.js, FastAPI, Firebase**를 활용하여 개발되었으며,  
**YOLOv8 모델**을 통한 **식재료 인식** 및 **ChatGPT 기반 레시피 추천** 기능을 포함하고 있습니다.


---


## 🎯 핵심 기능
### ✅ **1. AI 맞춤형 레시피 추천**
- **FMBT (Food + MBTI) 설문조사**를 활용한 **개인화된 레시피 추천**
- **사용자의 알레르기, 선호/비선호 식재료 반영**
- **ChatGPT + 공공 레시피 데이터셋 (1138개)** 기반 추천
- **보유한 식재료와 레시피 매칭, 부족한 재료 표시**

### ✅ **2. 식재료 인식 및 관리**
- **YOLOv8 모델**을 이용한 **사진 기반 자동 식재료 입력**
- **나만의 냉장고** 기능으로 보유 식재료 관리 가능
- **식재료 사진 촬영 → 자동 등록 → 부족한 재료 표시**

### ✅ **3. 손동작을 활용한 레시피북 조작**
- **MediaPipe Hand Tracking**을 이용한 **제스처 기반 페이지 넘김**
- 요리 중 손을 사용하지 않고 **책장을 넘기듯 레시피 확인 가능**
- **손동작 인식 (스와이프 제스처) → 레시피북 페이지 자동 전환**

### ✅ **4. 레시피북 생성 및 수정**
- 개인 맞춤형 **레시피북 자동 생성**
- **GPT-4 API 기반**으로 새로운 레시피 추가 및 수정 가능
- **사용자가 직접 레시피 수정 가능**
- **레시피를 저장하고 커뮤니티에서 공유 가능**


---


## 🛠️ 기술 스택
| **구분** | **기술** |
|------|------|
| **프론트엔드** | Flutter |
| **백엔드** | Node.js, FastAPI |
| **데이터베이스** | Firebase |
| **AI 모델** | YOLOv8 (식재료 인식), ChatGPT API |
| **API** | Google Cloud API, Mediapipe API |
| **개발 도구** | Android Studio, VS Code, PyCharm, WebStorm, Postman, Google Colab |


---

### 🖥️ 시스템 구성도 


![시스템 구성도 수정](https://github.com/user-attachments/assets/3fcb49dc-39a7-4d4e-b6aa-1cedce56aed4)



---

### 👨‍🍳➡️📲➡️🍲 시스템 수행 시나리오


![시나리오](https://github.com/user-attachments/assets/1b38d87d-108b-4bba-a59d-f6de9c35f6c1)

---





