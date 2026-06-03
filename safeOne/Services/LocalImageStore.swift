import Foundation
import UIKit

enum ReminderImageReference {
    static let photoPrefix = "photo:"

    static func fileName(from imageName: String?) -> String? {
        guard let imageName, imageName.hasPrefix(photoPrefix) else { return nil }
        return String(imageName.dropFirst(photoPrefix.count))
    }

    static func imageName(for fileName: String) -> String {
        "\(photoPrefix)\(fileName)"
    }
}

struct LocalImageStore {
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        let url = imageDirectory.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func load(fileName: String) -> UIImage? {
        UIImage(contentsOfFile: imageDirectory.appendingPathComponent(fileName).path)
    }

    private static var imageDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReminderImages", isDirectory: true)
    }
}

