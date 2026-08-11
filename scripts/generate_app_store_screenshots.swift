import AppKit
import Foundation

let canvasSize = NSSize(width: 1290, height: 2796)
let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = cwd.appendingPathComponent("screenshots/app_store", isDirectory: true)
let downloadDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
let iconURL = cwd.appendingPathComponent("assets/app_icon.png")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let captures: [String: URL] = [
    "medication": downloadDir.appendingPathComponent("KakaoTalk_Photo_2026-06-21-18-47-37 001.png"),
    "weightNormal": downloadDir.appendingPathComponent("KakaoTalk_Photo_2026-06-21-18-47-38 002.png"),
    "weightAlert": downloadDir.appendingPathComponent("KakaoTalk_Photo_2026-06-21-18-47-38 003.png"),
    "symptom": downloadDir.appendingPathComponent("KakaoTalk_Photo_2026-06-21-18-47-38 004.png"),
    "aiLoading": downloadDir.appendingPathComponent("KakaoTalk_Photo_2026-06-21-18-47-38 005.png"),
    "aiReportA": downloadDir.appendingPathComponent("KakaoTalk_Photo_2026-06-21-18-47-38 006.png"),
    "aiReportB": downloadDir.appendingPathComponent("KakaoTalk_Photo_2026-06-21-18-47-38 007.png"),
]

let text = NSColor(calibratedRed: 31 / 255, green: 41 / 255, blue: 55 / 255, alpha: 1)
let muted = NSColor(calibratedRed: 131 / 255, green: 139 / 255, blue: 154 / 255, alpha: 1)
let accent = NSColor(calibratedRed: 109 / 255, green: 53 / 255, blue: 232 / 255, alpha: 1)
let bg = NSColor(calibratedRed: 240 / 255, green: 235 / 255, blue: 255 / 255, alpha: 1)
let bgCard = NSColor(calibratedRed: 248 / 255, green: 246 / 255, blue: 255 / 255, alpha: 1)

struct Shot {
    let fileName: String
    let eyebrow: String
    let title: String
    let body: String
    let layout: Layout
}

enum Layout {
    case single(String, CGFloat)
    case weightCompare
    case aiLongReport
}

let shots: [Shot] = [
    Shot(
        fileName: "01_medication_real.png",
        eyebrow: "복약 알림부터 치료 루틴까지",
        title: "약 복용 시간을\n놓치지 않게",
        body: "항구토제, 진통제처럼 치료 중 필요한 약을 등록하고 알림 상태를 한눈에 확인합니다.",
        layout: .single("medication", 0.78)
    ),
    Shot(
        fileName: "02_weight_real.png",
        eyebrow: "체중 변화도 증상 흐름의 일부니까",
        title: "BMI와 체중 변화를\n같이 기록",
        body: "체중 증가나 감소 신호를 캘린더에서 확인하고, 상담이 필요한 변화는 놓치지 않습니다.",
        layout: .weightCompare
    ),
    Shot(
        fileName: "03_symptom_real.png",
        eyebrow: "회차별 생활 반응을 매일 기록",
        title: "증상이 언제\n심해졌는지 보여줘요",
        body: "오심, 구토, 두통처럼 주요 부작용을 항암 회차와 날짜 기준으로 정리합니다.",
        layout: .single("symptom", 0.82)
    ),
    Shot(
        fileName: "04_ai_loading_real.png",
        eyebrow: "기록이 쌓이면 AI가 분석",
        title: "회차별 증상 데이터를\nAI가 읽어요",
        body: "동일 항암 회차의 기록을 요약하고, 이전 회차와 비교할 준비를 합니다.",
        layout: .single("aiLoading", 0.82)
    ),
    Shot(
        fileName: "05_ai_report_real.png",
        eyebrow: "가장 중요한 강점",
        title: "외래 전에 말할 내용을\nAI가 정리",
        body: "식사량, 음수량, 운동량, 배변, 특이사항을 모아 상담 전 확인할 포인트로 정리합니다.",
        layout: .aiLongReport
    ),
]

for shot in shots {
    let image = NSImage(size: canvasSize)
    image.lockFocus()
    drawShot(shot)
    image.unlockFocus()
    try save(image, to: outputDir.appendingPathComponent(shot.fileName))
    print("saved \(shot.fileName)")
}

func drawShot(_ shot: Shot) {
    drawBackground()
    drawBrand()
    drawText(
        shot.eyebrow,
        x: 86,
        y: 250,
        width: 1118,
        fontSize: 42,
        weight: .semibold,
        color: muted,
        align: .center
    )
    drawText(
        shot.title,
        x: 86,
        y: 330,
        width: 1118,
        fontSize: 90,
        weight: .heavy,
        color: text,
        lineHeight: 1.08,
        align: .center
    )
    drawText(
        shot.body,
        x: 128,
        y: 580,
        width: 1034,
        fontSize: 35,
        weight: .medium,
        color: muted,
        lineHeight: 1.34,
        align: .center
    )

    switch shot.layout {
    case let .single(key, scale):
        if let image = loadCapture(key) {
            drawScreenshot(
                image,
                x: (canvasSize.width - 1179 * scale) / 2,
                y: 820,
                width: 1179 * scale,
                height: 2556 * scale,
                radius: 78
            )
        }
    case .weightCompare:
        if let normal = loadCapture("weightNormal"), let alert = loadCapture("weightAlert") {
            drawScreenshot(normal, x: 78, y: 820, width: 620, height: 1345, radius: 62)
            drawScreenshot(alert, x: 592, y: 1020, width: 620, height: 1345, radius: 62)
            drawPill("상담 권고 변화까지", x: 686, y: 910)
        }
    case .aiLongReport:
        drawLongAIReport()
    }
}

func drawBackground() {
    bg.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()
    fillRound(rect(-230, 140, 560, 560), radius: 280, color: accent.withAlphaComponent(0.08))
    fillRound(rect(966, 720, 430, 430), radius: 215, color: NSColor.white.withAlphaComponent(0.28))
    fillRound(rect(140, 762, 1010, 1900), radius: 92, color: bgCard.withAlphaComponent(0.64))
}

func drawBrand() {
    let iconRect = rect(84, 88, 92, 92)
    if let icon = NSImage(contentsOf: iconURL) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: iconRect, xRadius: 24, yRadius: 24).addClip()
        icon.draw(in: iconRect)
        NSGraphicsContext.restoreGraphicsState()
    }
    drawText("항암기록관리", x: 198, y: 96, width: 360, fontSize: 34, weight: .bold, color: text)
    drawText("AI 항암 증상 리포트", x: 198, y: 142, width: 380, fontSize: 25, weight: .medium, color: muted)
}

func drawLongAIReport() {
    guard let top = loadCapture("aiLoading"),
          let reportA = loadCapture("aiReportA"),
          let reportB = loadCapture("aiReportB") else { return }

    drawScreenshot(top, x: 126, y: 790, width: 520, height: 1128, radius: 54)
    drawScreenshot(reportA, x: 394, y: 920, width: 760, height: 1648, radius: 62)
    drawScreenshot(reportB, x: 136, y: 1510, width: 760, height: 1648, radius: 62)
    drawPill("AI 분석 결과", x: 470, y: 850)
    drawPill("이전 회차 비교", x: 214, y: 1440)
    drawPill("외래 전 전달 포인트", x: 214, y: 2470)
}

func drawPill(_ value: String, x: CGFloat, y: CGFloat) {
    let width = CGFloat(value.count) * 24 + 58
    fillRound(rect(x, y, width, 62), radius: 31, color: accent)
    drawText(value, x: x, y: y + 16, width: width, fontSize: 25, weight: .bold, color: .white, align: .center)
}

func loadCapture(_ key: String) -> NSImage? {
    guard let url = captures[key] else { return nil }
    return NSImage(contentsOf: url)
}

func drawScreenshot(
    _ image: NSImage,
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat,
    radius: CGFloat,
    crop: NSRect? = nil
) {
    let destination = rect(x, y, width, height)
    shadow(destination, radius: 34, y: -18, alpha: 0.14)
    fillRound(destination, radius: radius, color: .white)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: destination, xRadius: radius, yRadius: radius).addClip()
    image.draw(
        in: destination,
        from: crop ?? NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
}

func drawText(
    _ value: String,
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    lineHeight: CGFloat = 1.2,
    align: NSTextAlignment = .left
) {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    style.lineSpacing = fontSize * (lineHeight - 1)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    let height = CGFloat(value.components(separatedBy: "\n").count) * fontSize * lineHeight + fontSize
    NSString(string: value).draw(
        with: rect(x, y, width, height),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attrs
    )
}

func rect(_ x: CGFloat, _ yFromTop: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasSize.height - yFromTop - height, width: width, height: height)
}

func fillRound(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func shadow(_ rect: NSRect, radius: CGFloat, y: CGFloat, alpha: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.shadowBlurRadius = radius
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 64, yRadius: 64).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func save(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ScreenshotGenerator", code: 1)
    }
    try png.write(to: url)
}
