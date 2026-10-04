//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct FaviconView: View {
	let station: RadioStation
	var size: CGFloat = 36
	var cornerRadius: CGFloat? = nil
	@State private var favicon: UIImage? = nil
	@State private var faviconNeedsBackground = false
	@State private var faviconNeedsInset = false
	@State private var faviconBleed: CGFloat = 1
	@State private var faviconLoadFailed = false
	@State private var fallbackIcon: UIImage? = nil

	private var isSavedWithoutFavicon: Bool {
		!station.url.isEmpty
			&& (faviconLoadFailed || URL(string: station.faviconUrl) == nil
				|| station.faviconUrl.isEmpty)
	}

	var body: some View {
		Group {
			if let favicon {
				Image(uiImage: favicon)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.scaleEffect(
						faviconNeedsInset
							? StreamInfo.transparentIconInset : faviconBleed
					)
					.frame(width: size, height: size)
					.background(
						faviconNeedsBackground ? Color.white : Color.clear
					)
			} else if isSavedWithoutFavicon,
				let appIcon = StreamInfo.shared.appIcon
			{
				Image(uiImage: appIcon)
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else if let fallbackIcon {
				Image(uiImage: fallbackIcon)
					.resizable()
					.renderingMode(.template)
					.foregroundColor(
						station.url.isEmpty
							? Color(.quaternaryLabel) : Color(.label)
					)
					.aspectRatio(contentMode: .fit)
			} else {
				Color.clear
			}
		}
		.frame(width: size, height: size)
		.clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? size / 6))
		.onAppear {
			loadFallbackIcon()
			loadFavicon()
		}
		.onChange(of: station.faviconUrl) { loadFavicon() }
	}

	private func loadFallbackIcon() {
		fallbackIcon = UIImage(systemName: "antenna.radiowaves.left.and.right")
	}

	private func normalizeImage(_ image: UIImage) -> UIImage {
		let renderer = UIGraphicsImageRenderer(size: image.size)
		return renderer.image { _ in
			image.draw(in: CGRect(origin: .zero, size: image.size))
		}
	}

	private func loadFavicon() {
		faviconLoadFailed = false
		guard !station.faviconUrl.isEmpty,
			let url = URL(string: station.faviconUrl)
		else {
			favicon = nil
			faviconNeedsBackground = false
			faviconNeedsInset = false
			faviconBleed = 1
			return
		}
		URLSession.shared.dataTask(with: url) { data, _, _ in
			if let data, let image = UIImage(data: data) {
				let normalized = self.normalizeImage(image)
				let treatment = StreamInfo.faviconTreatment(for: normalized)
				let bleed =
					treatment.needsBleed
					? StreamInfo.cornerBleedScale(for: normalized) : 1
				DispatchQueue.main.async {
					favicon = normalized
					faviconNeedsBackground = treatment.needsBackground
					faviconNeedsInset = treatment.needsInset
					faviconBleed = bleed
				}
			} else {
				DispatchQueue.main.async { faviconLoadFailed = true }
			}
		}.resume()
	}
}
