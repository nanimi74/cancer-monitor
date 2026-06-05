# 플랫폼 설정 가이드

## iOS

대상 플랫폼:

- iOS 15 이상 권장
- App Store 배포

필요 설정:

- Firebase iOS 앱 등록 및 `GoogleService-Info.plist` 추가
- Apple Developer 계정에서 Bundle ID 생성
- HealthKit Capability 활성화
- Push Notifications 또는 Local Notifications 권한 설정
- `Info.plist`에 HealthKit 및 알림 권한 설명 추가

HealthKit 권한 문구 예시:

```xml
<key>NSHealthShareUsageDescription</key>
<string>증상 기록의 운동량 입력을 돕기 위해 Apple 건강 앱의 걸음수 데이터를 불러옵니다.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>본 앱은 현재 건강 앱에 데이터를 쓰지 않습니다.</string>
```

운영 정책:

- 사용자가 마이페이지에서 걸음수 연동을 켤 때만 HealthKit 권한을 요청한다.
- 읽기 권한은 걸음수 데이터로 제한한다.
- HealthKit 데이터는 광고, 마케팅, 사용자 추적에 사용하지 않는다.

## Android

대상 플랫폼:

- Android 8.0 이상 권장
- Google Play 배포

필요 설정:

- Firebase Android 앱 등록 및 `google-services.json` 추가
- Health Connect 사용 준비
- Android 14 이상은 시스템 Health Connect를 사용하고, Android 13 이하는 Health Connect 앱 설치/사용 가능 여부를 확인한다.
- 걸음수 읽기 권한은 `READ_STEPS`로 제한한다.

Health Connect 권한 예시:

```xml
<uses-permission android:name="android.permission.health.READ_STEPS" />
```

운영 정책:

- 사용자가 마이페이지에서 걸음수 연동을 켤 때만 Health Connect 권한을 요청한다.
- Health Connect 권한은 걸음수 읽기에만 사용한다.
- Play Console의 Health Connect 권한 신청과 Data safety 양식에 사용 목적을 일치시킨다.

## 공통

- 민감 건강정보는 암호화 전송을 기본으로 한다.
- 서버 저장 데이터는 사용자 ID 기준으로 분리한다.
- 회원탈퇴 시 Firebase 계정과 앱 데이터 삭제 플로우를 제공한다.
- 둘러보기 모드는 실제 건강정보 저장과 권한 요청을 수행하지 않는다.
- Claude API 기반 AI 분석은 서버 경유로만 호출한다.
- Claude API에는 이름, 이메일, Firebase UID 등 직접 식별정보를 전송하지 않는다.
- Claude API로 전송되는 건강정보 범위, 보관 기간, 모델 학습 사용 여부, 국외 이전 여부를 개인정보처리방침에 명시한다.
- AI 분석 이용 동의는 HealthKit/Health Connect 걸음수 연동 동의와 별도로 관리한다.
