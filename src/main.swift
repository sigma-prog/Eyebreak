import Cocoa
import SwiftUI
import AVFoundation

// config
let WORK_SECONDS = 20 * 60 // 20 mins 
let BREAK_SECONDS = 30     // 30 secs 


class BreakModel: ObservableObject {
    @Published var secondsRemaining: Int
    @Published var isVisible = false
    init(seconds: Int) { self.secondsRemaining = seconds }
}

struct NotchBreakView: View {
    @ObservedObject var model: BreakModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Look outside: \(model.secondsRemaining)s")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            )
            .scaleEffect(model.isVisible ? 1.0 : 0.45, anchor: .top)
            .offset(y: model.isVisible ? 0 : -42)
            .opacity(model.isVisible ? 1.0 : 0.0)
            .padding(.top, 10)
            .onTapGesture { onDismiss() }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.62)) {
                model.isVisible = true
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var isRunning = false
    var isBreakActive = false
    var isExpanded = false
    var wasRunningBeforeSleep = false
    
    var workSeconds = WORK_SECONDS
    var breakSeconds = BREAK_SECONDS
    var targetEndTime: Date?
    
    var breakModel: BreakModel?
    var popupWindow: NSPanel?
    var audioPlayer: AVAudioPlayer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let res = Bundle.main.resourcePath { FileManager.default.changeCurrentDirectoryPath(res) }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = loadIcon()
        button.imagePosition = .imageOnly
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.target = self
        button.action = #selector(statusBarClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Listen
        let ws = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            ws.addObserver(self, selector: #selector(macSleep), name: n, object: nil)
        }
        for n in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            ws.addObserver(self, selector: #selector(macWake), name: n, object: nil)
        }

        updateDisplay()
        startTimer()
    }

    func loadIcon() -> NSImage {
        let img = NSImage(contentsOfFile: "Assets/eye.svg") ?? NSImage(contentsOfFile: "../Assets/eye.svg") ?? NSImage()
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = true
        return img
    }

    // Sleep & Wake
    @objc func macSleep() {
        if isRunning {
            wasRunningBeforeSleep = true
            pauseTimer()
        }
        closePopup()
    }

    @objc func macWake() {
        if wasRunningBeforeSleep {
            wasRunningBeforeSleep = false
            startTimer()
        }
    }

    func playBreakSound() {
        let paths = ["Assets/break.mp3", "assets/break.mp3", "../Assets/break.mp3", "break.mp3"]
        guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }

        audioPlayer = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        audioPlayer?.volume = 1.0
        audioPlayer?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.audioPlayer?.setVolume(0, fadeDuration: 2.0)
        }
    }

    func triggerHaptics() {
        NSApp.activate(ignoringOtherApps: true)
        for i in 0..<20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * 0.1)) {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
        }
    }

    func updateDisplay() {
        guard let button = statusItem.button else { return }
        let s = isBreakActive ? breakSeconds : workSeconds
        let timeStr = s >= 60 ? String(format: "%dm %02ds", s / 60, s % 60) : "\(s)s"

        button.toolTip = nil

        if isExpanded || isBreakActive {
            button.imagePosition = .imageLeft
            button.title = " \(timeStr)"
            button.alphaValue = (isRunning || isBreakActive) ? 1.0 : 0.4
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            button.alphaValue = isRunning ? 1.0 : 0.4
        }
    }

    // Clicks
    @objc func statusBarClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            showContextMenu()
            return
        }

        if event.clickCount == 2 {
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            isExpanded.toggle()
            updateDisplay()
        } else if event.clickCount == 1 {
            self.perform(#selector(handleSingleClick), with: nil, afterDelay: NSEvent.doubleClickInterval)
        }
    }

    @objc func handleSingleClick() {
        wasRunningBeforeSleep = false
        if isBreakActive {
            popupWindow != nil ? closePopup() : showNotchPopup()
            return
        }
        isRunning ? pauseTimer() : startTimer()
    }

    func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: isExpanded ? "Collapse" : "Expand", action: #selector(toggleExpand), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: isRunning ? "Pause" : "Resume", action: #selector(toggleTimer), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc func toggleExpand() { isExpanded.toggle(); updateDisplay() }
    @objc func toggleTimer() { wasRunningBeforeSleep = false; isRunning ? pauseTimer() : startTimer() }
    @objc func quitApp() { NSApplication.shared.terminate(nil) }

    // Timer Logic
    func startTimer() {
        isRunning = true
        let current = isBreakActive ? breakSeconds : workSeconds
        targetEndTime = Date().addingTimeInterval(TimeInterval(current))
        updateDisplay()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pauseTimer() {
        isRunning = false
        if let target = targetEndTime {
            let left = max(0, Int(ceil(target.timeIntervalSinceNow)))
            if isBreakActive { breakSeconds = left } else { workSeconds = left }
        }
        targetEndTime = nil
        timer?.invalidate()
        timer = nil
        updateDisplay()
    }

    func tick() {
        guard isRunning, let target = targetEndTime else { return }
        let left = max(0, Int(ceil(target.timeIntervalSinceNow)))

        if isBreakActive {
            breakSeconds = left
            breakModel?.secondsRemaining = left
            if left <= 0 { endBreak() }
        } else {
            workSeconds = left
            if left <= 0 { startBreak() }
        }
        updateDisplay()
    }

    func startBreak() {
        isBreakActive = true
        breakSeconds = BREAK_SECONDS
        targetEndTime = Date().addingTimeInterval(TimeInterval(BREAK_SECONDS))
        updateDisplay()
        showNotchPopup()
        playBreakSound()
        triggerHaptics()
    }

    func endBreak() {
        audioPlayer?.stop()
        isBreakActive = false
        closePopup()
        workSeconds = WORK_SECONDS
        targetEndTime = Date().addingTimeInterval(TimeInterval(WORK_SECONDS))
        updateDisplay()
        triggerHaptics()
    }

    // Notch Window
    func showNotchPopup() {
        guard let screen = NSScreen.main, popupWindow == nil else { return }

        let w: CGFloat = 600
        let h: CGFloat = 160
        let notchY = screen.frame.maxY - screen.safeAreaInsets.top

        let panel = NSPanel(
            contentRect: NSRect(x: screen.frame.midX - (w / 2), y: notchY - h, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false

        let model = BreakModel(seconds: breakSeconds)
        panel.contentView = NSHostingView(rootView: NotchBreakView(model: model, onDismiss: { [weak self] in
            self?.closePopup()
        }))

        panel.orderFrontRegardless()
        self.popupWindow = panel
        self.breakModel = model
    }

    func closePopup() {
        popupWindow?.close()
        popupWindow = nil
        breakModel = nil
    }
}

// Run
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
