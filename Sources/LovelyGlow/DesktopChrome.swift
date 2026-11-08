import AppKit
import CoreGraphics
import Darwin
import LovelyGlowCore

@MainActor
enum DesktopChrome {
    // Window membership stays meaningful while fullscreen bounds slide.
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias ActiveSpace = @convention(c) (Int32) -> UInt64
    private typealias SpaceType = @convention(c) (Int32, UInt64) -> Int32
    private typealias CurrentSpace = @convention(c) (Int32, CFString) -> UInt64
    private typealias WindowSpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?

    private static let connection: MainConnection? = symbol("SLSMainConnectionID")
    private static let activeSpace: ActiveSpace? = symbol("SLSGetActiveSpace")
    private static let spaceType: SpaceType? = symbol("SLSSpaceGetType")
    private static let currentSpace: CurrentSpace? = symbol("SLSManagedDisplayGetCurrentSpace")
    private static let windowSpaces: WindowSpaces? = symbol("SLSCopySpacesForWindows")
    private static var displays: [(bounds: CGRect, uuid: String)] = []

    static func invalidateDisplays() { displays = [] }

    static func observation(windowBounds: CGRect?, windowID: UInt32?) -> SpaceObservation {
        guard let connection, let spaceType else {
            return SpaceObservation(spaceID: 0, spaceType: SpaceOverview.userSpace)
        }
        let cid = connection()
        let fallbackID = activeSpace?(cid) ?? 0
        if displays.isEmpty {
            displays = NSScreen.screens.compactMap { screen in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                else { return nil }
                let id = CGDirectDisplayID(number.uint32Value)
                let uuid = CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue()
                return (CGDisplayBounds(id), CFUUIDCreateString(nil, uuid) as String)
            }
        }
        let displaySpaces: [DisplaySpaceSnapshot] =
            currentSpace.map { current in
                displays.map { display in
                    let sid = current(cid, display.uuid as CFString)
                    return DisplaySpaceSnapshot(bounds: display.bounds, spaceID: sid, spaceType: spaceType(cid, sid))
                }
            } ?? []
        let selected = SpaceSelection.observation(
            for: windowBounds, displays: displaySpaces,
            fallback: SpaceObservation(spaceID: fallbackID, spaceType: spaceType(cid, fallbackID)))
        let sid = selected.spaceID
        let type = selected.spaceType
        guard let windowID, let windowSpaces,
            let spaces = windowSpaces(cid, 7, [NSNumber(value: windowID)] as CFArray)?.takeRetainedValue()
                as? [NSNumber],
            !spaces.isEmpty
        else { return SpaceObservation(spaceID: sid, spaceType: type) }
        let ids = spaces.map(\.uint64Value)
        return SpaceObservation(
            spaceID: sid, spaceType: type,
            windowSpaceTypes: ids.map { spaceType(cid, $0) },
            windowOnCurrentSpace: ids.contains(sid)
        )
    }

    private static func symbol<T>(_ name: String) -> T? {
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }
}
