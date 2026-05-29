import Foundation
import Combine

/// Single source of truth for 84Key's options. Backed by `UserDefaults` with
/// **registered defaults** so a never-written key returns its real default
/// rather than 0 — this is what keeps default-ON options like `vFixSpotlight`
/// and `vAutoDetectEnglish` ON for fresh and existing installs (SPEC §9).
/// Changes are persisted and pushed into the engine option globals immediately.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let d = UserDefaults.standard
    private weak var controller: InputController?

    /// Option global name -> default value. Registered at startup.
    static let registeredDefaults: [String: Any] = [
        "vLanguage": 1,                 // 1: Vietnamese, 0: English
        "vInputType": 0,                // 0: Telex, 1: VNI, 2/3: Simple Telex
        "vCodeTable": 0,                // 0: Unicode
        "vFreeMark": 0,
        "vCheckSpelling": 1,
        "vUseModernOrthography": 1,
        "vQuickTelex": 0,
        "vRestoreIfWrongSpelling": 0,
        "vFixRecommendBrowser": 0,      // off: avoids stray chars in normal fields
        "vUseMacro": 0,
        "vUseSmartSwitchKey": 1,
        "vUpperCaseFirstChar": 0,
        "vAllowConsonantZFWJ": 0,
        "vQuickStartConsonant": 0,
        "vQuickEndConsonant": 0,
        "vAutoDetectEnglish": 1,        // flagship: default ON
        "vOtherLanguage": 0,            // off: don't disable on non-en macOS layouts
        "vFixSpotlight": 1,             // default ON — the registerDefaults gotcha
        "vSendKeyStepByStep": 0,
        "vFixChromiumBrowser": 0,
        "vPerformLayoutCompat": 0,
        "runOnStartup": 0,              // macOS-local (SMAppService), not an engine global
    ]

    // MARK: - Published, write-through settings (didSet does not fire during init)
    @Published var language: Int { didSet { persistAndApply() } }
    @Published var inputType: Int { didSet { persistAndApply() } }
    @Published var codeTable: Int { didSet { persistAndApply() } }
    @Published var freeMark: Bool { didSet { persistAndApply() } }
    @Published var checkSpelling: Bool { didSet { persistAndApply() } }
    @Published var modernOrthography: Bool { didSet { persistAndApply() } }
    @Published var quickTelex: Bool { didSet { persistAndApply() } }
    @Published var restoreIfWrongSpelling: Bool { didSet { persistAndApply() } }
    @Published var fixRecommendBrowser: Bool { didSet { persistAndApply() } }
    @Published var useMacro: Bool { didSet { persistAndApply() } }
    @Published var smartSwitchKey: Bool { didSet { persistAndApply() } }
    @Published var upperCaseFirstChar: Bool { didSet { persistAndApply() } }
    @Published var allowZFWJ: Bool { didSet { persistAndApply() } }
    @Published var quickStartConsonant: Bool { didSet { persistAndApply() } }
    @Published var quickEndConsonant: Bool { didSet { persistAndApply() } }
    @Published var autoDetectEnglish: Bool { didSet { persistAndApply() } }
    @Published var otherLanguage: Bool { didSet { persistAndApply() } }
    @Published var fixSpotlight: Bool { didSet { persistAndApply() } }
    @Published var runOnStartup: Bool { didSet { persistAndApply() } }

    private init() {
        d.register(defaults: Self.registeredDefaults)
        language = d.integer(forKey: "vLanguage")
        inputType = d.integer(forKey: "vInputType")
        codeTable = d.integer(forKey: "vCodeTable")
        freeMark = d.integer(forKey: "vFreeMark") != 0
        checkSpelling = d.integer(forKey: "vCheckSpelling") != 0
        modernOrthography = d.integer(forKey: "vUseModernOrthography") != 0
        quickTelex = d.integer(forKey: "vQuickTelex") != 0
        restoreIfWrongSpelling = d.integer(forKey: "vRestoreIfWrongSpelling") != 0
        fixRecommendBrowser = d.integer(forKey: "vFixRecommendBrowser") != 0
        useMacro = d.integer(forKey: "vUseMacro") != 0
        smartSwitchKey = d.integer(forKey: "vUseSmartSwitchKey") != 0
        upperCaseFirstChar = d.integer(forKey: "vUpperCaseFirstChar") != 0
        allowZFWJ = d.integer(forKey: "vAllowConsonantZFWJ") != 0
        quickStartConsonant = d.integer(forKey: "vQuickStartConsonant") != 0
        quickEndConsonant = d.integer(forKey: "vQuickEndConsonant") != 0
        autoDetectEnglish = d.integer(forKey: "vAutoDetectEnglish") != 0
        otherLanguage = d.integer(forKey: "vOtherLanguage") != 0
        fixSpotlight = d.integer(forKey: "vFixSpotlight") != 0
        runOnStartup = d.integer(forKey: "runOnStartup") != 0
    }

    /// Connect the input controller and push the current options into the engine.
    func attach(_ controller: InputController) {
        self.controller = controller
        applyToEngine()
    }

    private func persistAndApply() {
        persist()
        applyToEngine()
    }

    private func persist() {
        for (key, value) in engineValues { d.set(value, forKey: key) }
        d.set(runOnStartup ? 1 : 0, forKey: "runOnStartup")
    }

    /// The engine + macOS-local option values keyed by their global name.
    private var engineValues: [String: Int] {
        [
            "vLanguage": language,
            "vInputType": inputType,
            "vCodeTable": codeTable,
            "vFreeMark": freeMark ? 1 : 0,
            "vCheckSpelling": checkSpelling ? 1 : 0,
            "vUseModernOrthography": modernOrthography ? 1 : 0,
            "vQuickTelex": quickTelex ? 1 : 0,
            "vRestoreIfWrongSpelling": restoreIfWrongSpelling ? 1 : 0,
            "vFixRecommendBrowser": fixRecommendBrowser ? 1 : 0,
            "vUseMacro": useMacro ? 1 : 0,
            "vUseSmartSwitchKey": smartSwitchKey ? 1 : 0,
            "vUpperCaseFirstChar": upperCaseFirstChar ? 1 : 0,
            "vAllowConsonantZFWJ": allowZFWJ ? 1 : 0,
            "vQuickStartConsonant": quickStartConsonant ? 1 : 0,
            "vQuickEndConsonant": quickEndConsonant ? 1 : 0,
            "vAutoDetectEnglish": autoDetectEnglish ? 1 : 0,
            "vOtherLanguage": otherLanguage ? 1 : 0,
            "vFixSpotlight": fixSpotlight ? 1 : 0,
        ]
    }

    private func applyToEngine() {
        let dict = engineValues.mapValues { NSNumber(value: $0) }
        controller?.applyEngineOptions(dict)
    }
}
