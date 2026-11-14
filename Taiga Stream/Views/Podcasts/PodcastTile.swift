//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

/// A podcast in the grid: its artwork with a number badge. Selecting it
/// plays (or pauses) its current episode; holding it opens its options,
/// including the episode list.
struct PodcastTile: View {
	let index: Int
	@Binding var movingIndex: Int?
	@EnvironmentObject var library: PodcastLibrary
	@ObservedObject private var player = PodcastPlayer.shared
	@ObservedObject private var streamInfo = StreamInfo.shared
	@State private var showingOptions = false
	@State private var didLongPress = false
	@State private var showingManualEntry = false
	@State private var showingSearch = false
	@State private var showingEpisodes = false
	@State private var manualUrl = ""
	@State private var manualName = ""

	var isAddButton = false

	var podcast: Podcast { library.podcast(at: index) }

	private var podcastNumber: Int { index + 1 }

	private var isPlaying: Bool {
		streamInfo.isPlaying && player.activePodcastID == podcast.id
			&& !podcast.feedUrl.isEmpty
	}

	private var isMoving: Bool { movingIndex == index }

	var body: some View {
		tileButton
			.sheet(isPresented: $showingOptions) {
				PodcastOptionsSheet(
					index: index,
					isPresented: $showingOptions,
					showingSearch: $showingSearch,
					showingManualEntry: $showingManualEntry,
					showingEpisodes: $showingEpisodes,
					manualUrl: $manualUrl,
					manualName: $manualName,
					movingIndex: $movingIndex
				)
				.environmentObject(library)
			}
			.onChange(of: showingOptions) {
				if !showingOptions { didLongPress = false }
			}
			.sheet(isPresented: $showingSearch) {
				PodcastSearchSheet(slotIndex: index, isPresented: $showingSearch)
					.environmentObject(library)
			}
			.sheet(isPresented: $showingManualEntry) {
				PodcastURLSheet(
					slotIndex: index,
					isPresented: $showingManualEntry,
					manualUrl: $manualUrl,
					manualName: $manualName
				)
				.environmentObject(library)
			}
			.sheet(isPresented: $showingEpisodes) {
				EpisodePickerSheet(
					podcastID: podcast.id,
					isPresented: $showingEpisodes
				)
			}
	}

	private var emptyContent: some View {
		VStack(spacing: 20) {
			PodcastArtworkView(podcast: podcast, size: 120)
			HStack {
				statusLabel
				Spacer()
			}
			.font(.callout)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private var configuredContent: some View {
		GeometryReader { geometry in
			PodcastArtworkView(
				podcast: podcast,
				size: geometry.size.width,
				cornerRadius: 0
			)
		}
		.overlay(alignment: .bottomLeading) {
			statusLabel
				.font(.callout)
				.frame(width: 56, height: 56)
				.badgeGlass()
				.padding(12)
		}
	}

	@ViewBuilder
	private var statusLabel: some View {
		if isMoving {
			Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
				.foregroundColor(Color(.label))
		} else if isPlaying {
			Image(systemName: "pause.fill")
				.foregroundColor(Color(.label))
		} else {
			Text("\(podcastNumber)")
				.foregroundColor(
					podcast.feedUrl.isEmpty
						? Color(.quaternaryLabel) : Color(.label)
				)
		}
	}

	private func select() {
		if didLongPress {
			didLongPress = false
		} else if isMoving {
			movingIndex = nil
		} else if podcast.feedUrl.isEmpty {
			showingOptions = true
		} else {
			Task { await player.play(podcastNumber: podcastNumber) }
		}
	}

	@ViewBuilder
	private var tileButton: some View {
		if isAddButton {
			Color.clear
				.aspectRatio(1, contentMode: .fit)
				.overlay {
					Button(action: { showingOptions = true }) {
						Image(systemName: "plus")
							.font(.title2)
							.foregroundStyle(.white)
							.frame(width: 120, height: 120)
					}
					.addButtonStyle()
					.accessibilityLabel(Text("Add Podcast"))
				}
		} else {
			Button(action: select) {
				Color.clear
					.aspectRatio(1, contentMode: .fit)
					.overlay {
						if podcast.feedUrl.isEmpty {
							emptyContent
						} else {
							configuredContent
						}
					}
			}
			.buttonStyle(.card)
			.accessibilityLabel(
				isPlaying ? Text("Pause") : Text("Play Podcast \(podcastNumber)")
			)
			.simultaneousGesture(
				LongPressGesture(minimumDuration: 0.5).onEnded { _ in
					didLongPress = true
					showingOptions = true
				}
			)
		}
	}
}
