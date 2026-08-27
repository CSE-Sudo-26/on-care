"""공공 식품영양성분 DB 큐레이션 시드.

식약처(MFDS) 식품영양성분 데이터베이스 / 국가표준식품성분표를 참고해,
국내에서 가장 자주 촬영되는 한식·외식·디저트 메뉴 43종을 **1회 제공량(1인분) 기준**으로
정리한 대표값이다. 운영에서는 공식 CSV 전체 임포트로 대체(스크립트 예정).

고혈압·당뇨 위험군 특화 서비스이므로 나트륨(sodium_mg)·당류(sugar_g)를 특히 신중히 채웠다.
값 단위: serving_size_g=g, calories=kcal, sodium_mg=mg, sugar_g/carbs_g/protein_g/fat_g=g.
"""
from __future__ import annotations

# name, category, serving_g, kcal, sodium_mg, sugar_g (+ 탄단지는 있는 항목만)
FOOD_NUTRIENTS: list[dict] = [
    # --- 밥·분식 ---
    {"name": "공기밥", "category": "밥류", "serving_size_g": 210, "calories": 310, "sodium_mg": 3, "sugar_g": 0},
    {"name": "비빔밥", "category": "밥류", "serving_size_g": 500, "calories": 600, "sodium_mg": 900, "sugar_g": 8},
    {"name": "김밥", "category": "분식", "serving_size_g": 200, "calories": 480, "sodium_mg": 700, "sugar_g": 6},
    {"name": "볶음밥", "category": "밥류", "serving_size_g": 400, "calories": 620, "sodium_mg": 1300, "sugar_g": 5},
    {"name": "떡볶이", "category": "분식", "serving_size_g": 300, "calories": 550, "sodium_mg": 1600, "sugar_g": 20},
    {"name": "순대", "category": "분식", "serving_size_g": 200, "calories": 360, "sodium_mg": 900, "sugar_g": 2},
    # --- 국·찌개·탕 ---
    {"name": "김치찌개", "category": "국·찌개류", "serving_size_g": 400, "calories": 250, "sodium_mg": 1200, "sugar_g": 3},
    {"name": "된장찌개", "category": "국·찌개류", "serving_size_g": 400, "calories": 180, "sodium_mg": 1300, "sugar_g": 4},
    {"name": "순두부찌개", "category": "국·찌개류", "serving_size_g": 400, "calories": 220, "sodium_mg": 1100, "sugar_g": 3},
    {"name": "미역국", "category": "국·찌개류", "serving_size_g": 300, "calories": 110, "sodium_mg": 800, "sugar_g": 1},
    {"name": "된장국", "category": "국·찌개류", "serving_size_g": 300, "calories": 90, "sodium_mg": 900, "sugar_g": 2},
    {"name": "갈비탕", "category": "탕류", "serving_size_g": 700, "calories": 430, "sodium_mg": 1500, "sugar_g": 3},
    {"name": "설렁탕", "category": "탕류", "serving_size_g": 700, "calories": 400, "sodium_mg": 1400, "sugar_g": 2},
    {"name": "삼계탕", "category": "탕류", "serving_size_g": 1000, "calories": 900, "sodium_mg": 1400, "sugar_g": 1},
    # --- 면 ---
    {"name": "라면", "category": "면류", "serving_size_g": 550, "calories": 500, "sodium_mg": 1800, "sugar_g": 5},
    {"name": "짜장면", "category": "면류", "serving_size_g": 650, "calories": 700, "sodium_mg": 2400, "sugar_g": 12},
    {"name": "짬뽕", "category": "면류", "serving_size_g": 700, "calories": 660, "sodium_mg": 4000, "sugar_g": 8},
    {"name": "잔치국수", "category": "면류", "serving_size_g": 550, "calories": 480, "sodium_mg": 1900, "sugar_g": 6},
    {"name": "물냉면", "category": "면류", "serving_size_g": 600, "calories": 550, "sodium_mg": 2200, "sugar_g": 15},
    # --- 구이·볶음·고기 ---
    {"name": "삼겹살", "category": "구이류", "serving_size_g": 200, "calories": 660, "sodium_mg": 120, "sugar_g": 0},
    {"name": "제육볶음", "category": "볶음류", "serving_size_g": 250, "calories": 480, "sodium_mg": 1300, "sugar_g": 10},
    {"name": "불고기", "category": "구이류", "serving_size_g": 250, "calories": 420, "sodium_mg": 1100, "sugar_g": 14},
    {"name": "양념갈비", "category": "구이류", "serving_size_g": 250, "calories": 550, "sodium_mg": 1200, "sugar_g": 16},
    # --- 튀김·외식 ---
    {"name": "후라이드치킨", "category": "튀김류", "serving_size_g": 300, "calories": 800, "sodium_mg": 1200, "sugar_g": 2},
    {"name": "양념치킨", "category": "튀김류", "serving_size_g": 300, "calories": 900, "sodium_mg": 1400, "sugar_g": 20},
    {"name": "돈까스", "category": "튀김류", "serving_size_g": 250, "calories": 730, "sodium_mg": 1000, "sugar_g": 8},
    {"name": "감자튀김", "category": "튀김류", "serving_size_g": 130, "calories": 410, "sodium_mg": 350, "sugar_g": 1},
    {"name": "피자", "category": "외식", "serving_size_g": 120, "calories": 280, "sodium_mg": 600, "sugar_g": 4},
    {"name": "햄버거", "category": "외식", "serving_size_g": 250, "calories": 550, "sodium_mg": 1000, "sugar_g": 9},
    {"name": "초밥", "category": "외식", "serving_size_g": 200, "calories": 480, "sodium_mg": 900, "sugar_g": 15},
    # --- 반찬·달걀 ---
    {"name": "김치", "category": "반찬", "serving_size_g": 50, "calories": 15, "sodium_mg": 300, "sugar_g": 1},
    {"name": "계란후라이", "category": "달걀", "serving_size_g": 50, "calories": 90, "sodium_mg": 160, "sugar_g": 0},
    {"name": "계란찜", "category": "달걀", "serving_size_g": 200, "calories": 150, "sodium_mg": 700, "sugar_g": 1},
    {"name": "샐러드", "category": "채소", "serving_size_g": 150, "calories": 40, "sodium_mg": 30, "sugar_g": 4},
    # --- 음료·과일·빵 ---
    {"name": "아메리카노", "category": "음료", "serving_size_g": 350, "calories": 10, "sodium_mg": 10, "sugar_g": 0},
    {"name": "콜라", "category": "음료", "serving_size_g": 355, "calories": 150, "sodium_mg": 15, "sugar_g": 39},
    {"name": "우유", "category": "음료", "serving_size_g": 200, "calories": 130, "sodium_mg": 100, "sugar_g": 10},
    {"name": "사과", "category": "과일", "serving_size_g": 200, "calories": 100, "sodium_mg": 2, "sugar_g": 20},
    {"name": "바나나", "category": "과일", "serving_size_g": 120, "calories": 105, "sodium_mg": 1, "sugar_g": 14},
    {"name": "식빵", "category": "빵류", "serving_size_g": 70, "calories": 200, "sodium_mg": 380, "sugar_g": 4},
    # --- 디저트 ---
    # 요거트 아이스크림 볼은 컵 하나가 베이스 + 과일 + 그래놀라로 갈리므로 세 줄로 둔다.
    # 한 줄로 묶으면 토핑을 바꾼 컵이 전부 같은 값이 된다.
    {"name": "요거트 아이스크림", "category": "디저트", "serving_size_g": 110,
     "calories": 135, "sodium_mg": 55, "sugar_g": 14.5,
     "carbs_g": 26.0, "protein_g": 3.0, "fat_g": 2.0},
    {"name": "과일 토핑", "category": "디저트", "serving_size_g": 90,
     "calories": 55, "sodium_mg": 5, "sugar_g": 9.0,
     "carbs_g": 13.0, "protein_g": 1.0, "fat_g": 0.5},
    {"name": "그래놀라 토핑", "category": "디저트", "serving_size_g": 50,
     "calories": 205, "sodium_mg": 125, "sugar_g": 6.0,
     "carbs_g": 20.0, "protein_g": 5.0, "fat_g": 11.5},
]
