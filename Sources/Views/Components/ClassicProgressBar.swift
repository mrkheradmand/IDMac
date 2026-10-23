import SwiftUI

public struct ClassicProgressBar: View {
    public let progress: Double
    public var height: CGFloat = 16
    public var showPercentage: Bool = true

    public init(progress: Double, height: CGFloat = 16, showPercentage: Bool = true) {
        self.progress = progress
        self.height = height
        self.showPercentage = showPercentage
    }

    public var body: some View {
        GeometryReader { geo in
            let clampedProgress = min(1.0, max(0.0, progress))
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                // Fill
                if clampedProgress > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.85),
                                    Color.cyan.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(clampedProgress)))
                        .overlay(
                            // Subtle classic highlight
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }

                // Text Percentage overlay
                if showPercentage {
                    Text("\(Int(clampedProgress * 100))%")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(clampedProgress > 0.5 ? .white : .primary)
                        .shadow(color: .black.opacity(clampedProgress > 0.5 ? 0.4 : 0.0), radius: 1, x: 0, y: 1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(height: height)
    }
}
