import Cocoa
import SwiftUI
// config
let WORK_DURATION_SECONDS = 20 * 60 // 20 minutes
let BREAK_DURATION_SECONDS = 30     
let AUTO_RESTART = true             
let SHOW_TIME_IN_MENU_BAR = true   

class BreakModel: ObservableObject {
    @Published var secondsRemaining: Int
    @Published var isVisible = false
    var isDismissed = false
    var onDismissAnimationDone: (() -> Void)?

    init(secondsRemaining: Int) {
        self.secondsRemaining = secondsRemaining
    }

    func dismissPopup() {
        guard !isDismissed else { return }
        isDismissed = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.onDismissAnimationDone?()
        }
    }
}

// Notch alert
struct NotchBreakView: View {
    @ObservedObject var model: BreakModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("Look outside: \(model.secondsRemaining)s")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.78))
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            )
            .contentShape(Capsule())
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
            .scaleEffect(model.isVisible ? 1.0 : 0.45, anchor: .top)
            .offset(y: model.isVisible ? 0 : -42)
            .opacity(model.isVisible ? 1.0 : 0.0)
            .padding(.top, 10)
            .onTapGesture {
                model.dismissPopup()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.62)) {
                    model.isVisible = true
                }
            }
        }
    }
}

// Menu bar
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var isRunning = false
    var isBreakActive = false
    var wasRunningBeforeSleep = false
    
    var workSecondsRemaining = WORK_DURATION_SECONDS
    var breakSecondsRemaining = BREAK_DURATION_SECONDS
    var targetEndTime: Date?
    
    var breakModel: BreakModel?
    var popupWindow: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = loadIcon()
        button.imagePosition = .imageLeft
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.target = self
        button.action = #selector(statusBarClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateDisplay()

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(macWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(macWillSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(macDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(macDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    func loadIcon() -> NSImage {
        if let bundleURL = Bundle.main.url(forResource: "eye", withExtension: "svg"),
           let img = NSImage(contentsOf: bundleURL) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }

        let localURL = URL(fileURLWithPath: "Assets/eye.svg")
        if let img = NSImage(contentsOf: localURL) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }

        let fallback = NSImage(systemSymbolName: "eye", accessibilityDescription: "Eye Timer") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    @objc func macWillSleep() {
        if isRunning {
            wasRunningBeforeSleep = true
            pauseTimer()
        }
        closePopup()
    }

    @objc func macDidWake() {
        if wasRunningBeforeSleep {
            wasRunningBeforeSleep = false
            startTimer()
        } else {
            updateDisplay()
        }
    }

    func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 0 {
            return String(format: "%dm %02ds", mins, secs)
        } else {
            return "\(secs)s"
        }
    }

    func updateDisplay() {
        guard let button = statusItem.button else { return }

        if !SHOW_TIME_IN_MENU_BAR {
            button.title = ""
            button.alphaValue = isRunning ? 1.0 : 0.4
            return
        }

        if isBreakActive {
            button.title = " \(formatTime(breakSecondsRemaining))"
            button.alphaValue = 1.0
        } else if isRunning {
            button.title = " \(formatTime(workSecondsRemaining))"
            button.alphaValue = 1.0
        } else {
            button.title = " Paused"
            button.alphaValue = 0.4
        }
    }

    @objc func statusBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        // right click
        if event?.type == .rightMouseUp {
            let menu = NSMenu()

            let pauseTitle = isRunning ? "Pause" : "Resume"
            let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(toggleTimer), keyEquivalent: "")
            pauseItem.target = self
            menu.addItem(pauseItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(title: "Quit Eye Timer", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)

            if let button = statusItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
            }
            return
        }

        if isBreakActive {
            if popupWindow != nil {
                closePopup()
            } else {
                showNotchPopup()
            }
            return
        }

        wasRunningBeforeSleep = false
        toggleTimer()
    }

    @objc func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    func startTimer() {
        isRunning = true
        let currentSeconds = isBreakActive ? breakSecondsRemaining : workSecondsRemaining
        targetEndTime = Date().addingTimeInterval(TimeInterval(currentSeconds))
        
        updateDisplay()
        timer?.invalidate()
        
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(t, forMode: .common)
        self.timer = t
    }

    func pauseTimer() {
        isRunning = false
        if let target = targetEndTime {
            let remaining = max(0, Int(ceil(target.timeIntervalSinceNow)))
            if isBreakActive {
                breakSecondsRemaining = remaining
            } else {
                workSecondsRemaining = remaining
            }
        }
        targetEndTime = nil
        updateDisplay()
        timer?.invalidate()
        timer = nil
    }

    @objc func quitApp() {
        closePopup()
        NSApplication.shared.terminate(nil)
    }

    func tick() {
        guard isRunning, let target = targetEndTime else { return }

        let remaining = max(0, Int(ceil(target.timeIntervalSinceNow)))

        if isBreakActive {
            breakSecondsRemaining = remaining
            breakModel?.secondsRemaining = remaining

            if remaining <= 0 {
                endBreak()
            }
        } else {
            workSecondsRemaining = remaining
            if remaining <= 0 {
                startBreak()
            }
        }
        updateDisplay()
    }

    func startBreak() {
        isBreakActive = true
        breakSecondsRemaining = BREAK_DURATION_SECONDS
        targetEndTime = Date().addingTimeInterval(TimeInterval(BREAK_DURATION_SECONDS))
        updateDisplay()
        showNotchPopup()
    }

    func endBreak() {
        isBreakActive = false
        closePopup()
        workSecondsRemaining = WORK_DURATION_SECONDS
        targetEndTime = Date().addingTimeInterval(TimeInterval(WORK_DURATION_SECONDS))
        updateDisplay()

        if !AUTO_RESTART {
            pauseTimer()
        }
    }

    func showNotchPopup() {
        guard let screen = NSScreen.main, popupWindow == nil else { return }

        let winWidth: CGFloat = 600
        let winHeight: CGFloat = 160
        let notchBottomY = screen.frame.maxY - screen.safeAreaInsets.top

        let panel = NSPanel(
            contentRect: NSRect(
                x: screen.frame.midX - (winWidth / 2),
                y: notchBottomY - winHeight,
                width: winWidth,
                height: winHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let model = BreakModel(secondsRemaining: breakSecondsRemaining)
        model.onDismissAnimationDone = { [weak self] in
            panel.close()
            self?.popupWindow = nil
            self?.breakModel = nil
        }

        panel.contentView = NSHostingView(rootView: NotchBreakView(model: model))
        panel.orderFrontRegardless()
        self.popupWindow = panel
        self.breakModel = model
    }

    func closePopup() {
        if let model = breakModel {
            model.dismissPopup()
        } else {
            popupWindow?.close()
            popupWindow = nil
            breakModel = nil
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
