# 🏂 Ski Boarder

3D 백컨트리 스노우보드 게임 - Godot 4 프로젝트

## 📋 프로젝트 개요
- **엔진**: Godot 4.4+
- **장르**: 3D 레이싱/스포츠
- **플랫폼**: macOS (추후 확장)
- **개발 기간**: 2025.10 ~

## 🎮 핵심 기능
- 1인칭/3인칭 시점 전환
- 물리 기반 스노우보드 조작
- 눈가루 파티클 효과
- 산악 구조 미션 시스템

## 🛠 개발 환경 설정

### 필수 요구사항
- Godot 4.4 이상
- macOS 12+ (Apple Silicon 권장)
- Git

### 프로젝트 셋업
```bash
git clone https://github.com/kimhanui/ski-boarder.git
cd ski-boarder
# Godot Editor로 프로젝트 열기
```

**상세 셋팅 가이드**: [PROJECT_SETUP.md](./PROJECT_SETUP.md) 참고

## 📁 프로젝트 구조
```
ski-boarder/
├── scenes/
│   ├── player/              # 플레이어 캐릭터 씬
│   ├── environment/         # 지형 및 환경 씬
│   └── camera/              # 카메라 시스템
├── scripts/
│   ├── player/              # 플레이어 스크립트 (V1, V2)
│   ├── camera/              # 프리 카메라 스크립트
│   └── terrain/             # 지형 생성 스크립트
├── resources/
│   └── slope_data.json      # 지형 설정 데이터
├── assets/                  # 모델, 텍스처, 사운드
├── CREATE_PLAYER.json       # 3D 모델링 명세
└── project.godot            # 프로젝트 설정
```

## 🎯 개발 로드맵
- [x] 프로젝트 초기 셋팅
- [x] 기본 지형 및 플레이어 이동
- [x] 카메라 시스템 (4가지 모드)
- [x] 플레이어 애니메이션 V2 (점프 포함)
- [x] 절차적 지형 생성 시스템
- [ ] 파티클 시스템 (눈가루 효과)
- [ ] 미션 시스템

## 📚 주요 문서

### 시스템별 가이드
- **[PLAYER.md](./PLAYER.md)** - 플레이어 시스템 완전 가이드
  - Character Model (치비 스타일)
  - Movement System (스케이팅, 브레이크, 점프)
  - Animation System V2 (IDLE, FORWARD, TURN, BRAKE, JUMP)
  - V1 vs V2 비교

- **[CAMERA.md](./CAMERA.md)** - 카메라 시스템 가이드
  - 4가지 카메라 모드 (3인칭 뒤/앞, 1인칭, 프리 카메라)
  - 프리 카메라 조작법
  - UI 통합

- **[SLOPE.md](./SLOPE.md)** - 지형 시스템 가이드
  - 절차적 지형 생성
  - Heightmap 및 Mesh 빌딩
  - 난이도 시스템 (Easy/Medium/Hard)
  - 충돌 레이어 설정

### 설정 및 참고
- **[PROJECT_SETUP.md](./PROJECT_SETUP.md)** - 프로젝트 초기 설정
- **[CLAUDE.md](./CLAUDE.md)** - Claude Code 작업 가이드
- **[CREATE_PLAYER.json](./CREATE_PLAYER.json)** - 전문 3D 모델 명세 (향후 교체용)

## 🔗 외부 링크
- [Notion 프로젝트 페이지](https://www.notion.so/28adfd12eb0f8169bac5ef9d5514f4f0)
- [Godot 공식 문서](https://docs.godotengine.org/en/stable/)

## 📝 라이선스
MIT License
