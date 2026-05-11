import SwiftUI

struct MetricsView: View {
    let metricsManager: MetricsManager
    let profileManager: UserProfileManager

    private var metrics: Metrics { metricsManager.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroRow
                secondaryRow
                HeatmapView(data: metrics.heatmapData(weeks: 12))
                vocabRow
            }
            .padding(24)
        }
        .frame(width: 540)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var heroRow: some View {
        HStack(spacing: 16) {
            StatCard(
                value: "\(metrics.totalWords.formatted())",
                label: "words dictated",
                color: .primary
            )
            StatCard(
                value: formattedTimeSaved,
                label: "estimated time saved",
                color: .ebAccent
            )
        }
    }

    private var secondaryRow: some View {
        HStack(spacing: 16) {
            StatCard(value: "🔥 \(metrics.currentStreak)", label: "day streak", color: .primary)
            StatCard(value: "⚡ \(Int(metrics.averageWPM)) wpm", label: "avg dictation speed", color: .primary)
        }
    }

    private var vocabRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personal Dictionary")
                .font(.system(.headline, design: .serif))
            HStack {
                Text("\(profileManager.profile.customVocabulary.count)")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.orange)
                Text("custom words learned")
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 6) {
                ForEach(profileManager.profile.customVocabulary.prefix(12), id: \.self) { word in
                    Text(word)
                        .font(.system(.caption, design: .serif))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var formattedTimeSaved: String {
        let minutes = metrics.minutesSaved
        if minutes >= 60 {
            return String(format: "%.1f hrs", minutes / 60)
        }
        return String(format: "%.0f min", minutes)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct HeatmapView: View {
    let data: [(date: String, count: Int)]
    private let days = 7
    private let cellSize: CGFloat = 12
    private let gap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity — Last 12 Weeks")
                .font(.system(.headline, design: .serif))
            let grid = data.chunked(intoSize: days)
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<grid.count, id: \.self) { wi in
                    VStack(spacing: gap) {
                        ForEach(0..<grid[wi].count, id: \.self) { di in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: grid[wi][di].count))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0:        return Color(nsColor: .controlBackgroundColor)
        case 1...50:   return .green.opacity(0.3)
        case 51...150: return .green.opacity(0.6)
        default:       return .green
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > maxWidth { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

extension Array {
    func chunked(intoSize size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
