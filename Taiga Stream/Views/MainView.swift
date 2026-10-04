//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct MainView: View {
	@ObservedObject var streamInfo = StreamInfo.shared
	@State private var movingIndex: Int? = nil
	@FocusState private var focusedStation: UUID?
	@State private var highlightedStation: UUID?

	static let columnCount = 4

	private let columns = Array(
		repeating: GridItem(.flexible(), spacing: 40),
		count: columnCount
	)

	var body: some View {
		HStack(alignment: .top, spacing: 60) {
			NowPlayingPanel(highlightedIndex: highlightedIndex)
				.frame(width: 440)

			ScrollView {
				LazyVGrid(columns: columns, spacing: 40) {
					ForEach(
						Array(streamInfo.stations.enumerated()),
						id: \.element.id
					) { index, station in
						StationTile(index: index, movingIndex: $movingIndex)
							.environmentObject(streamInfo)
							.focused($focusedStation, equals: station.id)
							.disabled(
								movingIndex != nil && movingIndex != index
							)
							.onMoveCommand { direction in
								moveStation(direction)
							}
					}
				}
				.padding(40)
			}
		}
		.background {
			GeometryReader { geometry in
				StationArtwork(
					highlightedIndex: highlightedIndex,
					size: geometry.size.width
				)
				.frame(width: geometry.size.width, height: geometry.size.height)
				.clipped()
				.blur(radius: 60, opaque: true)
				.overlay(Color.black.opacity(0.55))
			}
			.ignoresSafeArea()
		}
		.onExitCommand(
			perform: movingIndex == nil ? nil : { movingIndex = nil }
		)
		.onChange(of: focusedStation) {
			if let focusedStation { highlightedStation = focusedStation }
		}
	}

	private var highlightedIndex: Int? {
		streamInfo.stations.firstIndex { $0.id == highlightedStation }
	}

	private func moveStation(_ direction: MoveCommandDirection) {
		guard let from = movingIndex else { return }
		var to = from
		switch direction {
		case .left: to = from - 1
		case .right: to = from + 1
		case .up: to = from - Self.columnCount
		case .down: to = from + Self.columnCount
		@unknown default: return
		}
		guard to >= 0, to < streamInfo.stations.count else { return }
		let id = streamInfo.stations[from].id
		streamInfo.moveStation(
			from: IndexSet(integer: from),
			to: to > from ? to + 1 : to
		)
		movingIndex = to
		focusedStation = id
	}
}
