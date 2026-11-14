//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

/// The Podcasts tab: the same layout as the stations, with a Now Playing
/// panel on the left and a grid of podcast artwork on the right.
struct PodcastsPage: View {
	@ObservedObject var library = PodcastLibrary.shared
	@State private var movingIndex: Int? = nil
	@FocusState private var focusedPodcast: UUID?
	@State private var highlightedPodcast: UUID?

	private let columns = Array(
		repeating: GridItem(.flexible(), spacing: 40),
		count: MainView.columnCount
	)

	var body: some View {
		HStack(alignment: .top, spacing: 0) {
			PodcastNowPlayingPanel(highlightedID: highlightedPodcast)
				.frame(width: 440)

			ScrollView {
				LazyVGrid(columns: columns, spacing: 40) {
					ForEach(
						Array(library.podcasts.enumerated()),
						id: \.element.id
					) { index, podcast in
						PodcastTile(index: index, movingIndex: $movingIndex)
							.environmentObject(library)
							.focused($focusedPodcast, equals: podcast.id)
							.disabled(
								movingIndex != nil && movingIndex != index
							)
							.onMoveCommand { direction in
								movePodcast(direction)
							}
					}
					PodcastTile(
						index: library.podcasts.count,
						movingIndex: $movingIndex,
						isAddButton: true
					)
					.environmentObject(library)
					.disabled(movingIndex != nil)
				}
				.padding(40)
				// The gap to the panel is inside the scroll area, so the
				// focused tile's shadow has room on the left too.
				.padding(.leading, 60)
			}
			// The focused tile grows and casts a shadow past the grid's
			// edge; without this the scroll view cuts it off in a straight
			// line next to the panel.
			.scrollClipDisabled()
		}
		.background {
			GeometryReader { geometry in
				PodcastArtwork(
					highlightedID: highlightedPodcast,
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
		.onChange(of: focusedPodcast) {
			if let focusedPodcast { highlightedPodcast = focusedPodcast }
		}
		.task { await library.refreshAllFeeds() }
	}

	private func movePodcast(_ direction: MoveCommandDirection) {
		guard let from = movingIndex else { return }
		var to = from
		switch direction {
		case .left: to = from - 1
		case .right: to = from + 1
		case .up: to = from - MainView.columnCount
		case .down: to = from + MainView.columnCount
		@unknown default: return
		}
		guard to >= 0, to < library.podcasts.count else { return }
		let id = library.podcasts[from].id
		library.movePodcast(
			from: IndexSet(integer: from),
			to: to > from ? to + 1 : to
		)
		movingIndex = to
		focusedPodcast = id
	}
}

/// The podcast the panel and background show: the one playing or paused,
/// otherwise the one with focus.
private func shownPodcast(highlightedID: UUID?) -> Podcast? {
	let library = PodcastLibrary.shared
	if let id = PodcastPlayer.shared.activePodcastID,
		let podcast = library.podcast(id: id)
	{
		return podcast
	}
	return highlightedID.flatMap { library.podcast(id: $0) }
}

struct PodcastArtwork: View {
	let highlightedID: UUID?
	let size: CGFloat
	@ObservedObject private var library = PodcastLibrary.shared
	@ObservedObject private var player = PodcastPlayer.shared
	@ObservedObject private var streamInfo = StreamInfo.shared

	private var playingArtwork: UIImage? {
		player.isActive ? streamInfo.nowPlayingArtwork : nil
	}

	private var podcast: Podcast? { shownPodcast(highlightedID: highlightedID) }

	private var contentID: String {
		if let playingArtwork {
			return "artwork-\(ObjectIdentifier(playingArtwork).hashValue)"
		}
		return podcast.map { "podcast-\($0.id)" } ?? "app"
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
		} else if let podcast {
			PodcastArtworkView(podcast: podcast, size: size, cornerRadius: 0)
		} else {
			Image("FallbackIcon")
				.resizable()
				.aspectRatio(contentMode: .fill)
		}
	}
}

struct PodcastNowPlayingPanel: View {
	let highlightedID: UUID?
	@ObservedObject private var library = PodcastLibrary.shared
	@ObservedObject private var player = PodcastPlayer.shared

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			PodcastArtwork(highlightedID: highlightedID, size: 440)
				.clipShape(RoundedRectangle(cornerRadius: 24))
				.shadow(radius: 16)
				.padding(.bottom, 16)

			if let podcast = shownPodcast(highlightedID: highlightedID) {
				let isActive = player.activePodcastID == podcast.id
				let episode =
					isActive ? player.activeEpisode : library.currentEpisode(for: podcast)
				if let episode {
					Text(episode.title.isEmpty ? podcast.name : episode.title)
						.font(.title3)
						.bold()
						.lineLimit(2)
				}
				Text(podcast.name.isEmpty ? podcast.feedUrl : podcast.name)
					.font(.headline)
					.foregroundColor(Color(.secondaryLabel))
					.lineLimit(1)
				if let episode {
					progress(for: episode, of: podcast, isActive: isActive)
				}
			} else {
				Text("Taiga Stream")
					.font(.title3)
					.bold()
			}

			Spacer()
		}
		.padding(.vertical, 40)
	}

	@ViewBuilder
	private func progress(
		for episode: PodcastEpisode,
		of podcast: Podcast,
		isActive: Bool
	) -> some View {
		let position =
			isActive
			? player.position
			: library.savedPosition(podcastID: podcast.id, episode: episode)
		let duration = isActive ? (player.duration ?? episode.duration) : episode.duration
		if let duration, duration > 0, position > 0 {
			ProgressView(value: min(position / duration, 1))
				.tint(Color(.secondaryLabel))
		}
		if let detail = PodcastFormat.remaining(position: position, duration: duration)
			?? PodcastFormat.date(episode.publishedAt)
		{
			Text(detail)
				.font(.callout)
				.foregroundColor(Color(.tertiaryLabel))
		}
	}
}

struct PodcastArtworkView: View {
	let podcast: Podcast
	var size: CGFloat = 36
	var cornerRadius: CGFloat? = nil

	var body: some View {
		FaviconView(
			station: RadioStation(
				url: podcast.feedUrl,
				name: podcast.name,
				faviconUrl: podcast.artworkUrl
			),
			size: size,
			cornerRadius: cornerRadius,
			fallbackSystemImage: "mic"
		)
	}
}

enum PodcastFormat {
	static func duration(_ seconds: Double) -> String {
		let rounded = max(seconds.rounded(), 60)
		return Duration.seconds(rounded).formatted(
			.units(allowed: [.hours, .minutes], width: .abbreviated)
		)
	}

	static func remaining(position: Double, duration: Double?) -> String? {
		guard let duration, duration > 0, position > 0 else { return nil }
		let left = duration - position
		guard left > 0 else { return nil }
		return String(localized: "\(Self.duration(left)) left")
	}

	static func date(_ date: Date?) -> String? {
		date?.formatted(date: .abbreviated, time: .omitted)
	}
}
