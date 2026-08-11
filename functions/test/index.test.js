const assert = require("node:assert/strict");
const test = require("node:test");

const { _test } = require("../index.js");

function validPayload(overrides = {}) {
  return _test.normalizePayload({
    cycleNo: 2,
    profile: {
      age: 52,
      heightCm: 162,
      diagnosisDate: "2026-01-15",
      treatmentStartDate: "2026-04-01",
    },
    weights: [{ date: "2026-06-14", weightKg: 51.2 }],
    records: [
      {
        date: "2026-06-14",
        cycleNo: 2,
        cycleDay: 3,
        mealAmount: "절반",
        waterAmount: "1~1.5L",
        steps: 1500,
        bowel: "있음",
        sideEffects: ["오심"],
      },
    ],
    previousRecords: [
      {
        date: "2026-05-14",
        cycleNo: 1,
        cycleDay: 3,
        mealAmount: "평소와 같음",
        waterAmount: "1~1.5L",
        steps: 2200,
        bowel: "있음",
        sideEffects: ["없음"],
      },
    ],
    ...overrides,
  });
}

test("validates accepted AI analysis payload ranges", () => {
  assert.doesNotThrow(() => _test.validatePayloadForAnalysis(validPayload()));
});

test("normalizes AI analysis requests to cycle number only", () => {
  assert.deepEqual(_test.normalizeAnalysisRequest({ cycleNo: "3" }), {
    cycleNo: 3,
  });
});

test("rejects invalid cycle, profile, weight, and symptom values", () => {
  assert.throws(
    () => _test.validatePayloadForAnalysis(validPayload({ cycleNo: 101 })),
    /항암 회차/,
  );
  assert.throws(
    () =>
      _test.validatePayloadForAnalysis(
        validPayload({ profile: { age: 52, heightCm: 12 } }),
      ),
    /사용자 정보/,
  );
  assert.throws(
    () =>
      _test.validatePayloadForAnalysis(
        validPayload({ weights: [{ date: "2026-06-14", weightKg: 8 }] }),
      ),
    /체중 기록/,
  );
  assert.throws(
    () =>
      _test.validatePayloadForAnalysis(
        validPayload({
          records: [{ date: "2026-02-31", cycleNo: 2, cycleDay: 1, steps: 0 }],
        }),
      ),
    /기록 날짜/,
  );
  assert.throws(
    () =>
      _test.validatePayloadForAnalysis(
        validPayload({
          records: [
            { date: "2026-06-14", cycleNo: 2, cycleDay: 101, steps: 0 },
          ],
        }),
      ),
    /증상 기록/,
  );
});

test("parses JSON even when the model wraps it in extra text", () => {
  const parsed = _test.parseJson(
    "result:\n{\"items\":[],\"comment\":\"ok\",\"encouragement\":\"go\"}\nthanks",
  );

  assert.equal(parsed.comment, "ok");
});

test("normalizes analysis schema and fills expected item order", () => {
  const result = _test.validateAnalysis(
    {
      items: [
        { title: "운동량", current: "활동량 제한 신호", previous: "이전보다 감소" },
      ],
      comment: "이번 회차는 수분과 활동량 확인이 필요합니다.",
      encouragement: "",
    },
    true,
  );

  assert.deepEqual(
    result.items.map((item) => item.title),
    ["식사량", "음수량", "운동량", "배변", "특이사항"],
  );
  assert.equal(result.items[2].current, "활동량 제한 신호");
  assert.match(result.encouragement, /기록/);
});
