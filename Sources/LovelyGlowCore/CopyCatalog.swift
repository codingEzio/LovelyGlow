import Foundation

public enum CopyKey: String, CaseIterable, Sendable {
    case appName
    case menuEnableGlow
    case menuSettings
    case menuQuit
    case menuGrantAccessibility
    case settingsTitle
    case settingsEnable
    case settingsSpread
    case settingsLineWidth
    case settingsCornerRadius
    case settingsOpacity
    case settingsLightColor
    case settingsDarkColor
    case settingsFont
    case settingsFontSystem
    case settingsFontPixel
    case settingsLanguage
    case settingsLanguageAuto
    case settingsLaunchAtLogin
    case settingsAboveDock
    case settingsAnimation
    case settingsAnimationStill
    case settingsAnimationOrbit
    case settingsAnimationBreathe
    case settingsAnimationComet
    case settingsAnimationOrbitBreathe
    case settingsSpeed
    case settingsScheme
    case settingsSchemeVioletBloom
    case settingsSchemeAuroraTeal
    case settingsSchemeCyberNeon
    case settingsSchemeNorthern
    case settingsSchemeSunset
    case settingsSchemeChampagne
    case settingsSchemeMoonlight
    case settingsSchemeEmber
    case settingsSchemeJade
    case settingsSchemeCustom
    case settingsLook
    case settingsMotion
    case settingsSize
    case settingsThickness
    case settingsAuxiliaryWindows
    case settingsMore
    case settingsSpeedSlow
    case settingsSpeedFast
    case settingsScrollHint
    case settingsPrevious
    case settingsNext
    case settingsAppear
    case settingsArrivalInstant
    case settingsArrivalSeamless
    case settingsAccessibilityGranted
    case settingsAccessibilityNeeded
    case settingsOpenAccessibility
    case statusEnabled
    case statusDisabled
    case statusNeedsAccessibility
}

public enum CopyCatalog {
    public static func resolvedLanguage(
        _ language: AppLanguage,
        preferred: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        if language != .auto { return language }
        for raw in preferred {
            let tag = raw.replacingOccurrences(of: "_", with: "-")
            if tag.hasPrefix("zh-Hant") || tag.hasPrefix("zh-TW") || tag.hasPrefix("zh-HK") {
                return .zhHant
            }
            if tag.hasPrefix("zh-Hans") || tag.hasPrefix("zh-CN") || tag.hasPrefix("zh") {
                return .zhHans
            }
            if tag.hasPrefix("ko") { return .ko }
            if tag.hasPrefix("ja") { return .ja }
            if tag.hasPrefix("es") { return .es }
            if tag.hasPrefix("ru") { return .ru }
            if tag.hasPrefix("uk") { return .uk }
            if tag.hasPrefix("en") { return .en }
        }
        return .en
    }

    public static func text(
        _ key: CopyKey,
        language: AppLanguage,
        preferred: [String] = Locale.preferredLanguages
    ) -> String {
        let resolved = resolvedLanguage(language, preferred: preferred)
        return table[resolved]?[key] ?? table[.en]![key]!
    }

    public static func languageTitle(_ language: AppLanguage, displayLanguage: AppLanguage) -> String {
        switch language {
        case .auto: return text(.settingsLanguageAuto, language: displayLanguage)
        case .en: return "English"
        case .zhHant: return "繁體中文"
        case .zhHans: return "简体中文"
        case .ko: return "한국어"
        case .ja: return "日本語"
        case .es: return "Español"
        case .ru: return "Русский"
        case .uk: return "Українська"
        }
    }

    private static let table: [AppLanguage: [CopyKey: String]] = [
        .en: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "Enable Glow",
            .menuSettings: "Settings…",
            .menuQuit: "Quit Lovely Glow",
            .menuGrantAccessibility: "Grant Accessibility…",
            .settingsTitle: "Lovely Glow Settings",
            .settingsEnable: "Enable Glow",
            .settingsSpread: "Spread",
            .settingsLineWidth: "Line Width",
            .settingsCornerRadius: "Corner Radius",
            .settingsOpacity: "Opacity",
            .settingsLightColor: "Light Color",
            .settingsDarkColor: "Dark Color",
            .settingsFont: "Typeface",
            .settingsFontSystem: "System",
            .settingsFontPixel: "Pixel",
            .settingsLanguage: "Language",
            .settingsLanguageAuto: "Auto",
            .settingsLaunchAtLogin: "Launch at Login",
            .settingsAboveDock: "Glow above Dock",
            .settingsAnimation: "Animation",
            .settingsAnimationStill: "Still",
            .settingsAnimationOrbit: "Orbit",
            .settingsAnimationBreathe: "Breathe",
            .settingsAnimationComet: "Comet",
            .settingsAnimationOrbitBreathe: "Orbit & Breathe",
            .settingsSpeed: "Speed",
            .settingsScheme: "Color scheme",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "Custom",
            .settingsLook: "Look",
            .settingsMotion: "Motion",
            .settingsSize: "Size",
            .settingsThickness: "Thickness",
            .settingsAuxiliaryWindows: "Include auxiliary windows",
            .settingsMore: "More",
            .settingsSpeedSlow: "Slow",
            .settingsSpeedFast: "Fast",
            .settingsScrollHint: "Scroll",
            .settingsPrevious: "Previous",
            .settingsNext: "Next",
            .settingsAppear: "Appear",
            .settingsArrivalInstant: "Instant",
            .settingsArrivalSeamless: "Seamless",
            .settingsAccessibilityGranted: "Accessibility is allowed.",
            .settingsAccessibilityNeeded: "Accessibility is needed to follow move and resize.",
            .settingsOpenAccessibility: "Open Accessibility Settings",
            .statusEnabled: "Enabled",
            .statusDisabled: "Disabled",
            .statusNeedsAccessibility: "Needs Accessibility",
        ],
        .zhHant: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "啟用光暈",
            .menuSettings: "設定…",
            .menuQuit: "結束 Lovely Glow",
            .menuGrantAccessibility: "授予輔助使用…",
            .settingsTitle: "Lovely Glow 設定",
            .settingsEnable: "啟用光暈",
            .settingsSpread: "擴散",
            .settingsLineWidth: "線寬",
            .settingsCornerRadius: "圓角",
            .settingsOpacity: "不透明度",
            .settingsLightColor: "淺色",
            .settingsDarkColor: "深色",
            .settingsFont: "字型",
            .settingsFontSystem: "系統",
            .settingsFontPixel: "像素",
            .settingsLanguage: "語言",
            .settingsLanguageAuto: "自動",
            .settingsLaunchAtLogin: "登入時開啟",
            .settingsAboveDock: "光暈蓋過 Dock",
            .settingsAnimation: "動畫",
            .settingsAnimationStill: "靜止",
            .settingsAnimationOrbit: "環繞",
            .settingsAnimationBreathe: "呼吸",
            .settingsAnimationComet: "彗星",
            .settingsAnimationOrbitBreathe: "環繞加呼吸",
            .settingsSpeed: "速度",
            .settingsScheme: "配色",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "自訂",
            .settingsLook: "外觀",
            .settingsMotion: "動態",
            .settingsSize: "大小",
            .settingsThickness: "粗細",
            .settingsAuxiliaryWindows: "包含輔助視窗",
            .settingsMore: "更多",
            .settingsSpeedSlow: "慢",
            .settingsSpeedFast: "快",
            .settingsScrollHint: "捲動",
            .settingsPrevious: "上一個",
            .settingsNext: "下一個",
            .settingsAppear: "出現",
            .settingsArrivalInstant: "即時",
            .settingsArrivalSeamless: "無縫",
            .settingsAccessibilityGranted: "已允許輔助使用。",
            .settingsAccessibilityNeeded: "需要輔助使用才能跟隨移動與縮放。",
            .settingsOpenAccessibility: "開啟輔助使用設定",
            .statusEnabled: "已啟用",
            .statusDisabled: "已停用",
            .statusNeedsAccessibility: "需要輔助使用",
        ],
        .zhHans: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "启用光晕",
            .menuSettings: "设置…",
            .menuQuit: "退出 Lovely Glow",
            .menuGrantAccessibility: "授予辅助功能…",
            .settingsTitle: "Lovely Glow 设置",
            .settingsEnable: "启用光晕",
            .settingsSpread: "扩散",
            .settingsLineWidth: "线宽",
            .settingsCornerRadius: "圆角",
            .settingsOpacity: "不透明度",
            .settingsLightColor: "浅色",
            .settingsDarkColor: "深色",
            .settingsFont: "字体",
            .settingsFontSystem: "系统",
            .settingsFontPixel: "像素",
            .settingsLanguage: "语言",
            .settingsLanguageAuto: "自动",
            .settingsLaunchAtLogin: "登录时打开",
            .settingsAboveDock: "光晕盖过 Dock",
            .settingsAnimation: "动画",
            .settingsAnimationStill: "静止",
            .settingsAnimationOrbit: "环绕",
            .settingsAnimationBreathe: "呼吸",
            .settingsAnimationComet: "彗星",
            .settingsAnimationOrbitBreathe: "环绕加呼吸",
            .settingsSpeed: "速度",
            .settingsScheme: "配色",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "自定义",
            .settingsLook: "外观",
            .settingsMotion: "动态",
            .settingsSize: "大小",
            .settingsThickness: "粗细",
            .settingsAuxiliaryWindows: "包含辅助窗口",
            .settingsMore: "更多",
            .settingsSpeedSlow: "慢",
            .settingsSpeedFast: "快",
            .settingsScrollHint: "滚动",
            .settingsPrevious: "上一个",
            .settingsNext: "下一个",
            .settingsAppear: "出现",
            .settingsArrivalInstant: "即时",
            .settingsArrivalSeamless: "无缝",
            .settingsAccessibilityGranted: "已允许辅助功能。",
            .settingsAccessibilityNeeded: "需要辅助功能才能跟随移动和缩放。",
            .settingsOpenAccessibility: "打开辅助功能设置",
            .statusEnabled: "已启用",
            .statusDisabled: "已停用",
            .statusNeedsAccessibility: "需要辅助功能",
        ],
        .ko: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "글로우 사용",
            .menuSettings: "설정…",
            .menuQuit: "Lovely Glow 종료",
            .menuGrantAccessibility: "손쉬운 사용 허용…",
            .settingsTitle: "Lovely Glow 설정",
            .settingsEnable: "글로우 사용",
            .settingsSpread: "확산",
            .settingsLineWidth: "선 두께",
            .settingsCornerRadius: "모서리",
            .settingsOpacity: "불투명도",
            .settingsLightColor: "라이트 색",
            .settingsDarkColor: "다크 색",
            .settingsFont: "서체",
            .settingsFontSystem: "시스템",
            .settingsFontPixel: "픽셀",
            .settingsLanguage: "언어",
            .settingsLanguageAuto: "자동",
            .settingsLaunchAtLogin: "로그인 시 열기",
            .settingsAboveDock: "Dock 위에 글로우",
            .settingsAnimation: "애니메이션",
            .settingsAnimationStill: "정지",
            .settingsAnimationOrbit: "궤도",
            .settingsAnimationBreathe: "숨결",
            .settingsAnimationComet: "혜성",
            .settingsAnimationOrbitBreathe: "궤도+숨결",
            .settingsSpeed: "속도",
            .settingsScheme: "배색",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "사용자 지정",
            .settingsLook: "모양",
            .settingsMotion: "움직임",
            .settingsSize: "크기",
            .settingsThickness: "굵기",
            .settingsAuxiliaryWindows: "보조 창 포함",
            .settingsMore: "더보기",
            .settingsSpeedSlow: "느리게",
            .settingsSpeedFast: "빠르게",
            .settingsScrollHint: "스크롤",
            .settingsPrevious: "이전",
            .settingsNext: "다음",
            .settingsAppear: "등장",
            .settingsArrivalInstant: "즉시",
            .settingsArrivalSeamless: "매끄럽게",
            .settingsAccessibilityGranted: "손쉬운 사용이 허용되었습니다.",
            .settingsAccessibilityNeeded: "이동과 크기 조절을 따르려면 손쉬운 사용이 필요합니다.",
            .settingsOpenAccessibility: "손쉬운 사용 설정 열기",
            .statusEnabled: "사용 중",
            .statusDisabled: "꺼짐",
            .statusNeedsAccessibility: "손쉬운 사용 필요",
        ],
        .ja: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "グローを有効にする",
            .menuSettings: "設定…",
            .menuQuit: "Lovely Glow を終了",
            .menuGrantAccessibility: "アクセシビリティを許可…",
            .settingsTitle: "Lovely Glow 設定",
            .settingsEnable: "グローを有効にする",
            .settingsSpread: "広がり",
            .settingsLineWidth: "線幅",
            .settingsCornerRadius: "角丸",
            .settingsOpacity: "不透明度",
            .settingsLightColor: "ライトの色",
            .settingsDarkColor: "ダークの色",
            .settingsFont: "書体",
            .settingsFontSystem: "システム",
            .settingsFontPixel: "ピクセル",
            .settingsLanguage: "言語",
            .settingsLanguageAuto: "自動",
            .settingsLaunchAtLogin: "ログイン時に開く",
            .settingsAboveDock: "グローを Dock の上に表示",
            .settingsAnimation: "アニメーション",
            .settingsAnimationStill: "静止",
            .settingsAnimationOrbit: "周回",
            .settingsAnimationBreathe: "呼吸",
            .settingsAnimationComet: "彗星",
            .settingsAnimationOrbitBreathe: "周回と呼吸",
            .settingsSpeed: "速さ",
            .settingsScheme: "配色",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "カスタム",
            .settingsLook: "見た目",
            .settingsMotion: "動き",
            .settingsSize: "大きさ",
            .settingsThickness: "太さ",
            .settingsAuxiliaryWindows: "補助ウインドウを含める",
            .settingsMore: "その他",
            .settingsSpeedSlow: "遅く",
            .settingsSpeedFast: "速く",
            .settingsScrollHint: "スクロール",
            .settingsPrevious: "前へ",
            .settingsNext: "次へ",
            .settingsAppear: "出現",
            .settingsArrivalInstant: "即時",
            .settingsArrivalSeamless: "シームレス",
            .settingsAccessibilityGranted: "アクセシビリティは許可されています。",
            .settingsAccessibilityNeeded: "移動とサイズ変更を追うにはアクセシビリティが必要です。",
            .settingsOpenAccessibility: "アクセシビリティ設定を開く",
            .statusEnabled: "有効",
            .statusDisabled: "無効",
            .statusNeedsAccessibility: "許可が必要",
        ],
        .es: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "Activar resplandor",
            .menuSettings: "Ajustes…",
            .menuQuit: "Salir de Lovely Glow",
            .menuGrantAccessibility: "Conceder Accesibilidad…",
            .settingsTitle: "Ajustes de Lovely Glow",
            .settingsEnable: "Activar resplandor",
            .settingsSpread: "Alcance",
            .settingsLineWidth: "Grosor",
            .settingsCornerRadius: "Esquinas",
            .settingsOpacity: "Opacidad",
            .settingsLightColor: "Color claro",
            .settingsDarkColor: "Color oscuro",
            .settingsFont: "Tipografía",
            .settingsFontSystem: "Sistema",
            .settingsFontPixel: "Píxel",
            .settingsLanguage: "Idioma",
            .settingsLanguageAuto: "Auto",
            .settingsLaunchAtLogin: "Abrir al iniciar sesión",
            .settingsAboveDock: "Resplandor sobre el Dock",
            .settingsAnimation: "Animación",
            .settingsAnimationStill: "Quieto",
            .settingsAnimationOrbit: "Órbita",
            .settingsAnimationBreathe: "Respirar",
            .settingsAnimationComet: "Cometa",
            .settingsAnimationOrbitBreathe: "Órbita y respirar",
            .settingsSpeed: "Velocidad",
            .settingsScheme: "Esquema de color",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "Personalizado",
            .settingsLook: "Aspecto",
            .settingsMotion: "Movimiento",
            .settingsSize: "Tamaño",
            .settingsThickness: "Grosor",
            .settingsAuxiliaryWindows: "Incluir ventanas auxiliares",
            .settingsMore: "Más",
            .settingsSpeedSlow: "Lento",
            .settingsSpeedFast: "Rápido",
            .settingsScrollHint: "Desplazar",
            .settingsPrevious: "Anterior",
            .settingsNext: "Siguiente",
            .settingsAppear: "Aparición",
            .settingsArrivalInstant: "Instantáneo",
            .settingsArrivalSeamless: "Fluido",
            .settingsAccessibilityGranted: "La accesibilidad está permitida.",
            .settingsAccessibilityNeeded: "Se necesita Accesibilidad para seguir el movimiento y el tamaño.",
            .settingsOpenAccessibility: "Abrir ajustes de Accesibilidad",
            .statusEnabled: "Activado",
            .statusDisabled: "Desactivado",
            .statusNeedsAccessibility: "Falta Accesibilidad",
        ],
        .ru: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "Включить свечение",
            .menuSettings: "Настройки…",
            .menuQuit: "Выйти из Lovely Glow",
            .menuGrantAccessibility: "Разрешить Универсальный доступ…",
            .settingsTitle: "Настройки Lovely Glow",
            .settingsEnable: "Включить свечение",
            .settingsSpread: "Размах",
            .settingsLineWidth: "Толщина линии",
            .settingsCornerRadius: "Скругление",
            .settingsOpacity: "Непрозрачность",
            .settingsLightColor: "Светлый цвет",
            .settingsDarkColor: "Тёмный цвет",
            .settingsFont: "Шрифт",
            .settingsFontSystem: "Системный",
            .settingsFontPixel: "Пиксельный",
            .settingsLanguage: "Язык",
            .settingsLanguageAuto: "Авто",
            .settingsLaunchAtLogin: "Открывать при входе",
            .settingsAboveDock: "Свечение над Dock",
            .settingsAnimation: "Анимация",
            .settingsAnimationStill: "Неподвижно",
            .settingsAnimationOrbit: "Орбита",
            .settingsAnimationBreathe: "Дыхание",
            .settingsAnimationComet: "Комета",
            .settingsAnimationOrbitBreathe: "Орбита и дыхание",
            .settingsSpeed: "Скорость",
            .settingsScheme: "Цвета",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "Свой",
            .settingsLook: "Вид",
            .settingsMotion: "Движение",
            .settingsSize: "Размер",
            .settingsThickness: "Толщина",
            .settingsAuxiliaryWindows: "Включить вспомогательные окна",
            .settingsMore: "Ещё",
            .settingsSpeedSlow: "Медленно",
            .settingsSpeedFast: "Быстро",
            .settingsScrollHint: "Прокрутка",
            .settingsPrevious: "Назад",
            .settingsNext: "Вперёд",
            .settingsAppear: "Появление",
            .settingsArrivalInstant: "Мгновенно",
            .settingsArrivalSeamless: "Плавно",
            .settingsAccessibilityGranted: "Универсальный доступ разрешён.",
            .settingsAccessibilityNeeded: "Чтобы следить за перемещением и размером, нужен Универсальный доступ.",
            .settingsOpenAccessibility: "Открыть настройки доступа",
            .statusEnabled: "Включено",
            .statusDisabled: "Выключено",
            .statusNeedsAccessibility: "Нужен доступ",
        ],
        .uk: [
            .appName: "Lovely Glow",
            .menuEnableGlow: "Увімкнути сяйво",
            .menuSettings: "Параметри…",
            .menuQuit: "Вийти з Lovely Glow",
            .menuGrantAccessibility: "Надати універсальний доступ…",
            .settingsTitle: "Параметри Lovely Glow",
            .settingsEnable: "Увімкнути сяйво",
            .settingsSpread: "Розмір",
            .settingsLineWidth: "Товщина лінії",
            .settingsCornerRadius: "Заокруглення",
            .settingsOpacity: "Непрозорість",
            .settingsLightColor: "Світлий колір",
            .settingsDarkColor: "Темний колір",
            .settingsFont: "Шрифт",
            .settingsFontSystem: "Системний",
            .settingsFontPixel: "Піксельний",
            .settingsLanguage: "Мова",
            .settingsLanguageAuto: "Авто",
            .settingsLaunchAtLogin: "Відкривати під час входу",
            .settingsAboveDock: "Сяйво над Dock",
            .settingsAnimation: "Анімація",
            .settingsAnimationStill: "Нерухомо",
            .settingsAnimationOrbit: "Орбіта",
            .settingsAnimationBreathe: "Дихання",
            .settingsAnimationComet: "Комета",
            .settingsAnimationOrbitBreathe: "Орбіта і дихання",
            .settingsSpeed: "Швидкість",
            .settingsScheme: "Кольори",
            .settingsSchemeVioletBloom: "Violet Bloom",
            .settingsSchemeAuroraTeal: "Aurora Teal",
            .settingsSchemeCyberNeon: "Cyber Neon",
            .settingsSchemeNorthern: "Northern Lights",
            .settingsSchemeSunset: "Sunset",
            .settingsSchemeChampagne: "Champagne",
            .settingsSchemeMoonlight: "Moonlight",
            .settingsSchemeEmber: "Ember",
            .settingsSchemeJade: "Jade",
            .settingsSchemeCustom: "Власний",
            .settingsLook: "Вигляд",
            .settingsMotion: "Рух",
            .settingsSize: "Розмір",
            .settingsThickness: "Товщина",
            .settingsAuxiliaryWindows: "Додати допоміжні вікна",
            .settingsMore: "Більше",
            .settingsSpeedSlow: "Повільно",
            .settingsSpeedFast: "Швидко",
            .settingsScrollHint: "Прокрутка",
            .settingsPrevious: "Назад",
            .settingsNext: "Далі",
            .settingsAppear: "Поява",
            .settingsArrivalInstant: "Миттєво",
            .settingsArrivalSeamless: "Плавно",
            .settingsAccessibilityGranted: "Універсальний доступ дозволено.",
            .settingsAccessibilityNeeded: "Щоб стежити за переміщенням і розміром, потрібен універсальний доступ.",
            .settingsOpenAccessibility: "Відкрити параметри доступу",
            .statusEnabled: "Увімкнено",
            .statusDisabled: "Вимкнено",
            .statusNeedsAccessibility: "Потрібен доступ",
        ],
    ]
}
