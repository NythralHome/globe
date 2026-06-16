import AppKit

@MainActor
final class HUDController {
    private var window: NSWindow?

    func show(text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSVisualEffectView()
        contentView.material = .hudWindow
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 14
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 76),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
        }
    }
}
