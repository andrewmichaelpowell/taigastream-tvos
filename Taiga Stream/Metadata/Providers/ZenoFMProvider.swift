//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct ZenoFMProvider: MetadataProvider {
	var pollInterval: TimeInterval? { 30 }
	func matches(streamUrl: URL) -> Bool {
		let result = streamUrl.host?.contains("stream.zeno.fm") == true
		return result
	}

	private func mountId(from streamUrl: URL) -> String? {
		streamUrl.pathComponents.first(where: { !$0.isEmpty && $0 != "/" })
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let mount = mountId(from: streamUrl),
			let apiUrl = URL(
				string: "https://api.zeno.fm/mounts/metadata/subscribe/\(mount)"
			)
		else { return }
		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = 60
		config.timeoutIntervalForResource = 3600
		let delegate = ZenoSSEDelegate(
			streamUrl: streamUrl,
			completion: completion
		)
		let session = URLSession(
			configuration: config,
			delegate: delegate,
			delegateQueue: nil
		)
		var request = URLRequest(url: apiUrl)
		request.timeoutInterval = 3600
		request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
		request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
		session.dataTask(with: request).resume()
		delegate.session = session
	}
}

private class ZenoSSEDelegate: NSObject, URLSessionDataDelegate {
	let streamUrl: URL
	let completion: (String, String) -> Void
	var buffer = ""
	var session: URLSession?
	init(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		self.streamUrl = streamUrl
		self.completion = completion
	}

	func urlSession(
		_ session: URLSession,
		dataTask: URLSessionDataTask,
		didReceive data: Data
	) {
		guard let text = String(data: data, encoding: .utf8) else {
			return
		}
		buffer += text

		let events = buffer.components(separatedBy: "\n\n")
		buffer = events.last ?? ""

		for event in events.dropLast() {
			guard !event.isEmpty else { continue }
			for line in event.components(separatedBy: "\n") {
				let prefix = "data: "
				guard line.hasPrefix(prefix) else { continue }
				let jsonString = String(line.dropFirst(prefix.count))
				guard let jsonData = jsonString.data(using: .utf8),
					let json = try? JSONSerialization.jsonObject(with: jsonData)
						as? [String: Any]
				else { continue }
				guard StreamInfo.shared.currentStreamUrl == streamUrl else {
					return
				}
				let streamTitle = (json["streamTitle"] as? String ?? "")
					.trimmingCharacters(in: .whitespaces)
				guard !streamTitle.isEmpty else { continue }
				var normalized = streamTitle
				while normalized.contains("  ") {
					normalized = normalized.replacingOccurrences(
						of: "  ",
						with: " "
					)
				}
				var artist = ""
				var title = normalized

				if normalized.contains(" - ") {
					let (parsedArtist, parsedTitle) =
						StreamInfo.shared.splitArtistTitle(from: normalized)
					if !parsedArtist.isEmpty {
						artist = parsedArtist
						title = parsedTitle
					}
				} else if normalized.contains("-") {
					let parts = normalized.components(separatedBy: "-")
						.map { $0.trimmingCharacters(in: .whitespaces) }
						.filter { !$0.isEmpty }
					if parts.count >= 2 {
						let parsedArtist = StreamInfo.shared
							.cleanMetadataString(parts[0])
						let parsedTitle = StreamInfo.shared.cleanMetadataString(
							parts[1]
						)
						if !parsedArtist.isEmpty && !parsedTitle.isEmpty {
							artist = parsedArtist
							title = parsedTitle
						}
					}
				}

				guard !title.isEmpty,
					!StreamInfo.shared.junkMetadata(title)
				else { continue }
				completion(artist, title)
			}
		}
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: Error?
	) {
		self.session = nil
	}
}
