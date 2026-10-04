//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct RadioBrowserSearchSheet: View {
	let slotIndex: Int
	@Binding var isPresented: Bool
	@EnvironmentObject var streamInfo: StreamInfo

	@State private var searchName = ""
	@State private var results: [RadioBrowserStation] = []
	@State private var isLoading = false
	@State private var hasSearched = false
	@State private var currentOffset = 0
	private let pageSize = 50

	var body: some View {
		NavigationStack {
			VStack(spacing: 40) {
				VStack(spacing: 20) {
					TextField(
						"",
						text: $searchName,
						prompt: .fieldPrompt(systemImage: "magnifyingglass")
					)
					.autocorrectionDisabled()
					.onSubmit {
						if !searchName.isEmpty { performSearch() }
					}

					Button(action: performSearch) {
						HStack {
							if isLoading {
								ProgressView().padding(.trailing, 8)
							}
							Text("Search")
								.bold()
								.lineLimit(1)
								.fixedSize()
						}
						.frame(maxWidth: .infinity)
					}
					.disabled(isLoading || searchName.isEmpty)

					Button(action: { isPresented = false }) {
						Text("Cancel")
							.bold()
							.lineLimit(1)
							.fixedSize()
							.frame(maxWidth: .infinity)
					}
				}

				if hasSearched && results.isEmpty && !isLoading {
					Spacer()
					Text("No results")
						.foregroundColor(Color(.tertiaryLabel))
					Spacer()
				} else {
					List {
						ForEach(results) { station in
							Button(action: { selectStation(station) }) {
								RadioBrowserResultRow(station: station)
							}
						}
						if results.count == pageSize
							* (currentOffset / pageSize + 1)
							&& !isLoading
						{
							Button(action: loadMore) {
								Text("More results")
									.frame(
										maxWidth: .infinity,
										alignment: .leading
									)
									.padding(.leading, 72)
							}
						}
						if isLoading && !results.isEmpty {
							HStack {
								Spacer()
								ProgressView()
								Spacer()
							}
						}
					}
				}
			}
			.padding(.horizontal, 40)
			.padding(.top, 40)
			.navigationTitle("Search")
		}
	}

	private var allFieldsEmpty: Bool { searchName.isEmpty }
	private func performSearch() {
		currentOffset = 0
		results = []
		hasSearched = true
		isLoading = true
		let params = RadioBrowserClient.SearchParams(
			name: searchName,
			limit: pageSize,
			offset: 0
		)
		RadioBrowserClient.shared.search(params: params) { stations in
			DispatchQueue.main.async {
				results = stations
				isLoading = false
			}
		}
	}

	private func loadMore() {
		isLoading = true
		currentOffset += pageSize
		let params = RadioBrowserClient.SearchParams(
			name: searchName,
			limit: pageSize,
			offset: currentOffset
		)
		RadioBrowserClient.shared.search(params: params) { stations in
			DispatchQueue.main.async {
				results.append(contentsOf: stations)
				isLoading = false
			}
		}
	}

	private func selectStation(_ station: RadioBrowserStation) {
		let saved = RadioStation(
			url: station.url,
			name: station.name,
			faviconUrl: station.faviconUrl
		)
		streamInfo.saveStation(saved, at: slotIndex)
		RadioBrowserClient.shared.recordClick(stationId: station.id)
		isPresented = false
	}
}
