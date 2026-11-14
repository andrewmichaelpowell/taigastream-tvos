//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct MainView: View {
	@AppStorage("SelectedTab") private var selectedTab = MainTab.radio

	static let columnCount = 4

	enum MainTab: String {
		case radio, podcasts
	}

	var body: some View {
		TabView(selection: $selectedTab) {
			Tab(value: MainTab.radio) {
				RadioPage()
			} label: {
				tabIcon("radio")
					.accessibilityLabel(Text("Radio"))
			}
			Tab(value: MainTab.podcasts) {
				PodcastsPage()
			} label: {
				tabIcon("mic")
					.accessibilityLabel(Text("Podcasts"))
			}
		}
	}

	/// Colours come from the tab bar's appearance (see TaigaStream.swift).
	private func tabIcon(_ name: String) -> Image {
		let symbol =
			UIImage(
				systemName: name,
				withConfiguration: UIImage.SymbolConfiguration(pointSize: 34)
			) ?? UIImage()
		return Image(uiImage: symbol.withRenderingMode(.alwaysTemplate))
	}
}

struct RadioPage: View {
	@ObservedObject var streamInfo = StreamInfo.shared
	@State private var movingIndex: Int? = nil
	@FocusState private var focusedStation: UUID?
	@State private var highlightedStation: UUID?

	private let columns = Array(
		repeating: GridItem(.flexible(), spacing: 40),
		count: MainView.columnCount
	)

	var body: some View {
		HStack(alignment: .top, spacing: 0) {
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
					StationTile(
						index: streamInfo.stations.count,
						movingIndex: $movingIndex,
						isAddButton: true
					)
					.environmentObject(streamInfo)
					.disabled(movingIndex != nil)
				}
				.padding(40)
				.padding(.leading, 60)
			}
			.scrollClipDisabled()
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
		case .up: to = from - MainView.columnCount
		case .down: to = from + MainView.columnCount
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
