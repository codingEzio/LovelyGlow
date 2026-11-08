import CoreGraphics
import Foundation

/// Shared compact popover grammar from Calm Bar / HW Status.
public enum GlowPanelMetrics {
    public static let width: CGFloat = 300
    public static let inset: CGFloat = 12
    public static let contentWidth: CGFloat = width - inset * 2
    public static let sectionSpacing: CGFloat = 7
    public static let rowHeight: CGFloat = 22
    public static let footerHeight: CGFloat = 22
    public static let cornerRadius: CGFloat = 18
    public static let minimumSpread: CGFloat = 2
    public static let maximumSpread: CGFloat = 64
}

public enum GlowPopoverDismissal {
    public static func shouldDismiss(clickedPanel: Bool, clickedStatusItem: Bool, clickedMenu: Bool) -> Bool {
        !(clickedPanel || clickedStatusItem || clickedMenu)
    }
}
