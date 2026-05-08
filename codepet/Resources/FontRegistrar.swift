import Foundation
import CoreText
import os
#if canImport(AppKit)
import AppKit
#endif

/// Registers any .ttf/.otf fonts bundled in the app's Resources at app launch
/// so they're usable from `Font.custom(...)` without an Info.plist entry.
///
/// Call `FontRegistrar.registerBundledFonts()` once early in `CodePetApp.init`.
enum FontRegistrar {

    private static let logger = Logger(subsystem: "app.murror.codepet", category: "FontRegistrar")

    /// Triggered on first access (e.g. when `CodepetTheme.pixel(_:)` is
    /// first called). Ensures fonts are available even in SwiftUI Previews,
    /// which bypass `App.init()`.
    static let autoRegister: Void = {
        registerBundledFonts()
    }()

    /// Idempotent: safe to call multiple times. The font URLs are looked up
    /// in `Bundle.main`, so any .ttf/.otf placed under `codepet/Resources/`
    /// will be picked up by the synchronized-folder build.
    static func registerBundledFonts() {
        // Specific font names we ship. Extend this list as needed.
        let names = ["Minecraft"]
        let extensions = ["ttf", "otf"]

        for name in names {
            var registered = false
            for ext in extensions {
                guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                    continue
                }
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    logger.info("Registered bundled font: \(name).\(ext) at \(url.path)")
                    print("[FontRegistrar] ✓ registered \(name).\(ext)")
                } else {
                    let cf = error?.takeRetainedValue()
                    let code = (cf as Error?).map { ($0 as NSError).code } ?? 0
                    // 105 = "already registered" in CTFontManagerErrorDomain. Harmless.
                    if code == 105 {
                        logger.debug("Font already registered: \(name)")
                        print("[FontRegistrar] (already registered: \(name))")
                    } else {
                        logger.error("Failed to register font \(name).\(ext): \(String(describing: cf))")
                        print("[FontRegistrar] ✗ failed to register \(name).\(ext): \(String(describing: cf))")
                    }
                }
                registered = true
                break
            }
            if !registered {
                logger.error("Bundled font not found in Bundle.main: \(name)")
                print("[FontRegistrar] ✗ \(name).ttf not in Bundle.main")
            }
        }

        // Diagnostic: confirm the registered font is now resolvable by name.
        for name in names {
            #if canImport(AppKit)
            if NSFont(name: name, size: 13) != nil {
                print("[FontRegistrar] NSFont(name: \"\(name)\") resolves ✓")
            } else {
                print("[FontRegistrar] NSFont(name: \"\(name)\") returned nil ✗")
            }
            #endif
        }
    }
}
