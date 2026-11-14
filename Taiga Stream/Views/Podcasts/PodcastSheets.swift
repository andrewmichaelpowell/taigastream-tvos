//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

/// A full-width sheet button matching the station sheets.
private struct SheetButton: View {
	let title: LocalizedStringResource
	var role: ButtonRole? = nil
	var isLoading = false
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack {
				if isLoading {
					ProgressView().padding(.trailing, 8)
				}
				Text(title)
					.bold()
					.foregroundColor(role == .destructive ? .red : nil)
					.lineLimit(1)
					.fixedSize()
			}
			.frame(maxWidth: .infinity)
		}
	}
}

struct PodcastOptionsSheet: View {
	let index: Int
	@Binding var isPresented: Bool
	@Binding var showingSearch: Bool
	@Binding var showingManualEntry: Bool
	@Binding var showingEpisodes: Bool
	@Binding var manualUrl: String
	@Binding var manualName: String
	@Binding var movingIndex: Int?
	@EnvironmentObject var library: PodcastLibrary

	var podcast: Podcast { library.podcast(at: index) }

	var body: some View {
		NavigationStack {
			VStack(spacing: 20) {
				if !podcast.feedUrl.isEmpty {
					SheetButton(title: "Episodes") {
						isPresented = false
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
							showingEpisodes = true
						}
					}
				}
				SheetButton(title: "Search") {
					isPresented = false
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
						showingSearch = true
					}
				}
				SheetButton(title: "Enter URL") {
					manualUrl = podcast.feedUrl
					manualName = podcast.name
					isPresented = false
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
						showingManualEntry = true
					}
				}
				if !podcast.feedUrl.isEmpty {
					SheetButton(title: "Move") {
						isPresented = false
						movingIndex = index
					}
					SheetButton(title: "Clear", role: .destructive) {
						library.clearPodcast(at: index)
						isPresented = false
					}
				}
				SheetButton(title: "Cancel") {
					isPresented = false
				}

				Spacer()
			}
			.frame(maxWidth: 1200)
			.padding(.horizontal, 40)
			.padding(.top, 40)
			.navigationTitle("Podcast \(index + 1)")
		}
	}
}

struct PodcastURLSheet: View {
	let slotIndex: Int
	@Binding var isPresented: Bool
	@Binding var manualUrl: String
	@Binding var manualName: String
	@EnvironmentObject var library: PodcastLibrary

	private var trimmedUrl: String {
		manualUrl.trimmingCharacters(in: .whitespaces)
	}

	private var isValidUrl: Bool {
		guard let url = URL(string: trimmedUrl),
			let scheme = url.scheme?.lowercased(),
			scheme == "http" || scheme == "https",
			let host = url.host,
			!host.isEmpty
		else { return false }
		return true
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 20) {
				TextField(
					"",
					text: $manualName,
					prompt: .fieldPrompt(systemImage: "mic")
				)
				.autocorrectionDisabled()

				TextField(
					"",
					text: $manualUrl,
					prompt: .fieldPrompt(systemImage: "link")
				)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.never)
				.keyboardType(.URL)
				.onSubmit { save() }

				SheetButton(title: "Save", action: save)
					.disabled(!isValidUrl)
				SheetButton(title: "Cancel") { isPresented = false }

				Spacer()
			}
			.frame(maxWidth: 1200)
			.padding(.horizontal, 40)
			.padding(.top, 40)
			.navigationTitle("Enter URL")
		}
	}

	private func save() {
		guard isValidUrl else { return }
		let existing = library.podcast(at: slotIndex)
		library.savePodcast(
			Podcast(
				feedUrl: trimmedUrl,
				name: manualName.trimmingCharacters(in: .whitespaces),
				artworkUrl: existing.feedUrl == trimmedUrl
					? existing.artworkUrl : ""
			),
			at: slotIndex
		)
		isPresented = false
	}
}

struct PodcastSearchSheet: View {
	let slotIndex: Int
	@Binding var isPresented: Bool
	@EnvironmentObject var library: PodcastLibrary

	@State private var searchTerm = ""
	@State private var results: [PodcastSearchResult] = []
	@State private var isLoading = false
	@State private var hasSearched = false

	private var canSearch: Bool {
		!isLoading && !searchTerm.trimmingCharacters(in: .whitespaces).isEmpty
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 40) {
				VStack(spacing: 20) {
					TextField(
						"",
						text: $searchTerm,
						prompt: .fieldPrompt(systemImage: "magnifyingglass")
					)
					.autocorrectionDisabled()
					.onSubmit { if canSearch { performSearch() } }

					SheetButton(
						title: "Search",
						isLoading: isLoading,
						action: performSearch
					)
					.disabled(!canSearch)

					SheetButton(title: "Cancel") { isPresented = false }
				}

				if hasSearched && results.isEmpty && !isLoading {
					Spacer()
					Text("No results")
						.foregroundColor(Color(.tertiaryLabel))
					Spacer()
				} else {
					List(results) { result in
						Button(action: { select(result) }) {
							PodcastSearchResultRow(result: result)
						}
					}
					// The focused row grows past the list's edges.
					.scrollClipDisabled()
				}
			}
			.padding(.horizontal, 40)
			.padding(.top, 40)
			.navigationTitle("Search")
		}
	}

	private func performSearch() {
		let term = searchTerm.trimmingCharacters(in: .whitespaces)
		guard !term.isEmpty else { return }
		hasSearched = true
		isLoading = true
		results = []
		Task {
			let found = await PodcastSearchClient.search(term)
			results = found
			isLoading = false
		}
	}

	private func select(_ result: PodcastSearchResult) {
		library.savePodcast(
			Podcast(
				feedUrl: result.feedUrl,
				name: result.name,
				artworkUrl: result.artworkUrl
			),
			at: slotIndex
		)
		isPresented = false
	}
}

private struct PodcastSearchResultRow: View {
	let result: PodcastSearchResult

	var body: some View {
		HStack(spacing: 12) {
			PodcastArtworkView(
				podcast: Podcast(
					feedUrl: result.feedUrl,
					name: result.name,
					artworkUrl: result.artworkUrl
				),
				size: 60
			)
			VStack(alignment: .leading, spacing: 2) {
				Text(result.name)
					.font(.body)
					.lineLimit(1)
				if !result.author.isEmpty {
					Text(result.author)
						.font(.caption)
						.foregroundColor(Color(.tertiaryLabel))
						.lineLimit(1)
				}
				if !result.genre.isEmpty {
					Text(result.genre)
						.font(.caption)
						.foregroundColor(Color(.tertiaryLabel))
						.lineLimit(1)
				}
			}
			Spacer()
		}
	}
}

struct EpisodePickerSheet: View {
	let podcastID: UUID
	@Binding var isPresented: Bool
	@ObservedObject private var library = PodcastLibrary.shared
	@ObservedObject private var player = PodcastPlayer.shared
	@ObservedObject private var streamInfo = StreamInfo.shared

	private var podcast: Podcast? { library.podcast(id: podcastID) }
	private var episodes: [PodcastEpisode] {
		library.feeds[podcastID]?.episodes ?? []
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 20) {
				content
			}
			.padding(.horizontal, 40)
			.padding(.top, 40)
			.navigationTitle(podcast?.name ?? String(localized: "Episodes"))
		}
		.task {
			if let podcast, library.feeds[podcastID] == nil {
				await library.refreshFeed(for: podcast)
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		if episodes.isEmpty {
			Spacer()
			if library.loadingFeeds.contains(podcastID)
				|| (library.feeds[podcastID] == nil
					&& !library.failedFeeds.contains(podcastID))
			{
				ProgressView()
			} else {
				Text(
					library.failedFeeds.contains(podcastID)
						? "Couldn't load episodes" : "No episodes"
				)
				.foregroundColor(Color(.tertiaryLabel))
			}
			Spacer()
		} else if let podcast {
			let selectedID = library.currentEpisode(for: podcast)?.id
			ScrollViewReader { proxy in
				List(episodes) { episode in
					Button(action: { select(episode, of: podcast) }) {
						EpisodeRow(
							episode: episode,
							podcast: podcast,
							isSelected: episode.id == selectedID,
							isPlaying: player.activePodcastID == podcastID
								&& player.activeEpisode?.id == episode.id
								&& streamInfo.isPlaying
						)
					}
					.id(episode.id)
				}
				// The focused row grows past the list's edges.
				.scrollClipDisabled()
				.onAppear {
					if let selectedID { proxy.scrollTo(selectedID, anchor: .center) }
				}
			}
		}
	}

	/// Picking an episode makes it the podcast's current one and plays it,
	/// since selecting is how you play things on Apple TV.
	private func select(_ episode: PodcastEpisode, of podcast: Podcast) {
		library.selectEpisode(episode, for: podcast)
		Task { await player.play(episode, of: podcast) }
		isPresented = false
	}
}

private struct EpisodeRow: View {
	let episode: PodcastEpisode
	let podcast: Podcast
	let isSelected: Bool
	let isPlaying: Bool
	@ObservedObject private var library = PodcastLibrary.shared
	@ObservedObject private var player = PodcastPlayer.shared

	private var position: Double {
		if player.activePodcastID == podcast.id,
			player.activeEpisode?.id == episode.id
		{
			return player.position
		}
		return library.savedPosition(podcastID: podcast.id, episode: episode)
	}

	private var details: String {
		var parts: [String] = []
		if let date = PodcastFormat.date(episode.publishedAt) {
			parts.append(date)
		}
		if let remaining = PodcastFormat.remaining(
			position: position,
			duration: episode.duration
		) {
			parts.append(remaining)
		} else if let duration = episode.duration {
			parts.append(PodcastFormat.duration(duration))
		}
		return parts.joined(separator: " · ")
	}

	var body: some View {
		HStack(spacing: 20) {
			Image(
				systemName: isPlaying
					? "speaker.wave.2.fill"
					: isSelected ? "checkmark" : "circle"
			)
			.opacity(isSelected || isPlaying ? 1 : 0)
			.frame(width: 40)
			VStack(alignment: .leading, spacing: 6) {
				Text(episode.title.isEmpty ? episode.audioUrl : episode.title)
					.lineLimit(2)
				if !details.isEmpty {
					Text(details)
						.font(.caption)
						.foregroundColor(Color(.tertiaryLabel))
						.lineLimit(1)
				}
				if let duration = episode.duration, duration > 0, position > 0 {
					ProgressView(value: min(position / duration, 1))
				}
			}
			Spacer(minLength: 0)
		}
	}
}
