import SwiftUI

struct SharedStatusBadge: View {
    let text: String
    let colorToken: AppColorToken
    var symbolName: String? = nil

    var body: some View {
        SharedTag(text: text, colorToken: colorToken, symbolName: symbolName)
    }
}
