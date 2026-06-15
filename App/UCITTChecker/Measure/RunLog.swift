import Foundation
import UCITTCore

/// One recorded measurement run, for debugging accuracy. Captures the raw inputs
/// (the 3D landmark points in ARKit mode) alongside the computed results, so a
/// bad number can be traced back to a mis-placed point.
struct RunRecord: Codable {
    let date: Date
    let mode: String
    let heightCm: Double
    let category: String
    let overall: String
    /// Raw gravity-aligned landmark points in mm (ARKit mode; empty otherwise).
    let points3DmmByLandmark: [String: Point3]
    let measurements: [Recorded]

    struct Recorded: Codable {
        let kind: String
        let value: Double
        let limit: Double
        let margin: Double
        let state: String
    }

    init(date: Date = Date(),
         mode: String,
         heightCm: Double,
         report: ResultReport,
         points3D: [Landmark: Point3]) {
        self.date = date
        self.mode = mode
        self.heightCm = heightCm
        self.category = report.category.rawValue
        self.overall = report.overallState.rawValue
        self.points3DmmByLandmark = Dictionary(
            uniqueKeysWithValues: points3D.map { ($0.key.rawValue, $0.value) })
        self.measurements = report.measurements.map {
            Recorded(kind: $0.kind.rawValue, value: $0.value,
                     limit: $0.limit, margin: $0.margin, state: $0.state.rawValue)
        }
    }
}

/// Append-only run log persisted as JSON Lines in the app's Documents folder,
/// plus helpers to render a single run as readable text for quick sharing.
enum RunLog {
    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("ucitt-runs.jsonl")
    }

    static func append(_ record: RunRecord) {
        guard var data = try? JSONEncoder().encode(record) else { return }
        data.append(0x0A) // newline
        if FileManager.default.fileExists(atPath: fileURL.path),
           let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }

    static func wholeLogText() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "(no runs logged yet)"
    }

    /// Human-readable single-run summary including the raw points and the key
    /// pairwise distances that feed each measurement, for debugging.
    static func text(for record: RunRecord, points3D: [Landmark: Point3]) -> String {
        var lines: [String] = []
        let df = ISO8601DateFormatter()
        lines.append("UCI TT run · \(df.string(from: record.date))")
        lines.append("mode=\(record.mode) height=\(record.heightCm)cm category=\(record.category) overall=\(record.overall)")
        lines.append("")
        lines.append("Measurements:")
        for m in record.measurements {
            let lim = m.limit.isNaN ? "—" : String(format: "%.0f", m.limit)
            let mar = m.margin.isNaN ? "—" : String(format: "%+.0f", m.margin)
            lines.append(String(format: "  %@: %.1f (limit %@, margin %@, %@)",
                                m.kind, m.value, lim, mar, m.state))
        }
        if !points3D.isEmpty {
            lines.append("")
            lines.append("Raw 3D points (mm, gravity-aligned x/y/z):")
            for lm in Landmark.captureOrder {
                if let p = points3D[lm] {
                    lines.append(String(format: "  %@: (%.0f, %.0f, %.0f)",
                                        lm.rawValue, p.x, p.y, p.z))
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
