//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct SverigesRadioProvider: MetadataProvider {
	var pollInterval: TimeInterval? { 15 }

	private static let streamToChannelId: [String: Int] = [
		"/p1/": 132, "/p1-": 132, "sr-p1": 132,
		"/p2/": 163, "/p2-": 163, "sr-p2": 163,
		"/p3/": 164, "/p3-": 164, "sr-p3": 164,
		"p4-blekinge": 204,
		"p4-dalarna": 201,
		"p4-gavleborg": 207,
		"p4-gotland": 209,
		"p4-halland": 206,
		"p4-jamtland": 210,
		"p4-jonkoping": 205,
		"p4-kalmar": 214,
		"p4-kronoberg": 213,
		"p4-norrbotten": 212,
		"p4-skaraborg": 530,
		"p4-skane": 211,
		"p4-stockholm": 203,
		"p4-sormland": 215,
		"p4-uppland": 216,
		"p4-varmland": 196,
		"p4-vast": 197,
		"p4-vasterbotten": 200,
		"p4-vasternorrland": 202,
		"p4-vastmanland": 208,
		"p4-ostergotland": 217,
		"sr-p4": 500,
		"sr-extra": 666,
		"p6-": 2576,
		"sr-p6": 2576,
		"lc/p1": 132,
		"lc/p2": 163,
		"lc/p3": 164,
		"edge1.sr.se/p1": 132,
		"edge1.sr.se/p2": 163,
		"edge1.sr.se/p3": 164,
		"edge2.sr.se/p1": 132,
		"edge2.sr.se/p2": 163,
		"edge3.sr.se/p3": 164,
	]

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString.lowercased()
		return (s.contains(".sr.se") || s.contains("sverigesradio"))
			&& channelId(from: streamUrl) != nil
	}

	private func channelId(from streamUrl: URL) -> Int? {
		let s = streamUrl.absoluteString.lowercased()
		return Self.streamToChannelId.keys
			.sorted { $0.count > $1.count }
			.first(where: { s.contains($0) })
			.flatMap { Self.streamToChannelId[$0] }
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let channelId = channelId(from: streamUrl),
			let apiUrl = URL(
				string:
					"https://api.sr.se/api/v2/playlists/rightnow?channelid=\(channelId)&format=json"
			)
		else { return }

		let request = URLRequest.noCacheRequest(url: apiUrl)

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let playlist = json["playlist"] as? [String: Any],
				let song = playlist["song"] as? [String: Any]
			else { return }

			let artist = (song["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (song["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty,
				!StreamInfo.shared.junkMetadata(title)
			else { return }

			completion(artist, title)
		}.resume()
	}
}
