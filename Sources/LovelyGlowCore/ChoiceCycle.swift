import Foundation

public enum ChoiceCycle {
    public static func step<T: Equatable>(_ value: T, in items: [T], by delta: Int) -> T {
        guard !items.isEmpty, let index = items.firstIndex(of: value) else { return value }
        let count = items.count
        let next = ((index + delta) % count + count) % count
        return items[next]
    }
}
