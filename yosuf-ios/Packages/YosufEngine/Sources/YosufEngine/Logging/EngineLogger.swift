import Foundation
#if canImport(os)
import os
#endif

/// Structured logging for the engine. Wraps `os.Logger` on Apple platforms
/// and falls back to a minimal stderr writer on Linux (so `swift test`
/// keeps working outside Xcode) — no bare `print` calls anywhere in the engine.
public enum EngineLogger {
    #if canImport(os)
    private static let logger = Logger(subsystem: "com.yosuf.game", category: "engine")
    #endif

    public static func debug(_ message: @autoclosure () -> String) {
        #if canImport(os)
        let resolved = message()
        logger.debug("\(resolved, privacy: .public)")
        #else
        FileHandle.standardError.write(Data("[debug] \(message())\n".utf8))
        #endif
    }

    public static func info(_ message: @autoclosure () -> String) {
        #if canImport(os)
        let resolved = message()
        logger.info("\(resolved, privacy: .public)")
        #else
        FileHandle.standardError.write(Data("[info] \(message())\n".utf8))
        #endif
    }

    public static func fault(_ message: @autoclosure () -> String) {
        #if canImport(os)
        let resolved = message()
        logger.fault("\(resolved, privacy: .public)")
        #else
        FileHandle.standardError.write(Data("[fault] \(message())\n".utf8))
        #endif
    }
}
