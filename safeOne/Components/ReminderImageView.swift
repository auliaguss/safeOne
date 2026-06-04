import SwiftUI

struct ReminderImageView: View {
    let imageName: String?
    var size: CGFloat = 48
    var fallback: String = "💊"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(width: size, height: size)

            if let fileName = ReminderImageReference.fileName(from: imageName),
               let image = LocalImageStore.load(fileName: fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(imageName ?? fallback)
                    .font(.system(size: size * 0.45))
            }
        }
    }
}

