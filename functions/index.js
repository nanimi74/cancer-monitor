const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const CLAUDE_MODEL = process.env.ANTHROPIC_MODEL || "claude-3-5-haiku-20241022";
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

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": anthropicApiKey.value(),
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 1200,
        temperature: 0.2,
        system: buildSystemPrompt(),
        messages: [
          {
            role: "user",
            content: JSON.stringify(payload),
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("Claude API request failed", {
        status: response.status,
        errorText,
      });
      throw new HttpsError("internal", "AI 분석 요청에 실패했습니다.");
    }

    const body = await response.json();
    const text = extractClaudeText(body);
    const parsed = parseJson(text);
    return validateAnalysis(parsed, payload.previousRecords.length > 0);
  },
);

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
    "너는 항암치료 기록을 요약하는 건강 기록 보조자이다.",
    "의학적 진단, 처방, 치료 변경, 응급 여부 확정 판단을 하지 않는다.",
    "사용자가 기록한 사실만 바탕으로 상담 준비용 참고 요약을 작성한다.",
    "기록하지 않은 정보는 추정하지 않는다.",
    "반드시 JSON만 반환한다. 마크다운, 코드블록, 추가 설명은 쓰지 않는다.",
    "반환 형식은 {\"items\":[{\"title\":\"식사량\",\"current\":\"...\",\"previous\":\"...\"}],\"comment\":\"...\",\"encouragement\":\"...\"} 이다.",
    `items는 ${ANALYSIS_TITLES.join(", ")} 5개 항목을 이 순서로 제공한다.`,
    "각 current와 previous는 150자 이하로 쓴다.",
    "previousRecords가 비어 있으면 previous 필드는 빈 문자열로 둔다.",
    "comment는 사용자 연령, 암종, 병기, 진단일, 전이 여부, 치료방법, 치료 시작일, 체중 추이, 식사량, 수분, 활동량, 배변, 부작용, 기타정보를 종합해 300자 이하로 쓴다.",
    "profile과 weights가 제공되면 반드시 분석 맥락에 반영하되, 기록되지 않은 값은 추정하지 않는다.",
    "comment 마지막에는 응원 문장을 넣지 않는다.",
    "encouragement는 짧은 응원 문장 1개이며 이모지 1개를 포함한다.",
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
      current: limitText(matched && matched.current, 150),
      previous: hasPrevious ? limitText(matched && matched.previous, 150) : "",
    };
  });

  return {
    items,
    comment: limitText(data.comment, 300),
    encouragement:
      limitText(data.encouragement, 80) ||
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
