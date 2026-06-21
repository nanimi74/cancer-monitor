# 앱스토어 / 구글플레이 출시 체크리스트

## 현재 출시 후보

- 앱 버전: 1.0.0+1
- 앱 이름: 항암기록관리
- 번들 ID / 패키지명: com.nanimi74.cancermonitor
- 개인정보처리방침 공개 파일: docs/privacy.html
- 서비스 이용약관 공개 파일: docs/terms.html
- GitHub Pages를 docs 폴더 기준으로 켜면 사용할 URL:
  - https://nanimi74.github.io/cancer-monitor/privacy.html
  - https://nanimi74.github.io/cancer-monitor/terms.html

## 공통

- 서비스 이용약관 작성
- 개인정보처리방침 작성
- 민감 건강정보 처리 고지
- AI 분석 참고용 고지
- Claude API(Anthropic) 등 외부 AI 처리자 사용 고지
- AI 분석 데이터의 국외 이전, 보관 기간, 모델 학습 사용 여부 확인
- 의료 진단/치료 대체 불가 고지
- 회원탈퇴 및 데이터 삭제 기능
- 문의 채널
- 앱 버전 표시
- 알림 권한 설명
- 걸음수 연동 권한 설명
- 스토어 등록용 스크린샷
- 앱 설명, 키워드, 카테고리, 연령 등급
- QA: 권한 거부, 네트워크 오류, 탈퇴, 로그아웃, 둘러보기 모드
- Firebase Console에서 Firestore App Check 적용 상태 확인
- Firebase Console에서 Authentication 제공자별 운영 설정 확인
- Firebase Console에서 Firestore Rules 배포 상태 확인

## App Store

- App Privacy 항목 작성
- Xcode Archive 생성 후 Privacy Report 확인
- 건강/의료 데이터 수집 및 사용 목적 명시
- HealthKit 사용 목적 명시
- HealthKit 데이터는 광고, 마케팅, 사용자 추적에 사용하지 않음
- App Privacy에 Claude API 등 외부 AI 처리자에게 전송되는 건강정보 처리 여부를 반영
- 리뷰어 노트에 HealthKit 권한 요청 위치와 사용 목적 설명
- 의료 조언 앱이 아니라 기록 관리 및 상담 준비 보조 앱임을 설명

## Google Play

- Data safety 양식 작성
- Health Connect 권한 사용 목적 제출
- 민감 건강정보 및 Health Connect 데이터 처리 목적 명시
- Claude API 등 외부 AI 처리자에게 전송되는 건강정보 처리 목적과 보관 정책 명시
- 권한은 기능 사용 시점에 요청
- 앱 내 개인정보처리방침 링크 제공
- 계정 및 데이터 삭제 URL 또는 앱 내 삭제 플로우 제공
- Play Console 업로드 전 Android release keystore 설정

## 법적 문서에 포함할 항목

- 서비스 목적과 제공 범위
- 회원가입, 계정, 탈퇴
- 사용자 기록 저장과 관리
- AI 분석의 한계와 면책
- Claude API 등 외부 AI 처리자 이용 여부
- AI 분석에 전송되는 건강정보 범위
- AI 분석 데이터 보관 기간, 국외 이전 여부, 모델 학습 사용 여부
- 의료진 상담 권고
- 알림 권한
- HealthKit / Health Connect 걸음수 연동
- 개인정보 수집 항목
- 개인정보 이용 목적
- 보관 기간과 삭제
- 제3자 제공 및 위탁
- 국외 이전 여부
- 사용자의 권리
- 미성년자 이용 제한 또는 보호자 동의 정책
- 문의처

## Claude API 사용 전 확인 항목

- Anthropic 계약/정책 기준으로 입력/출력 데이터 보관 기간 확인
- 모델 학습에 사용자 건강정보가 사용되지 않도록 계약/설정 확인
- 가능하면 Zero Data Retention 또는 이에 준하는 보관 최소화 옵션 검토
- Claude API로 직접 식별정보를 보내지 않는 서버 필터링 구현
- 분석 요청/응답 로그 저장 여부와 자체 서버 보관 기간 확정
- 개인정보처리방침에 처리 위탁/제3자 제공/국외 이전 중 실제 법적 성격을 구분해 명시
- AI 분석 이용 안내에서 외부 AI 처리자 사용과 의료 면책을 사용자에게 고지
