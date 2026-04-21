import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        AppLanguage.apply(language)
                        appLanguageRawValue = language.rawValue
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage.from(appLanguageRawValue)
    }
}
