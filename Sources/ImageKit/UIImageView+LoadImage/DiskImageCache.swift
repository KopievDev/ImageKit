//
//  DiskImageCache.swift
//  ImageKit
//
//  Created by Иван Копиев on 19.09.2023.
//

import UIKit

final class DiskImageCache: Сacheable {

    typealias Key = String
    typealias Value = UIImage

    enum FileError: Error {
        case wrongData
        case noFile
    }

    var documentsDir: String {
        NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }

    var imageDir: String {
        documentsDir + "/images"
    }

    private let queue = DispatchQueue(label: "com.ImageKit.FileCache", qos: .utility)

    init() {
        createImageDir()
    }

    func value(for key: String) async throws -> UIImage? {
        let fileOriginal = imageDir.appendingPathComponent(normal(path: key.toBase64()))
        return try await withCheckedThrowingContinuation { continuation in
            if FileManager.default.fileExists(atPath: fileOriginal) {
                guard let data = FileManager.default.contents(atPath: fileOriginal) else {
                    continuation.resume(throwing: FileError.wrongData)
                    return
                }
                guard let image = UIImage(data: data) else {
                    continuation.resume(throwing: FileError.wrongData)
                    return
                }
                continuation.resume(with: .success(image))
            } else {
                continuation.resume(throwing: FileError.noFile)
            }
        }
    }

    func insert(_ value: UIImage?, for key: String) {
        guard let data = value?.pngData() else { return }
        let fileOriginal = imageDir.appendingPathComponent(normal(path: key.toBase64()))
        FileManager.default.createFile(atPath: fileOriginal, contents: data)
    }

    func remove(for key: String) {
        let fileOriginal = imageDir.appendingPathComponent(normal(path: key.toBase64()))
        try? FileManager.default.removeItem(atPath: fileOriginal)
    }

    func removeAll() {
        do {
            try FileManager.default.removeItem(atPath: imageDir)
            createImageDir()
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

private extension DiskImageCache {

    func normal(path: String) -> String {
        let wrongSymbols = ["/", ":", "?", "=", "&", "%"]
        var path = path
        wrongSymbols.forEach { path = path.replacingOccurrences(of: $0, with: "_") }
        return path
    }

    func createImageDir() {
        if !FileManager.default.fileExists(atPath: imageDir) {
            try? FileManager.default.createDirectory(
                atPath: imageDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}

fileprivate extension String {

    func appendingPathComponent(_ append: String) -> String {
        var s = self
        var append = append
        if s.last == "/" { s.removeLast() }
        if append.first == "/" { append.removeFirst() }
        return s + "/" + append
    }

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        Data(self.utf8).base64EncodedString()
    }
}
