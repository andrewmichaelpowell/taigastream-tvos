//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct ManualURLSheet: View {
	let slotIndex: Int
	@Binding var isPresented: Bool
	@Binding var manualUrl: String
	@EnvironmentObject var streamInfo: StreamInfo
	@Binding var manualName: String

	var station: RadioStation { streamInfo.stations[slotIndex] }

	private var isValidUrl: Bool {
		guard
			let url = URL(
				string: manualUrl.trimmingCharacters(in: .whitespaces)
			),
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
					prompt: .fieldPrompt(systemImage: "radio")
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

				Button(action: save) {
					Text("Save")
						.bold()
						.lineLimit(1)
						.fixedSize()
						.frame(maxWidth: .infinity)
				}
				.disabled(!isValidUrl)

				Button(action: { isPresented = false }) {
					Text("Cancel")
						.bold()
						.lineLimit(1)
						.fixedSize()
						.frame(maxWidth: .infinity)
				}

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
		let saved = RadioStation(
			url: manualUrl.trimmingCharacters(in: .whitespaces),
			name: manualName.trimmingCharacters(in: .whitespaces),
			faviconUrl: station.faviconUrl
		)
		streamInfo.saveStation(saved, at: slotIndex)
		isPresented = false
	}
}
