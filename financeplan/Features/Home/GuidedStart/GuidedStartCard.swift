import SwiftUI

struct GuidedStartCard: View {
  let progress: GuidedStartProgress
  var message: String?
  let onSelect: (GuidedStartStep) -> Void
  let onDismiss: () -> Void

  var body: some View {
    GlassCard(cornerRadius: 18) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(GuidedStartCopy.progress(completed: progress.completedCount))
              .typography(.nano)
              .foregroundStyle(.secondary)
            Text(GuidedStartCopy.headline)
              .typography(.small, weight: .semibold)
          }
          Spacer()
          Button("Hide \(GuidedStartCopy.headline)", systemImage: "xmark", action: onDismiss)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        ForEach(Array(GuidedStartStep.allCases.enumerated()), id: \.element) { index, step in
          row(index: index, step: step)
        }
        if progress.isAllDone {
          Text(GuidedStartCopy.completion)
            .typography(.small, weight: .semibold)
        }
        if let message {
          Text(message)
            .typography(.nano)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(GuidedStartCopy.headline), \(GuidedStartCopy.progress(completed: progress.completedCount))")
  }

  private func row(index: Int, step: GuidedStartStep) -> some View {
    let done = progress.completed.contains(step)
    return Button {
      onSelect(step)
    } label: {
      HStack(spacing: 12) {
        ZStack {
          Circle().strokeBorder(.secondary, lineWidth: 1).frame(width: 24, height: 24)
          if done {
            Image(systemName: "checkmark").font(.caption.bold())
          } else {
            Text("\(index + 1)").typography(.nano)
          }
        }
        Text(step.title)
          .typography(.small)
          .strikethrough(done)
          .foregroundStyle(done ? .secondary : .primary)
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Step \(index + 1) of \(GuidedStartStep.allCases.count), \(step.title)")
    .accessibilityValue(done ? "Done" : "Not started")
    .accessibilityHint(step.line)
  }
}
