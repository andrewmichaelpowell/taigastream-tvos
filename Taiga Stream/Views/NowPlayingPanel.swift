//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct NowPlayingPanel: View {
	let highlightedIndex: Int?
	@ObservedObject var streamInfo = StreamInfo.shared

	private var playingIndex: Int? { streamInfo.panelPlayingIndex() }

	private var shownIndex: Int? {
		streamInfo.panelShownIndex(highlightedIndex: highlightedIndex)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			StationArtwork(highlightedIndex: highlightedIndex, size: 440)
				.clipShape(RoundedRectangle(cornerRadius: 24))
				.shadow(radius: 16)
				.padding(.bottom, 16)

			if let playingIndex {
				let stationName = streamInfo.fallbackTitle(
					forSlot: playingIndex + 1
				)
				Text(streamInfo.nowPlayingTitle)
					.font(.title3)
					.bold()
					.lineLimit(2)
				if !streamInfo.nowPlayingArtist.isEmpty {
					Text(streamInfo.nowPlayingArtist)
						.font(.headline)
						.foregroundColor(Color(.secondaryLabel))
						.lineLimit(1)
				}
				if streamInfo.nowPlayingTitle != stationName {
					Text(stationName)
						.font(.callout)
						.foregroundColor(Color(.tertiaryLabel))
						.lineLimit(1)
				}
			} else if let shownIndex {
				Text(streamInfo.fallbackTitle(forSlot: shownIndex + 1))
					.font(.title3)
					.bold()
					.lineLimit(2)
			} else {
				Text("Taiga Stream")
					.font(.title3)
					.bold()
			}

			Spacer()
		}
		.padding(.vertical, 40)
	}
}
