import AppKit

@MainActor
final class HUDController {
    private var window: NSWindow?
    private var hideWorkItem: DispatchWorkItem?

    func show(text: String) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        window?.orderOut(nil)
        window = nil

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

        let hideWorkItem = DispatchWorkItem { [weak self, weak window] in
            guard let self, let window, self.window === window else {
                return
            }

            window.orderOut(nil)
            self.window = nil
            self.hideWorkItem = nil
        }
        self.hideWorkItem = hideWorkItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: hideWorkItem)
    }
}
