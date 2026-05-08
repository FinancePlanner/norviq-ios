import SwiftUI
import StockPlanShared

struct CryptoNewsCard: View {
    let news: StockNews

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if let imageURL = news.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(minHeight: 160, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.gray.opacity(0.2))
                        .frame(minHeight: 160, maxHeight: 200)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(news.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text(news.summary ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    HStack {
                        Text(news.source ?? "Crypto")
                            .font(.caption.bold())
                        Spacer()
                        Text(news.date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
