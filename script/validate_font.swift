import CoreText
import Foundation

// Validate the file which will actually be bundled, without registering it.
guard CommandLine.arguments.count == 2 else {
    fputs("Expected one font file.\n", stderr)
    exit(2)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey])
guard values?.isRegularFile == true, values?.isReadable == true,
    let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
    !descriptors.isEmpty else {
    fputs("Font input is missing, unreadable, or invalid.\n", stderr)
    exit(1)
}
