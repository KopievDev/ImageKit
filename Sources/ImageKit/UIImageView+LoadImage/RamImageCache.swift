//
//  RamImageCache.swift
//  ImageKit
//
//  Created by Иван Копиев on 19.09.2023.
//

import UIKit

protocol Сacheable: AnyObject {
    associatedtype Key
    associatedtype Value
    func value(for key: Key) async throws -> Value?
    func insert(_ value: Value?, for key: Key)
    func remove(for key: Key)
    func removeAll()
}

final class RamImageCache: Сacheable {
    typealias Key = String
    typealias Value = UIImage

    private lazy var imageCache = NSCache<AnyObject, AnyObject>()
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.ImageKit.ImageCache", qos: .utility)

    func value(for key: String) async throws -> UIImage? {
        return try await withCheckedThrowingContinuation { continuation in
            queue.sync { [unowned self] in
                let image = imageCache.object(forKey: key as NSString) as? UIImage
                continuation.resume(with: .success(image))
            }
        }
    }

    func insert(_ value: UIImage?, for key: String) {
        guard let value = value else { return remove(for: key) }
        imageCache.setObject(value, forKey: key as NSString, cost: value.diskSize)
    }

    func remove(for key: String) {
        defer { lock.unlock() }
        lock.lock()
        imageCache.removeObject(forKey: key as NSString)
    }

    func removeAll() {
        defer { lock.unlock() }
        lock.lock()
        imageCache.removeAllObjects()
    }
}

fileprivate extension UIImage {

    var diskSize: Int {
        guard let cgImage = cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
