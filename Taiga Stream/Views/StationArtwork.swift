//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

extension StreamInfo {
	func panelPlayingIndex() -> Int? {
		let index = currentStream - 1
		guard isPlaying, isConfigured(index) else { return nil }
		return index
	}

	func panelShownIndex(highlightedIndex: Int?) -> Int? {
		if let playing = panelPlayingIndex() { return playing }
		guard let highlightedIndex, isConfigured(highlightedIndex) else {
			return nil
		}
		return highlightedIndex
	}

	private func isConfigured(_ index: Int) -> Bool {
		stations.indices.contains(index) && !stations[index].url.isEmpty
	}
}

struct StationArtwork: View {
	let highlightedIndex: Int?
	let size: CGFloat
	@ObservedObject var streamInfo = StreamInfo.shared

	private var shownIndex: Int? {
		streamInfo.panelShownIndex(highlightedIndex: highlightedIndex)
	}

	private var playingArtwork: UIImage? {
		streamInfo.panelPlayingIndex() == nil
			? nil : streamInfo.nowPlayingArtwork
	}

	private var contentID: String {
		if let playingArtwork {
			return "artwork-\(ObjectIdentifier(playingArtwork).hashValue)"
		}
		if let shownIndex {
			return "station-\(streamInfo.stations[shownIndex].id)"
		}
		return "app"
	}

	var body: some View {
		ZStack {
			content
				.id(contentID)
				.transition(.opacity)
		}
		.frame(width: size, height: size)
		.animation(.easeInOut(duration: 0.5), value: contentID)
	}

	@ViewBuilder
	private var content: some View {
		if let playingArtwork {
			Image(uiImage: playingArtwork)
				.resizable()
				.aspectRatio(contentMode: .fill)
		} else if let shownIndex {
			FaviconView(
				station: streamInfo.stations[shownIndex],
				size: size,
				cornerRadius: 0
			)
		} else {
			Image("FallbackIcon")
				.resizable()
				.aspectRatio(contentMode: .fill)
		}
	}
}
