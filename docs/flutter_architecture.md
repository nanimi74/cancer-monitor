# Flutter 프로젝트 구조

본 프로젝트는 iOS와 Android 동시 출시를 전제로 Flutter 앱으로 구현한다. 기존 `index.html`은 화면 구조와 디자인 톤을 검증하기 위한 참고 시안으로 유지한다.

## 주요 구조

```text
lib/
  main.dart
  src/
    app/                  # MaterialApp, 전역 라우팅
    core/
      constants/          # 앱명, 버전, 고정 문구
      theme/              # 컬러, 타이포그래피, 공통 테마
      widgets/            # 카드, 섹션 헤더, 안내 배너
    data/
      models/             # UserProfile, Medication, WeightRecord, SymptomRecord
      repositories/       # Firebase 연동 전 샘플/로컬 저장소
    features/
      profile/            # 마이페이지
      medication/         # 복약관리
      weight/             # 체중관리
      symptom/            # 증상관리
      analysis/           # AI분석
      legal/              # 개인정보처리방침, 약관 등 법적 문서
    services/
      ai/                 # Claude API 기반 AI 분석 서비스
      auth/               # Firebase Authentication, mock 인증 fallback
      health/             # HealthKit / Health Connect 걸음수 연동
      notifications/      # 알림 권한 및 복약 알림
```

## 구현 원칙

- 화면 단위는 `features`로 분리한다.
- 건강 데이터, 알림, AI 분석처럼 플랫폼 또는 외부 서비스 의존성이 있는 기능은 `services`로 분리한다.
- 인증은 `AuthService` 인터페이스로 분리하고, Firebase 설정 파일이 없는 동안은 `MockAuthService`를 사용한다.
- Firebase 설정 파일이 추가되면 `FirebaseBootstrap`이 `FirebaseAuthService`로 전환한다.
- Firebase Authentication, Firestore, Cloud Functions, Claude API 호출은 repository/service 구현체로 분리한다.
- Claude API는 앱에서 직접 호출하지 않고 서버 또는 Cloud Functions에서만 호출한다.
- Claude API 요청에는 분석에 필요한 최소 건강정보만 포함하고, 이메일/Firebase UID 같은 직접 식별자는 제외한다.
- Claude API 처리자, 보관 기간, 모델 학습 사용 여부, 국외 이전 여부는 개인정보처리방침과 AI 분석 이용 안내에 명시한다.
- iOS HealthKit, Android Health Connect는 동일한 `StepSyncService` 인터페이스를 통해 호출한다.
- 걸음수 권한 요청은 마이페이지 설정에서 사용자가 연동을 켤 때만 수행한다.

## 사용 패키지

- `firebase_core`
- `firebase_auth`
- `google_sign_in`
- `sign_in_with_apple`

## 향후 패키지 후보

- `cloud_firestore`
- `flutter_local_notifications`
- HealthKit/Health Connect 지원 패키지 또는 직접 MethodChannel
- `go_router` 또는 `auto_route`
- `riverpod` 또는 `bloc`
- `intl`

패키지 버전은 실제 Flutter SDK 설치 후 최신 안정 버전을 확인해 확정한다.
