import Foundation

/// Format minutes as "6h 20m" / "45m".
func fmtDur(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
}

/// "HH:mm" minus N minutes -> "HH:mm" (wraps across midnight).
/// Tolerates a trailing seconds component ("23:00:00") by ignoring it.
func offsetTime(from hhmm: String, minusMinutes: Int) -> String {
    let parts = hhmm.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return hhmm }
    var total = parts[0] * 60 + parts[1] - minusMinutes
    total = ((total % 1440) + 1440) % 1440
    return String(format: "%02d:%02d", total / 60, total % 60)
}

func greetingWord() -> String {
    let h = Calendar.current.component(.hour, from: Date())
    switch h {
    case 5..<12: return "Good morning"
    case 12..<18: return "Good afternoon"
    default: return "Good evening"
    }
}

/// Parse an ISO-ish "yyyy-MM-dd" or full timestamp into a short label "Jul 4".
func shortDate(_ raw: String) -> String {
    let iso = String(raw.prefix(10))
    let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"; inF.timeZone = .init(identifier: "UTC")
    guard let d = inF.date(from: iso) else { return iso }
    let outF = DateFormatter(); outF.dateFormat = "MMM d"
    return outF.string(from: d)
}

func weekdayShort(_ raw: String) -> String {
    let iso = String(raw.prefix(10))
    let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"; inF.timeZone = .init(identifier: "UTC")
    guard let d = inF.date(from: iso) else { return "" }
    let outF = DateFormatter(); outF.dateFormat = "EEE"
    return outF.string(from: d)
}
