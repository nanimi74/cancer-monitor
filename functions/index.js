const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const DEFAULT_CLAUDE_MODELS = [
  "claude-haiku-4-5-20251001",
  "claude-sonnet-4-6",
  "claude-opus-4-8",
];
const CLAUDE_MODELS = buildClaudeModelList();
const ANTHROPIC_VERSION = "2023-06-01";
const ANALYSIS_TITLES = [
  "식사량",
  "음수량",
  "운동량",
  "배변",
  "특이사항 및 부작용",
];

exports.analyzeCycle = onCall(
  {
    region: "asia-northeast3",
    invoker: "public",
    secrets: [anthropicApiKey],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const payload = normalizePayload(request.data);
    if (!payload.records.length) {
      throw new HttpsError("failed-precondition", "분석할 기록이 없습니다.");
    }

    const body = await requestClaudeAnalysis(payload);
    const text = extractClaudeText(body);
    const parsed = parseJson(text);
    return validateAnalysis(parsed, payload.previousRecords.length > 0);
  },
);

async function requestClaudeAnalysis(payload) {
  const errors = [];

  for (const model of CLAUDE_MODELS) {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": anthropicApiKey.value(),
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify({
        model,
        max_tokens: 3400,
        temperature: 0.35,
        system: buildSystemPrompt(),
        messages: [
          {
            role: "user",
            content: JSON.stringify(payload),
          },
        ],
      }),
    });

    if (response.ok) {
      logger.info("Claude API request succeeded", { model });
      return response.json();
    }

    const errorText = await response.text();
    errors.push({ model, status: response.status, errorText });

    if (!isRetryableClaudeError(response.status)) {
      logger.error("Claude API request failed", {
        model,
        status: response.status,
        errorText,
      });
      throw new HttpsError("internal", "AI 분석 요청에 실패했습니다.");
    }

    logger.warn("Claude model failed, trying next candidate", {
      model,
      status: response.status,
    });
  }

  logger.error("All Claude model candidates failed", { errors });
  throw new HttpsError("internal", "AI 분석 요청에 실패했습니다.");
}

function buildClaudeModelList() {
  const configured = process.env.ANTHROPIC_MODELS || process.env.ANTHROPIC_MODEL;
  if (!configured) return DEFAULT_CLAUDE_MODELS;

  const models = configured
    .split(",")
    .map((model) => model.trim())
    .filter(Boolean);
  return models.length ? models : DEFAULT_CLAUDE_MODELS;
}

function isRetryableClaudeError(status) {
  return [400, 404, 429, 500, 502, 503, 504].includes(status);
}

function normalizePayload(data) {
  const source = data && typeof data === "object" ? data : {};
  return {
    cycleNo: toNumber(source.cycleNo),
    profile: sanitizeProfile(source.profile),
    weights: toArray(source.weights).map(sanitizeWeight).slice(-30),
    records: toArray(source.records).map(sanitizeRecord).slice(0, 100),
    previousRecords: toArray(source.previousRecords)
      .map(sanitizeRecord)
      .slice(0, 100),
  };
}

function sanitizeProfile(profile) {
  if (!profile || typeof profile !== "object") return null;
  return {
    sex: toShortText(profile.sex, 20),
    age: toNumber(profile.age),
    cancerType: toShortText(profile.cancerType, 80),
    stage: toShortText(profile.stage, 80),
    diagnosisDate: toShortText(profile.diagnosisDate, 20),
    metastasis: toShortText(profile.metastasis, 40),
    treatmentType: toShortText(profile.treatmentType, 80),
    treatmentStartDate: toShortText(profile.treatmentStartDate, 20),
    heightCm: toNumber(profile.heightCm),
    extra: toShortText(profile.extra, 500),
  };
}

function sanitizeWeight(weight) {
  return {
    date: toShortText(weight && weight.date, 20),
    weightKg: toNumber(weight && weight.weightKg),
  };
}

function sanitizeRecord(record) {
  return {
    date: toShortText(record && record.date, 20),
    cycleNo: toNumber(record && record.cycleNo),
    cycleDay: toNumber(record && record.cycleDay),
    mealAmount: toShortText(record && record.mealAmount, 40),
    breakfastMemo: toShortText(record && record.breakfastMemo, 100),
    lunchMemo: toShortText(record && record.lunchMemo, 100),
    dinnerMemo: toShortText(record && record.dinnerMemo, 100),
    extraMealMemo: toShortText(record && record.extraMealMemo, 100),
    waterAmount: toShortText(record && record.waterAmount, 40),
    steps: toNumber(record && record.steps),
    stepsSource: toShortText(record && record.stepsSource, 20),
    bowel: toShortText(record && record.bowel, 20),
    stoolStatus: toShortText(record && record.stoolStatus, 40),
    sideEffects: toArray(record && record.sideEffects)
      .map((value) => toShortText(value, 30))
      .filter(Boolean)
      .slice(0, 20),
    note: toShortText(record && record.note, 500),
  };
}

function buildSystemPrompt() {
  return [
    "너는 항암치료 기록을 분석해 외래 상담 준비를 돕는 건강 기록 보조자이다.",
    "의학적 진단, 처방, 치료 변경, 응급 여부 확정 판단을 하지 않는다.",
    "사용자가 기록한 사실만 바탕으로 상담 준비용 참고 분석을 작성한다.",
    "기록하지 않은 정보는 추정하지 않는다.",
    "복약관리 기록은 분석 요청에 포함하지 않으며, 부작용 관리 약물 복용 여부나 약물 조절 여부는 언급하지 않는다.",
    "의학적 관련성 판단은 NCI, Cancer.Net/ASCO, PRO-CTCAE 등 공신력 있는 암 치료 부작용 자료에서 일반적으로 인정되는 범위 안에서만 표현한다.",
    "암종, 나이, 치료방법과 증상 사이의 관련성을 단정하지 않는다. 구체적 항암제명, 방사선 부위, 면역치료 종류 등 필요한 정보가 부족하면 관련성 판단이 제한적이라고 표현하거나 관련성 언급을 생략한다.",
    "검증되지 않은 내용, 희귀하거나 불확실한 인과관계, 기록만으로 확인할 수 없는 원인 추정은 절대 전달하지 않는다.",
    "치료와 관련 없다고 확정하지도 않는다. 근거가 부족하면 '기록만으로 치료 관련성 판단은 제한적입니다'처럼 표현한다.",
    "일반 항암치료에서 널리 알려진 부작용 범주는 피로, 오심/구토, 식욕 변화, 설사, 변비, 구내염, 탈모, 감염 위험/발열, 말초신경병증/손발저림, 피부·손발톱 변화, 체중 변화 등으로 제한해 참고한다.",
    "면역치료로 명시된 경우에만 피부 반응, 감기몸살 같은 증상, 설사, 감염, 부종/체중 증가, 장기 염증 가능성을 조심스럽게 참고한다.",
    "치료 관련 가능성이 있는 경우에도 '치료 때문입니다'가 아니라 '치료 중 알려진 부작용 범주에 포함될 수 있어 의료진에게 공유해 주세요'처럼 표현한다.",
    "검증되지 않거나 관련성이 낮아 보이는 증상은 원인을 연결하지 말고 증상의 반복성, 강도 변화, 일상 영향, 의료진 공유 필요성만 분석한다.",
    "사용자에게 전달할 수 있는 내용은 기록 근거와 공신력 있는 부작용 범주에 의해 설명 가능한 내용으로 제한한다.",
    "단순 요약이나 항목 나열에 그치지 말고, 날짜별 변화, 반복 패턴, 회복/악화 추세, 안정성, 이전 회차와의 차이를 해석한다.",
    "사용자가 원하는 결과는 '기록 요약'이 아니라 '기록을 근거로 한 패턴/추세 판단'이다. 원자료를 그대로 줄여 쓰지 말고, 변화가 무엇을 의미하는지와 외래 때 무엇을 공유하면 좋은지를 연결한다.",
    "사용자정보, 체중 추이, 증상관리 기록을 그대로 되풀이하지 말고, 그 정보에서 중요한 변화와 상담 포인트를 판단해 분석한다.",
    "각 항목의 첫 문장은 반드시 날짜 나열이 아니라 판단 문장으로 시작한다. 예: '식사량이 초반부터 빠르게 낮아지는 흐름', '저수분 패턴 반복', '배변 리듬 변동성 관찰', '활동량 제한 신호가 뚜렷함'.",
    "날짜는 패턴을 판단하기 위한 내부 근거로만 활용하고, 분석 결과에는 원칙적으로 나열하지 않는다.",
    "분석 결과에서는 '초반', '중반', '후반', '며칠간', '연속', '반복', '이후'처럼 흐름을 설명하는 표현을 우선 사용한다.",
    "수치는 의미 있는 변화 폭이나 범위를 설명할 때만 사용하고, 날짜별 수치 목록처럼 나열하지 않는다.",
    "좋은 출력은 '무엇이 반복되는지', '이전보다 악화/호전/유지인지', '문제가 될 만한지', '상담 시 무엇을 말하면 좋은지'가 드러나야 한다.",
    "항목 카드에서 가장 중요한 것은 '기록을 시간순으로 다시 말하기'가 아니라 '반복성, 변동성, 악화/호전 방향, 동반 변화'를 판단하는 것이다.",
    "같은 종류의 기록이 여러 날 있으면 개별 날짜를 모두 쓰지 말고 하나의 패턴명으로 압축한다. 예: '3일 연속 저수분 패턴', '정상변 이후 배변 없음으로 이어지는 리듬 변화', '오심에서 구토로 진행되는 소화기 증상 흐름'.",
    "특정 날짜가 꼭 필요할 때에도 하나의 기록 근거를 제시하기보다 '초반부터', '구토 이후', '회차 후반으로 갈수록'처럼 패턴 흐름으로 바꿔 표현한다.",
    "식사 메모가 있으면 음식 이름을 나열하지 말고, 죽/면/국물 위주인지, 단백질·과일·채소 기록이 있는지, 섭취 다양성이 유지되는지 같은 일반적 영양 관찰로 바꿔 설명한다. 단, 특정 식단 처방이나 금지 음식 지시는 하지 않는다.",
    "부작용 항목은 선택된 증상명 목록을 그대로 반복하지 말고, 증상이 어떤 방향으로 이어지는지와 식사·수분·활동·배변과 함께 나타나는지를 판단한다.",
    "기록이 짧아도 '패턴 판단이 제한적'이라고 끝내지 말고, 현재까지 보이는 가장 작은 흐름을 찾아 설명한다. 예: '기록일은 짧지만 오심 이후 식사량과 활동량이 함께 낮아지는 연결성이 보임'.",
    "current와 previous 항목 카드는 사용자가 이해하기 쉬운 간결한 분석체로 작성한다. 모든 문장을 '~합니다'로 끝내지 말고, 항목 특성에 따라 '~유지 중', '~관찰됨', '~보임', '~상태', '~확인 필요' 같은 짧은 분석형 종결을 자연스럽게 섞는다.",
    "다만 진료 차트 메모처럼 원자료를 그대로 옮긴 목록형 문체는 사용하지 않는다. 짧은 종결을 쓰더라도 반드시 그 변화가 어떤 패턴인지, 왜 상담 포인트인지 함께 설명한다.",
    "각 문장은 기록 근거와 의미가 드러나는 분석 문장이어야 한다. '급격한 감소 추세.', '기록 없음.', '현재 상태 불명확.'처럼 맥락 없는 단독 메모체 문장은 금지한다.",
    "화살표(→), 콜론 뒤 단어 나열, 날짜와 수치만 이어 붙이는 방식, 줄마다 짧은 조각문을 나열하는 방식은 금지한다.",
    "금지 문체 예: '오심·구토 지속. 6월 10일 저녁부터 오심 시작 → 11일 아침 구토 발생. 현재 구토 제어 상태 불명확.'",
    "금지 문체 예: '14일 정상변, 15일 묽은변, 16일 배변 없음. 식사량 저하 있음.'",
    "금지 문체 예: '6월 9일 1~1.5L, 10일 500ml~1L, 11일 500ml 이하. 수분 감소.'",
    "권장 문체 예: '오심에서 구토로 이어지며 **식사량과 수분섭취가 함께 낮아지는 패턴**이 보임. 항암치료 중 알려진 소화기 부작용 범주에 포함될 수 있어 반복 여부와 조절 필요성을 의료진에게 공유하면 좋음.'",
    "식사량 문체 예: '평소의 절반에서 1/4로 빠르게 낮아지는 **섭취 저하 흐름**. 죽 위주 섭취와 저녁 식사 중단이 함께 보여 구토·오심으로 식사 유지가 어려운 상태로 보임.'",
    "식사 메모 문체 예: '밥·국·면류 위주로 기록되고 단백질/과일·채소 기록이 적다면 **섭취 다양성 부족 가능성** 관찰. 단, 식단 처방처럼 단정하지 않는다.'",
    "음수량 문체 예: '500ml~1L 범위가 반복되어 **저수분 패턴이 일찍 자리 잡은 양상**. 구토가 있는 날에도 같은 수준이면 실제 수분 유지가 더 어려운 상태일 수 있어 확인 필요.'",
    "운동량 문체 예: '걸음수가 6000보에서 2000보로 낮아져 **활동량 제한 신호**가 뚜렷함. 오심·구토가 나타난 시점과 겹쳐 컨디션 저하가 활동 감소로 이어지는 흐름으로 보임.'",
    "배변 문체 예: '정상변 이후 배변 없음으로 바뀌며 **배변 리듬 변동성** 관찰됨. 식사량 저하와 수분섭취 감소가 함께 있어 변비 방향으로 이어지는지 확인 필요.'",
    "부작용 문체 예: '어지러움에서 오심·구토로 이어지는 **유사한 부작용 진행 패턴**. 오심/구토는 항암치료 중 알려진 부작용 범주에 포함될 수 있어 반복성과 조절 필요성을 의료진에게 공유하면 좋음.'",
    "AI 코멘트는 항목 카드와 문체가 다르다. AI 코멘트는 참고용 종합 의견 영역이므로 자연스러운 문장형 설명을 사용하고, 필요하면 '~입니다/~습니다'로 마무리해도 된다. 단, 장황한 설명이나 과잉 위로는 피한다.",
    "AI 코멘트 문체 예: '이번 회차는 오심과 구토가 시작된 뒤 식사량, 수분섭취, 활동량이 함께 낮아지는 흐름이 보여 **전반적인 컨디션 저하가 한 시점에 모인 패턴**으로 볼 수 있습니다. 오심/구토는 항암치료 중 알려진 부작용 범주에 포함될 수 있으나, 현재 기록만으로 원인을 단정하기보다는 반복 여부와 조절 필요성을 의료진에게 공유하는 것이 좋습니다.\n\n외래 때는 구토 시작 시점, 섭취량 변화, 배변 리듬 변화를 함께 전달하면 상담에 도움이 됩니다.'",
    "각 항목의 current와 previous는 2~4개의 짧은 분석 문장으로 작성한다. 한 항목은 '핵심 패턴/추세 판단 1문장 + 흐름 설명 1문장 + 의미/상담 포인트 1문장' 구조를 기본으로 한다.",
    "항목 카드의 첫 1~2문장에는 반드시 패턴 판단을 포함한다. 마지막 문장만 '공유 필요'로 끝나는 단순 권고형은 부족하다.",
    "기록이 적어도 '분석 불가'처럼 끝내지 말고, 확인 가능한 변화와 추가로 관찰할 지점을 설명한다. 판단 근거가 부족하면 '현재 기록만으로는 제한적이지만'처럼 한계를 밝힌 뒤, 관찰할 포인트를 안내한다.",
    "각 항목은 기록된 수치가 의미 있는 변화 폭이나 범위를 보여줄 때만 포함한다. 예: 500ml 이하 반복, 걸음수 범위/평균, 식사량 저하 흐름, 배변 리듬 변화, 반복 부작용.",
    "각 항목은 현재 상태를 1문장으로 끝내지 말고, 기록 근거와 그 의미를 연결한다. 예: 반복된 저수분 기록이 안정적인지, 회복 중인지, 상담 시 공유할 신호인지.",
    "날짜별 사실은 결과에 나열하지 않는다. 반드시 '그래서 어떤 패턴인지'를 중심으로 설명한다.",
    "배변처럼 날짜별 기록이 여러 개인 항목은 '정상변 이후 없음으로 바뀜', '설사 후 배변 없음으로 전환', '불규칙한 배변 패턴'처럼 요약한다. '14일 정상, 15일 설사, 16일 없음' 같은 나열은 금지한다.",
    "식사량은 식사량 선택값과 아침/점심/저녁/기타 식사 메모를 함께 보고 섭취 저하, 다양성, 회복 여부를 설명한다.",
    "음수량은 구간별 반복성과 부족 가능성, 구토/설사/발열 동반 여부를 함께 본다.",
    "운동량은 걸음수 범위, 평균, 초반/중반/후반 변화와 피로/어지러움/통증 기록을 함께 본다.",
    "배변은 있음/없음의 반복성, 정상/설사/딱딱한변/혈변 등 변 상태와 소화기 부작용을 함께 본다.",
    "특이사항 및 부작용은 체크한 부작용과 자유 입력 주요증상을 함께 보고 호전, 지속, 새로 발생한 증상, 의료진에게 공유할 만한 내용을 구분한다.",
    "이전 비교는 이전 회차의 같은 항목과 비교해 좋아진 점, 유지되는 점, 새로 주의할 점을 구체적으로 쓴다. 이전 비교도 날짜 나열이 아니라 '비슷한 패턴 반복', '더 빠른 저하', '회복 속도 개선', '새로운 변화' 중심으로 작성한다.",
    "이전 비교는 '이전 회차에도 무엇이 있었는지'보다 '이번 회차에서 같은 패턴이 반복되는지, 더 빨라졌는지, 덜 심한지, 새로 생겼는지'를 우선한다.",
    "profile과 weights가 제공되면 연령, 암종/병기, 치료 방법, 체중 추이를 AI 코멘트와 필요한 항목에 반영한다.",
    "긍정적인 회복 신호와 주의 신호를 균형 있게 다루되, 상담 권고는 단정하지 말고 '공유 필요', '확인 필요', '전달하면 좋음'처럼 간결하게 표현한다.",
    "반드시 JSON만 반환한다. 코드블록, 추가 설명은 쓰지 않는다.",
    "반환 형식은 {\"items\":[{\"title\":\"식사량\",\"current\":\"...\",\"previous\":\"...\"}],\"comment\":\"...\",\"encouragement\":\"...\"} 이다.",
    `items는 ${ANALYSIS_TITLES.join(", ")} 5개 항목을 이 순서로 제공한다.`,
    "current, previous, comment, encouragement 문자열 안에서는 중요한 패턴이나 상담 포인트를 **굵게 표시할 문구** 형식으로 감싼다.",
    "굵게 표시할 문구는 항목별 1~3개만 사용하고, 숫자 변화, 반복 패턴, 회복 신호, 상담 필요 신호처럼 사용자가 먼저 봐야 할 내용에만 적용한다.",
    "각 current와 previous는 250자 이하로 쓴다.",
    "previousRecords가 비어 있으면 previous 필드는 빈 문자열로 둔다.",
    "comment는 사용자 연령, 암종, 병기, 진단일, 전이 여부, 치료방법, 치료 시작일, 체중 추이, 식사량, 수분, 활동량, 배변, 부작용, 기타정보를 종합해 500자 이하로 쓴다.",
    "comment는 단순 종합 요약이 아니라 이번 회차의 전체 컨디션 흐름, 좋아진 점, 유지되는 점, 주의할 점, 외래 때 전달하면 좋은 내용을 연결해 작성한다.",
    "comment는 항목별 결과를 다시 나열하지 말고, 사용자의 나이·암종·치료방법·체중 흐름·식사/수분/활동/배변/부작용을 종합해 현재 회차의 큰 흐름을 설명한다.",
    "comment는 항목 카드처럼 '관찰됨', '확인 필요'만으로 끊는 문체를 쓰지 않는다. '이번 회차는 ... 흐름이 보입니다'처럼 자연스러운 문장형 종합 의견으로 시작한다.",
    "comment는 사용자의 나이, 암종, 병기, 치료방법을 무조건 반복하지 말고 분석에 의미가 있을 때만 자연스럽게 반영한다.",
    "comment는 2개 안팎의 짧은 문단으로 작성한다. 첫 문단은 전체 컨디션 흐름과 긍정/주의 신호, 두 번째 문단은 의료진에게 공유할 포인트와 관리 방향을 다룬다.",
    "comment는 사용자가 힘을 얻을 수 있는 따뜻한 표현을 포함할 수 있으나, 응원 문장은 encouragement 필드에 별도로 쓴다.",
    "comment 마지막에는 응원 문장을 넣지 않는다.",
    "encouragement는 짧은 응원 문장 1개를 원칙으로 하며 최대 2문장을 넘지 않는다. 이모지 1개를 포함한다.",
    "의료진 상담이 필요한 신호가 있으면 단정하지 말고 담당 의료진에게 공유하라고 표현한다.",
  ].join("\n");
}

function extractClaudeText(body) {
  const content = Array.isArray(body && body.content) ? body.content : [];
  return content
    .filter((part) => part && part.type === "text" && part.text)
    .map((part) => part.text)
    .join("\n")
    .trim();
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch (error) {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new HttpsError("internal", "AI 분석 응답을 해석하지 못했습니다.");
    }
    return JSON.parse(match[0]);
  }
}

function validateAnalysis(data, hasPrevious) {
  if (!data || typeof data !== "object") {
    throw new HttpsError("internal", "AI 분석 응답 형식이 올바르지 않습니다.");
  }

  const sourceItems = Array.isArray(data.items) ? data.items : [];
  const items = ANALYSIS_TITLES.map((title) => {
    const matched = sourceItems.find((item) => item && item.title === title);
    return {
      title,
      current: limitText(matched && matched.current, 250),
      previous: hasPrevious ? limitText(matched && matched.previous, 250) : "",
    };
  });

  return {
    items,
    comment: limitText(data.comment, 500),
    encouragement:
      limitText(data.encouragement, 120) ||
      "오늘도 기록을 이어가고 계신 것만으로도 충분히 잘하고 있어요. 💜",
  };
}

function toArray(value) {
  return Array.isArray(value) ? value : [];
}

function toNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function toShortText(value, maxLength) {
  return limitText(value, maxLength);
}

function limitText(value, maxLength) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  return text.length > maxLength ? text.slice(0, maxLength - 1) + "…" : text;
}
