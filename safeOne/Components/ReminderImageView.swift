//
//  ReminderImageView.swift
//  safeOne
//

import SwiftUI

/// Displays a reminder's image: decodes base64 data URIs, loads http URLs, or shows an emoji.
struct ReminderImageView: View {
    let imageName: String?
    let size: CGFloat
    var isCircle: Bool = false
    var opacity: Double = 1.0
    var background: Color = Color(.systemGray6)
    var cornerRadius: CGFloat = 12

    private var decodedImage: UIImage? {
        guard let name = imageName, name.hasPrefix("data:"),
              let comma = name.firstIndex(of: ",") else { return nil }
        let b64 = String(name[name.index(after: comma)...])
        guard let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack {
            if isCircle {
                Circle().fill(background)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius).fill(background)
            }

            if let img = decodedImage {
                if isCircle {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .opacity(opacity)
                } else {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .opacity(opacity)
                }
            } else if let name = imageName,
                      name.hasPrefix("https://") || name.hasPrefix("http://") {
                AsyncImage(url: URL(string: name)) { phase in
                    if let img = phase.image {
                        if isCircle {
                            img.resizable().scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                                .opacity(opacity)
                        } else {
                            img.resizable().scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                .opacity(opacity)
                        }
                    } else {
                        Text(imageName ?? "💊")
                            .font(.system(size: size * 0.45))
                            .opacity(opacity)
                    }
                }
            } else {
                Text(imageName ?? "💊")
                    .font(.system(size: size * 0.45))
                    .opacity(opacity)
            }
        }
        .frame(width: size, height: size)
    }
}
