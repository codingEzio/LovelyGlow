import AppKit
import Combine
import LovelyGlowCore
import SwiftUI

@MainActor
final class GlowPanelModel: ObservableObject {
    private let runtime: GlowRuntime

    @Published var enabled: Bool { didSet { write { $0.enabled = enabled } } }
    @Published var launchAtLogin: Bool {
        didSet {
            write { $0.launchAtLogin = launchAtLogin }
            try? LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }
    @Published var fontStyle: FontStyle { didSet { write { $0.fontStyle = fontStyle } } }
    @Published var language: AppLanguage { didSet { write { $0.language = language } } }
    @Published var glowAboveDock: Bool { didSet { write { $0.glowAboveDock = glowAboveDock } } }
    @Published var includeAuxiliaryWindows: Bool {
        didSet { write { $0.includeAuxiliaryWindows = includeAuxiliaryWindows } }
    }
    @Published var animation: GlowAnimationID { didSet { write { $0.animation = animation } } }
    @Published var speed: Double { didSet { write { $0.animationSpeed = CGFloat(speed) } } }
    @Published var scheme: GlowSchemeID { didSet { write { $0.scheme = scheme } } }
    @Published var arrival: GlowArrivalID { didSet { write { $0.arrival = arrival } } }
    @Published var spread: Double { didSet { write { $0.style.spread = CGFloat(spread) } } }
    @Published var lineWidth: Double { didSet { write { $0.style.lineWidth = CGFloat(lineWidth) } } }
    @Published var opacity: Double { didSet { write { $0.style.opacity = CGFloat(opacity) } } }
    @Published var lightColor: Color {
        didSet { write { $0.style.lightColor = RGBAColor(lightColor) } }
    }
    @Published var darkColor: Color {
        didSet { write { $0.style.darkColor = RGBAColor(darkColor) } }
    }
    @Published var accessibilityTrusted: Bool
    @Published var showMore = false
    var onLayoutChange: (() -> Void)?

    init(runtime: GlowRuntime) {
        self.runtime = runtime
        let document = runtime.store.document
        enabled = document.enabled
        launchAtLogin = document.launchAtLogin
        fontStyle = document.fontStyle
        language = document.language
        glowAboveDock = document.glowAboveDock
        includeAuxiliaryWindows = document.includeAuxiliaryWindows
        animation = document.animation
        speed = Double(document.animationSpeed)
        scheme = document.scheme
        arrival = document.arrival
        spread = Double(document.style.spread)
        lineWidth = Double(document.style.lineWidth)
        opacity = Double(document.style.opacity)
        lightColor = Color(document.style.lightColor)
        darkColor = Color(document.style.darkColor)
        accessibilityTrusted = runtime.accessibilityTrusted
    }

    func text(_ key: CopyKey) -> String {
        runtime.copy(key)
    }

    func refreshAccessibility() {
        runtime.refreshAccessibility()
        accessibilityTrusted = runtime.accessibilityTrusted
    }

    func grantAccessibility() {
        if !AccessibilityPermission.request() {
            AccessibilityPermission.openSystemSettings()
        }
        refreshAccessibility()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func write(_ mutate: (inout SettingsDocument) -> Void) {
        runtime.updateDocument(mutate)
    }
}

struct GlowPanelView: View {
    @ObservedObject var model: GlowPanelModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: GlowPanelMetrics.sectionSpacing) {
            enableRow
            lookHero
            sliderRow(title: model.text(.settingsSize), value: sizeCaption) {
                Slider(
                    value: $model.spread,
                    in: Double(GlowPanelMetrics.minimumSpread)...Double(GlowPanelMetrics.maximumSpread)
                )
                .controlSize(.mini)
            }
            labeled(model.text(.settingsMotion)) {
                cycleRow(
                    title: motionTitle(model.animation),
                    previousLabel: model.text(.settingsPrevious),
                    nextLabel: model.text(.settingsNext),
                    onPrevious: {
                        model.animation = ChoiceCycle.step(model.animation, in: GlowAnimationID.allCases, by: -1)
                    },
                    onNext: {
                        model.animation = ChoiceCycle.step(model.animation, in: GlowAnimationID.allCases, by: 1)
                    }
                )
            }
            if model.animation != .still {
                sliderRow(
                    title: model.text(.settingsSpeed),
                    value: speedCaption,
                    leading: model.text(.settingsSpeedSlow),
                    trailing: model.text(.settingsSpeedFast)
                ) {
                    Slider(
                        value: Binding(
                            get: { GlowMotion.sliderPosition(for: CGFloat(model.speed)) },
                            set: { model.speed = Double(GlowMotion.speed(atSliderPosition: $0)) }
                        ),
                        in: 0...1
                    )
                    .controlSize(.mini)
                }
            }
            labeled(model.text(.settingsFont)) {
                QuietPills(
                    items: [
                        (.system, model.text(.settingsFontSystem)),
                        (.pixel, model.text(.settingsFontPixel)),
                    ],
                    selection: $model.fontStyle
                )
                .accessibilityIdentifier("glow.panel.font")
            }
            labeled(model.text(.settingsAppear)) {
                QuietPills(
                    items: [
                        (.instant, model.text(.settingsArrivalInstant)),
                        (.seamless, model.text(.settingsArrivalSeamless)),
                    ],
                    selection: $model.arrival
                )
                .accessibilityIdentifier("glow.panel.arrival")
            }
            moreSection
            if !model.accessibilityTrusted {
                Button(model.text(.settingsOpenAccessibility)) {
                    model.grantAccessibility()
                }
                .buttonStyle(.borderless)
                .font(controlFont)
                .foregroundStyle(.secondary)
            }
            Divider()
            footer
        }
        .padding(GlowPanelMetrics.inset)
        .frame(width: GlowPanelMetrics.width, alignment: .topLeading)
        .font(controlFont)
        .onAppear { model.refreshAccessibility() }
        .onChange(of: model.showMore) { _, _ in model.onLayoutChange?() }
        .onChange(of: model.scheme) { _, _ in model.onLayoutChange?() }
        .onChange(of: model.animation) { _, _ in model.onLayoutChange?() }
        .onChange(of: model.fontStyle) { _, _ in model.onLayoutChange?() }
        .onChange(of: model.arrival) { _, _ in model.onLayoutChange?() }
        .accessibilityIdentifier("glow.panel")
    }

    private var enableRow: some View {
        HStack {
            Text(model.text(.appName))
                .font(titleFont)
            Spacer(minLength: 8)
            Toggle("", isOn: $model.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityLabel(model.text(.settingsEnable))
        }
        .frame(height: GlowPanelMetrics.rowHeight)
    }

    private var lookHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            filamentPreview
            schemeStones
            Text(schemeTitle(model.scheme))
                .font(valueFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.text(.settingsLook))
    }

    private var filamentPreview: some View {
        let palette = previewPalette
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04))
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.03))
                .padding(10)
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [palette.highlight, palette.base, palette.warmth, palette.highlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.2
                )
                .shadow(color: palette.highlight.opacity(0.7), radius: 12)
                .padding(8)
        }
        .frame(height: 52)
        .accessibilityHidden(true)
    }

    private var schemeStones: some View {
        let isDark = colorScheme == .dark
        return HStack(spacing: 5) {
            VStack(spacing: 3) {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                    .opacity(0.35)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .frame(width: 13)
            ForEach(GlowSchemeID.allCases, id: \.self) { id in
                VStack(spacing: 3) {
                    Button {
                        model.scheme = id
                    } label: {
                        schemeStone(id, isDark: isDark, selected: model.scheme == id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(schemeTitle(id))
                    .accessibilityAddTraits(model.scheme == id ? .isSelected : [])
                    schemeStone(id, isDark: !isDark, selected: false)
                        .opacity(0.32)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func schemeStone(_ id: GlowSchemeID, isDark: Bool, selected: Bool) -> some View {
        let palette = stonePalette(id, isDark: isDark)
        return Circle()
            .fill(
                LinearGradient(
                    colors: [palette.highlight, palette.base],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: selected ? 15 : 12, height: selected ? 15 : 12)
            .overlay {
                Circle()
                    .strokeBorder(
                        selected ? Color.primary.opacity(0.9) : Color.white.opacity(0.28),
                        lineWidth: selected ? 1.2 : 0.6
                    )
            }
            .shadow(color: selected ? palette.highlight.opacity(0.7) : .clear, radius: selected ? 6 : 0)
            .frame(width: 18, height: 18)
    }

    @ViewBuilder
    private var moreSection: some View {
        Button {
            model.showMore.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.showMore ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text(model.text(.settingsMore))
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(controlFont)
        .frame(height: GlowPanelMetrics.rowHeight)
        .accessibilityIdentifier("glow.panel.more")

        if model.showMore {
            Toggle(model.text(.settingsLaunchAtLogin), isOn: $model.launchAtLogin)
                .controlSize(.mini)
            Toggle(model.text(.settingsAboveDock), isOn: $model.glowAboveDock)
                .controlSize(.mini)
            Toggle(model.text(.settingsAuxiliaryWindows), isOn: $model.includeAuxiliaryWindows)
                .controlSize(.mini)
            labeled(model.text(.settingsLanguage)) {
                Picker("", selection: $model.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(CopyCatalog.languageTitle(language, displayLanguage: model.language)).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }
            sliderRow(title: model.text(.settingsThickness), value: thicknessCaption) {
                Slider(value: $model.lineWidth, in: 1...14)
                    .controlSize(.mini)
            }
            sliderRow(title: model.text(.settingsOpacity), value: opacityCaption) {
                Slider(value: $model.opacity, in: 0.2...1)
                    .controlSize(.mini)
            }
            if model.scheme == .custom {
                ColorPicker(model.text(.settingsLightColor), selection: $model.lightColor, supportsOpacity: false)
                ColorPicker(model.text(.settingsDarkColor), selection: $model.darkColor, supportsOpacity: false)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer()
            Button(action: model.quit) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: GlowPanelMetrics.footerHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(model.text(.menuQuit))
            .keyboardShortcut("q", modifiers: .command)
            .accessibilityLabel(model.text(.menuQuit))
            .accessibilityIdentifier("glow.panel.quit")
        }
        .font(controlFont)
        .frame(height: GlowPanelMetrics.footerHeight)
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            content()
        }
        .frame(minHeight: GlowPanelMetrics.rowHeight)
    }

    private func cycleRow(
        title: String,
        previousLabel: String,
        nextLabel: String,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some View {
        let step: (Int) -> Void = { step in
            if step < 0 { onPrevious() } else { onNext() }
        }
        return CycleWheel(onStep: step) {
            HStack(spacing: 4) {
                cycleButton("chevron.left", label: previousLabel, action: onPrevious)
                Text(title)
                    .font(valueFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                cycleButton("chevron.right", label: nextLabel, action: onNext)
            }
        }
    }

    private func cycleButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .accessibilityLabel(label)
    }

    private func sliderRow<Content: View>(
        title: String,
        value: String,
        leading: String? = nil,
        trailing: String? = nil,
        @ViewBuilder slider: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(valueFont)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            if let leading, let trailing {
                HStack(spacing: 6) {
                    Text(leading).foregroundStyle(.tertiary).font(controlFont)
                    slider()
                    Text(trailing).foregroundStyle(.tertiary).font(controlFont)
                }
            } else {
                slider()
            }
        }
    }

    private var previewPalette: (base: Color, highlight: Color, warmth: Color) {
        stonePalette(model.scheme, isDark: colorScheme == .dark)
    }

    private func stonePalette(_ id: GlowSchemeID, isDark: Bool) -> (base: Color, highlight: Color, warmth: Color) {
        if id == .custom {
            let color = isDark ? model.darkColor : model.lightColor
            return (color, color.opacity(0.85), color.opacity(0.7))
        }
        let palette =
            GlowSchemeCatalog.scheme(id)?.palette(isDark: isDark)
            ?? GlowPalette(
                base: RGBAColor.parse("#A78BFA")!,
                highlight: RGBAColor.parse("#F4D6FF")!,
                warmth: RGBAColor.parse("#FFD8F4")!
            )
        return (Color(palette.base), Color(palette.highlight), Color(palette.warmth))
    }

    private func schemeTitle(_ id: GlowSchemeID) -> String {
        model.text(schemeKey(id))
    }

    private func motionTitle(_ id: GlowAnimationID) -> String {
        switch id {
        case .still: return model.text(.settingsAnimationStill)
        case .orbit: return model.text(.settingsAnimationOrbit)
        case .breathe: return model.text(.settingsAnimationBreathe)
        case .comet: return model.text(.settingsAnimationComet)
        case .orbitBreathe: return model.text(.settingsAnimationOrbitBreathe)
        }
    }

    private func schemeKey(_ id: GlowSchemeID) -> CopyKey {
        switch id {
        case .violetBloom: return .settingsSchemeVioletBloom
        case .auroraTeal: return .settingsSchemeAuroraTeal
        case .cyberNeon: return .settingsSchemeCyberNeon
        case .northern: return .settingsSchemeNorthern
        case .sunset: return .settingsSchemeSunset
        case .champagne: return .settingsSchemeChampagne
        case .moonlight: return .settingsSchemeMoonlight
        case .ember: return .settingsSchemeEmber
        case .jade: return .settingsSchemeJade
        case .custom: return .settingsSchemeCustom
        }
    }

    private var speedCaption: String {
        String(format: model.speed < 0.2 ? "%.2f×" : "%.1f×", model.speed)
    }

    private var sizeCaption: String {
        String(format: "%.0f", model.spread)
    }

    private var thicknessCaption: String {
        String(format: "%.1f", model.lineWidth)
    }

    private var opacityCaption: String {
        String(format: "%.0f%%", model.opacity * 100)
    }

    private var titleFont: Font {
        Font(LovelyFonts.contentFont(ofSize: 12, style: model.fontStyle, weight: .semibold))
    }

    private var valueFont: Font {
        Font(LovelyFonts.contentFont(ofSize: 12, style: model.fontStyle))
    }

    private var controlFont: Font {
        .system(size: 11)
    }
}

private struct QuietPills<Value: Hashable>: View {
    var items: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let selected = selection == item.0
                Button {
                    selection = item.0
                } label: {
                    Text(item.1)
                        .font(.system(size: 11, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: GlowPanelMetrics.rowHeight)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected ? Color.primary.opacity(0.12) : Color.primary.opacity(0.045))
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    selected ? Color.primary.opacity(0.22) : Color.primary.opacity(0.08),
                                    lineWidth: 0.5
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

private struct CycleWheel<Content: View>: NSViewRepresentable {
    var onStep: (Int) -> Void
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> CycleWheelView<Content> {
        let view = CycleWheelView(rootView: content)
        view.onStep = onStep
        return view
    }

    func updateNSView(_ nsView: CycleWheelView<Content>, context: Context) {
        nsView.rootView = content
        nsView.onStep = onStep
    }
}

private final class CycleWheelView<Content: View>: NSHostingView<Content> {
    var onStep: ((Int) -> Void)?
    private var carried: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 8
        carried += delta
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 10 : 1
        if abs(carried) >= threshold {
            onStep?(carried > 0 ? -1 : 1)
            carried = 0
        }
    }
}

extension Color {
    fileprivate init(_ color: RGBAColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

extension RGBAColor {
    fileprivate init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.init(
            red: nsColor.redComponent,
            green: nsColor.greenComponent,
            blue: nsColor.blueComponent,
            alpha: nsColor.alphaComponent
        )
    }
}
