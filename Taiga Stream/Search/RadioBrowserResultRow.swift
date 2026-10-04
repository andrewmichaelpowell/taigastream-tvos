//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct RadioBrowserResultRow: View {
	let station: RadioBrowserStation

	var body: some View {
		HStack(spacing: 12) {
			FaviconView(
				station: RadioStation(
					url: station.url,
					name: station.name,
					faviconUrl: station.faviconUrl
				),
				size: 60
			)

			VStack(alignment: .leading, spacing: 2) {
				Text(station.name)
					.font(.body)
					.lineLimit(1)
				if !station.state.isEmpty {
					Text(station.state)
						.font(.caption)
						.foregroundColor(Color(.tertiaryLabel))
						.lineLimit(1)
				}
				if !station.country.isEmpty {
					Text(station.country)
						.font(.caption)
						.foregroundColor(Color(.tertiaryLabel))
						.lineLimit(1)
				}
				if !station.tags.isEmpty {
					Text(
						station.tags.components(separatedBy: ",").prefix(2)
							.joined(separator: ", ")
					)
					.font(.caption)
					.foregroundColor(Color(.tertiaryLabel))
					.lineLimit(1)
				}
				if station.bitrate > 0 {
					Text("\(station.bitrate) kbps")
						.font(.caption2)
						.foregroundColor(Color(.tertiaryLabel))
				}
			}
			Spacer()
			Image(systemName: "chevron.right")
				.font(.caption)
				.foregroundColor(Color(.tertiaryLabel))
		}
		.padding(.vertical, 4)
	}
}
