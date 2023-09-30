//
//  UIImageView+LoadImage.swift
//  ImageKit
//
//  Created by Иван Копиев on 19.09.2023.
//

import UIKit

protocol PropertyStoring {

    associatedtype T

    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T
}

extension PropertyStoring {
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T {
        guard let value = objc_getAssociatedObject(self, key) as? T else {
            return defaultValue
        }
        return value
    }
}

private var loadingImageAssociationKey: UInt8 = 0
private let imageCache = RamImageCache()
private let fileCache = DiskImageCache()

extension UIImageView: PropertyStoring {

    typealias T = String

    var loadingImage: String {
        get { return getAssociatedObject(&loadingImageAssociationKey, defaultValue: "") as String }
        set { objc_setAssociatedObject(self, &loadingImageAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

}

public extension UIImageView {

    func load(
        urlString: String,
        withStoring: Bool = true,
        placeholder: UIImage? = nil,
        renderingMode: UIImage.RenderingMode = .alwaysOriginal,
        completion: ((UIImage?) -> Void)? = nil
    ) {
        if withStoring {
            loadStoring(urlString: urlString, placeholder: placeholder, renderingMode: renderingMode, completion: completion)
        } else {
            load(urlString: urlString, placeholder: placeholder, renderingMode: renderingMode, completion: completion)
        }
    }

    private func load(
        urlString: String,
        placeholder: UIImage? = nil,
        renderingMode: UIImage.RenderingMode = .alwaysOriginal,
        completion: ((UIImage?) -> Void)?
    ) {
        guard let urlImage = URL(string: urlString.urlEncoded()) else {
            if let placeholder { image = placeholder }
            return
        }
        loadingImage = urlString
        Task { @MainActor in
            if let placeholder { image = placeholder }
            if let image = try await imageCache.value(for: urlString) {
                guard loadingImage == urlString else { return }
                self.image = image.withRenderingMode(renderingMode)
                completion?(self.image)
                return
            }
            let data = try await getImage(url: urlImage)
            let image = UIImage(data: data)?.withRenderingMode(renderingMode)
            guard loadingImage == urlString else { return }
            imageCache.insert(image, for: urlString)
            self.image = image
            completion?(self.image)
        }
    }

    private func loadStoring(
        urlString: String,
        placeholder: UIImage? = nil,
        renderingMode: UIImage.RenderingMode = .alwaysOriginal,
        completion: ((UIImage?) -> Void)?
    ) {
        guard let urlImage = URL(string: urlString) else {
            if let placeholder { image = placeholder }
            return
        }
        loadingImage = urlString
        Task { @MainActor in
            if let placeholder { image = placeholder }
            if let image = try? await imageCache.value(for: urlString) {
                guard loadingImage == urlString else { return }
                self.image = image.withRenderingMode(renderingMode)
                completion?(self.image)
                return
            }
            if let image = try? await fileCache.value(for: urlString) {
                guard loadingImage == urlString else { return }
                self.image = image.withRenderingMode(renderingMode)
                completion?(self.image)
                imageCache.insert(image, for: urlString)
                return
            }
            let url = try await downloadImage(url: urlImage)
            let data = try Data(contentsOf: url)
            let image = UIImage(data: data)
            guard loadingImage == urlString else { return }
            imageCache.insert(image, for: urlString)
            self.image = image?.withRenderingMode(renderingMode)
            completion?(self.image)
            fileCache.insert(image, for: urlString)
        }
    }

    private func downloadImage(url: URL) async throws -> URL {
        enum ImageLoadError: Error { case notUrl }
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.downloadTask(with: URLRequest(url: url)) { url, _, error in
                if let error  {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: ImageLoadError.notUrl)
                    return
                }
                continuation.resume(with: .success(url))
            }.resume()
        }
    }

    private func getImage(url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }

}

fileprivate extension String {

    func urlEncoded() -> String {
        let allowedChSet = CharacterSet.urlQueryAllowed
        return addingPercentEncoding(withAllowedCharacters: allowedChSet) ?? self
    }
}
