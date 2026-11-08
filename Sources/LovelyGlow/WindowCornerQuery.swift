import CoreFoundation
import CoreGraphics
import Darwin
import Foundation
import LovelyGlowCore

@MainActor
enum WindowCornerQuery {
    private static var cache: [UInt32: CGFloat] = [:]

    static func radius(for windowID: UInt32?) -> CGFloat? {
        guard let windowID, windowID != 0 else { return nil }
        if let cached = cache[windowID] { return cached }
        let value = SkyLightCorners.radius(of: windowID) ?? WindowChrome.standardRadius
        cache[windowID] = value
        return value
    }

    static func forget(_ windowID: UInt32?) {
        guard let windowID else { return }
        cache.removeValue(forKey: windowID)
    }
}

private enum SkyLightCorners {
    typealias MainConnection = @convention(c) () -> Int32
    typealias QueryWindows = @convention(c) (Int32, CFArray, Int) -> Unmanaged<CFTypeRef>?
    typealias CopyWindows = @convention(c) (CFTypeRef) -> Unmanaged<CFTypeRef>?
    typealias Advance = @convention(c) (CFTypeRef) -> Bool
    typealias GetWindowID = @convention(c) (CFTypeRef) -> UInt32
    typealias GetRadii = @convention(c) (CFTypeRef) -> Unmanaged<CFArray>?

    static func radius(of windowID: UInt32) -> CGFloat? {
        guard let mainConnection: MainConnection = symbol("SLSMainConnectionID"),
            let queryWindows: QueryWindows = symbol("SLSWindowQueryWindows"),
            let copyWindows: CopyWindows = symbol("SLSWindowQueryResultCopyWindows"),
            let advance: Advance = symbol("SLSWindowIteratorAdvance"),
            let getWindowID: GetWindowID = symbol("SLSWindowIteratorGetWindowID"),
            let getRadii: GetRadii = symbol("SLSWindowIteratorGetCornerRadii")
        else { return nil }
        let cid = mainConnection()
        let ids = [NSNumber(value: windowID)] as CFArray
        guard let query = queryWindows(cid, ids, 1)?.takeRetainedValue(),
            let iterator = copyWindows(query)?.takeRetainedValue()
        else { return nil }
        while advance(iterator) {
            guard getWindowID(iterator) == windowID else { continue }
            guard let array = getRadii(iterator)?.takeRetainedValue() else { return nil }
            return WindowChrome.resolvedRadius(values: numbers(in: array))
        }
        return nil
    }

    private static func numbers(in array: CFArray) -> [CGFloat] {
        (0..<CFArrayGetCount(array)).compactMap { index in
            let value = Unmanaged<CFTypeRef>.fromOpaque(CFArrayGetValueAtIndex(array, index))
                .takeUnretainedValue()
            guard CFGetTypeID(value) == CFNumberGetTypeID() else { return nil }
            var number: CGFloat = 0
            CFNumberGetValue(unsafeDowncast(value as AnyObject, to: CFNumber.self), .cgFloatType, &number)
            return number
        }
    }

    private static func symbol<T>(_ name: String) -> T? {
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }
}
