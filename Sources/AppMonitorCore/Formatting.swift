import Foundation

public enum AppMonitorFormatting {
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }

    public static func bytes(_ bytes: Int64) -> String {
        if bytes == 0 {
            return "0 KB"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    public static func bytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "Not scanned" }
        return self.bytes(bytes)
    }

    public static func shortDateTime(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public static func tableDateTime(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy h:mm a"
        return formatter.string(from: date)
    }

    public static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
