import SwiftUI
#if !os(macOS)
import UIKit
#endif

struct ContactAvatar: View {
    let imageData: Data?
    let displayName: String
    let size: CGFloat
    let tint: Color
    let strokeWidth: CGFloat

    init(
        imageData: Data?,
        displayName: String,
        size: CGFloat = 36,
        tint: Color = EquilibriumColor.CardTint.network,
        strokeWidth: CGFloat = 1
    ) {
        self.imageData = imageData
        self.displayName = displayName
        self.size = size
        self.tint = tint
        self.strokeWidth = strokeWidth
    }

    var body: some View {
        ZStack {
            #if !os(macOS)
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackInitials
            }
            #else
            fallbackInitials
            #endif
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(tint.opacity(0.5), lineWidth: strokeWidth)
        )
    }

    private var fallbackInitials: some View {
        ZStack {
            Circle().fill(tint.opacity(0.20))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        return parts.compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
    }
}
