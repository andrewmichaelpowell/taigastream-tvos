//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct IcecastProvider: MetadataProvider {
	func matches(streamUrl: URL) -> Bool { true }

	func poll(
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		guard
			var components = URLComponents(
				url: streamUrl,
				resolvingAgainstBaseURL: false
			)
		else { return }
		components.path = "/status-json.xsl"
		components.query = nil
		components.scheme = "https"
		guard let statusUrl = components.url else { return }
		let mountPath = streamUrl.path

		URLSession.shared.dataTask(with: .noCacheRequest(url: statusUrl)) {
			data,
			_,
			error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let iceStats = json["icestats"] as? [String: Any]
			else { return }

			var sources: [[String: Any]] = []
			if let array = iceStats["source"] as? [[String: Any]] {
				sources = array
			} else if let single = iceStats["source"] as? [String: Any] {
				sources = [single]
			}

			let match =
				sources.first {
					($0["listenurl"] as? String)?.hasSuffix(mountPath) == true
				} ?? sources.first
			guard let source = match,
				let rawTitle = source["title"] as? String
			else { return }

			if let rawArtist = source["artist"] as? String,
				!rawArtist.trimmingCharacters(in: .whitespaces).isEmpty
			{
				let artist = StreamInfo.shared.cleanMetadataString(
					rawArtist.trimmingCharacters(in: .whitespaces)
				)
				let title = StreamInfo.shared.cleanMetadataString(
					rawTitle.trimmingCharacters(in: .whitespaces)
				)
				guard !title.isEmpty else { return }
				completion(artist, title)
				return
			}

			let title = rawTitle.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			let hyphenParts = title.components(separatedBy: " - ")
			let lastPart =
				hyphenParts.last?.trimmingCharacters(in: .whitespaces) ?? ""
			let isIsrc =
				lastPart.range(
					of: #"^[A-Z][A-Z0-9]{7,11}$"#,
					options: .regularExpression
				) != nil
			if hyphenParts.count >= 3 && isIsrc {
				let cleanParts = hyphenParts.dropLast().map {
					$0.trimmingCharacters(in: .whitespaces)
				}
				let isrcTitle = StreamInfo.shared.cleanMetadataString(
					cleanParts.first ?? ""
				)
				let isrcArtist = StreamInfo.shared.cleanMetadataString(
					cleanParts.dropFirst().joined(separator: " - ")
				)
				if !isrcTitle.isEmpty {
					completion(isrcArtist, isrcTitle)
					return
				}
			}

			let (parsedArtist, parsedTitle) = StreamInfo.shared
				.splitArtistTitle(
					from: title
				)
			let resolvedTitle =
				parsedTitle.isEmpty
				? StreamInfo.shared.cleanMetadataString(title) : parsedTitle
			completion(parsedArtist, resolvedTitle)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
