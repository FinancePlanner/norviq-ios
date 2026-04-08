import SwiftUI
import Charts

struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct InteractiveLineChart: View {
    let data: [ChartDataPoint]
    let color: Color
    
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var dragLocation: CGPoint = .zero
    
    private var minDate: Date { data.first?.date ?? .now }
    private var maxDate: Date { data.last?.date ?? .now }
    private var minValue: Double { data.map { $0.value }.min() ?? 0 }
    private var maxValue: Double { data.map { $0.value }.max() ?? 1 }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Line path
                Path { path in
                    guard data.count > 1 else { return }
                    
                    let points = data.enumerated().map { index, point -> CGPoint in
                        let x = geometry.size.width * CGFloat(index) / CGFloat(data.count - 1)
                        let normalizedY = (point.value - minValue) / (maxValue - minValue)
                        let y = geometry.size.height * (1.0 - CGFloat(normalizedY))
                        return CGPoint(x: x, y: y)
                    }
                    
                    path.move(to: points.first!)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // Gradient fill
                Path { path in
                    guard data.count > 1 else { return }
                    
                    let points = data.enumerated().map { index, point -> CGPoint in
                        let x = geometry.size.width * CGFloat(index) / CGFloat(data.count - 1)
                        let normalizedY = (point.value - minValue) / (maxValue - minValue)
                        let y = geometry.size.height * (1.0 - CGFloat(normalizedY))
                        return CGPoint(x: x, y: y)
                    }
                    
                    path.move(to: points.first!)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.0)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Interactive Drag Line and Label
                if let selected = selectedDataPoint {
                    let xPos = geometry.size.width * CGFloat(data.firstIndex(of: selected) ?? 0) / CGFloat(max(1, data.count - 1))
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 1)
                        .offset(x: xPos)
                    
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(
                            x: xPos,
                            y: geometry.size.height * (1.0 - CGFloat((selected.value - minValue) / (maxValue - minValue)))
                        )
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text(selected.date.formatted(.dateTime.month().day()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(selected.value.formatted(.currency(code: "USD")))
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    .padding(6)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .position(
                        x: max(50, min(geometry.size.width - 50, xPos)),
                        y: -20
                    )
                }
                
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelectedPoint(at: value.location.x, in: geometry.size.width)
                            }
                            .onEnded { _ in
                                selectedDataPoint = nil
                            }
                    )
            }
        }
    }
    
    private func updateSelectedPoint(at x: CGFloat, in width: CGFloat) {
        guard data.count > 1 else { return }
        let progress = max(0, min(1, x / width))
        let index = Int(round(progress * CGFloat(data.count - 1)))
        let safeIndex = max(0, min(data.count - 1, index))
        
        if selectedDataPoint != data[safeIndex] {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedDataPoint = data[safeIndex]
        }
    }
}
