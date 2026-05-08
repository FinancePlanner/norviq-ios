import SwiftUI

struct CryptoOverviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.gray.opacity(0.12))
                    .frame(minHeight: 110)
                    .shimmer()
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.gray.opacity(0.12))
                    .frame(minHeight: 110)
                    .shimmer()
            }
            .padding(.horizontal)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.gray.opacity(0.12))
                .frame(minHeight: 70)
                .shimmer()
                .padding(.horizontal)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.gray.opacity(0.12))
                .frame(minHeight: 200)
                .shimmer()
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.gray.opacity(0.12))
                            .frame(width: 120, height: 100)
                            .shimmer()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
