import SwiftUI

struct LaunchStatusView: View {
    let openSettings: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)

                    Image(systemName: "globe")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 76, height: 76)

                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.regularMaterial, in: Circle())
                        .offset(x: 10, y: -8)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Globe is running")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Look for the globe icon in the menu bar. Use it to open Settings, check permissions, or quit Globe.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Label("Menu bar app", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                Button("Open Settings") {
                    openSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Done") {
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
