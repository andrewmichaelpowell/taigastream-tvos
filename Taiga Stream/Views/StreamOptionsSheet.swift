//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct StreamOptionsSheet: View {
	let index: Int
	@Binding var isPresented: Bool
	@Binding var showingSearch: Bool
	@Binding var showingManualEntry: Bool
	@Binding var manualUrl: String
	@Binding var manualName: String
	@Binding var movingIndex: Int?
	@EnvironmentObject var streamInfo: StreamInfo

	var station: RadioStation { streamInfo.stations[index] }

	var body: some View {
		NavigationStack {
			VStack(spacing: 20) {
				optionButton("Search") {
					isPresented = false
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
						showingSearch = true
					}
				}
				optionButton("Enter URL") {
					manualUrl = station.url
					manualName = station.name
					isPresented = false
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
						showingManualEntry = true
					}
				}
				optionButton("Move") {
					isPresented = false
					movingIndex = index
				}
				if !station.url.isEmpty {
					optionButton("Clear", role: .destructive) {
						streamInfo.saveStation(.empty, at: index)
						isPresented = false
					}
				}
				optionButton("Cancel") {
					isPresented = false
				}

				Spacer()
			}
			.frame(maxWidth: 1200)
			.padding(.horizontal, 40)
			.padding(.top, 40)
			.navigationTitle("Stream \(index + 1)")
		}
	}

	@ViewBuilder
	private func optionButton(
		_ title: LocalizedStringResource,
		role: ButtonRole? = nil,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			Text(title)
				.bold()
				.foregroundColor(role == .destructive ? .red : nil)
				.lineLimit(1)
				.fixedSize()
				.frame(maxWidth: .infinity)
		}
	}
}
