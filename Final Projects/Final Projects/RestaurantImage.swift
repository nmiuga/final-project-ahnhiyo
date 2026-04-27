import SwiftUI
import UIKit
import ImageIO

struct RestaurantImage: View {
    enum OverlayStyle: Equatable {
        case none
        case bottomFade(opacity: Double)
    }

    private enum LoadState {
        case idle
        case loading
        case success(UIImage)
        case failure
    }

    private final class ImageCache {
        static let shared = NSCache<NSString, UIImage>()
    }

    private static let requestTimeoutSeconds: Double = 12
    private static let maxAttempts: Int = 2

    let photoReference: String?
    let height: CGFloat
    let maxWidth: CGFloat?
    let cornerRadius: CGFloat
    let overlayStyle: OverlayStyle

    init(
        photoReference: String?,
        height: CGFloat,
        maxWidth: CGFloat? = AppLayout.contentMaxWidth,
        cornerRadius: CGFloat = 18,
        overlayStyle: OverlayStyle = .none
    ) {
        self.photoReference = photoReference
        self.height = height
        self.maxWidth = maxWidth
        self.cornerRadius = cornerRadius
        self.overlayStyle = overlayStyle
    }

    @State private var state: LoadState = .idle

    var body: some View {
        ZStack {
            Group {
                if let photoReference, let url = googlePlacesPhotoURL(photoReference: photoReference, maxWidth: 600) {
                    content(for: url)
                        .task(id: url) {
                            state = .idle
                            await load(url: url)
                        }
                } else {
                    error
                }
            }

            switch overlayStyle {
            case .none:
                EmptyView()
            case .bottomFade(let opacity):
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(opacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .frame(maxWidth: maxWidth ?? .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private func content(for url: URL) -> some View {
        switch state {
        case .idle, .loading:
            loading
        case .success(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .saturation(0.85)
        case .failure:
            error
        }
    }

    @MainActor
    private func load(url: URL) async {
        let cacheKey = url.absoluteString as NSString
        if let cached = ImageCache.shared.object(forKey: cacheKey) {
            state = .success(cached)
            return
        }

        if case .loading = state { return }
        state = .loading

        var request = URLRequest(url: url)
        request.setValue("image/jpeg,image/png,image/*;q=0.8", forHTTPHeaderField: "Accept")

        do {
            let uiImage = try await Task.detached(priority: .userInitiated) {
                try await Self.fetchAndDecodeImage(
                    request: request,
                    timeoutSeconds: Self.requestTimeoutSeconds,
                    maxAttempts: Self.maxAttempts
                )
            }.value

            ImageCache.shared.setObject(uiImage, forKey: cacheKey)
            state = .success(uiImage)
        } catch {
            state = .failure
        }
    }

    private static func fetchAndDecodeImage(
        request: URLRequest,
        timeoutSeconds: Double,
        maxAttempts: Int
    ) async throws -> UIImage {
        var lastError: Error?

        for attempt in 1...max(1, maxAttempts) {
            do {
                let (data, response) = try await fetchDataWithTimeout(request: request, timeoutSeconds: timeoutSeconds)

                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                if let uiImage = decodeImage(from: data) {
                    return uiImage
                }
                throw URLError(.cannotDecodeContentData)
            } catch {
                lastError = error

                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(0.35 * 1_000_000_000))
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    private static func fetchDataWithTimeout(request: URLRequest, timeoutSeconds: Double) async throws -> (Data, URLResponse) {
        try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask {
                try await URLSession.shared.data(for: request)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw URLError(.timedOut)
            }

            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    private static func decodeImage(from data: Data) -> UIImage? {
        if let uiImage = UIImage(data: data) {
            return uiImage
        }

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private var loading: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.07))
            ProgressView()
                .tint(AppColors.orangePrimary)
        }
    }

    private var error: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.06))
            Image(systemName: "fork.knife")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.orangePrimary)
        }
    }
}
