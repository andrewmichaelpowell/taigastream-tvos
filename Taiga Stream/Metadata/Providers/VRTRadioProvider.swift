//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct VRTRadioProvider: MetadataProvider {
	var pollInterval: TimeInterval? { 30 }

	private static let streamToPage: [String: String] = [
		"icecast.vrtcdn.be/radio1": "/vrtmax/livestream/audio/radio1/",
		"icecast.vrtcdn.be/ra2ant":
			"/vrtmax/livestream/audio/radio2-antwerpen/",
		"icecast.vrtcdn.be/ra2lim": "/vrtmax/livestream/audio/radio2-limburg/",
		"icecast.vrtcdn.be/ra2ovl":
			"/vrtmax/livestream/audio/radio2-oost-vlaanderen/",
		"icecast.vrtcdn.be/ra2vlb":
			"/vrtmax/livestream/audio/radio2-vlaams-brabant/",
		"icecast.vrtcdn.be/ra2wvl":
			"/vrtmax/livestream/audio/radio2-west-vlaanderen/",
		"icecast.vrtcdn.be/klara": "/vrtmax/livestream/audio/klara/",
		"icecast.vrtcdn.be/klaracontinuo":
			"/vrtmax/livestream/audio/klara-continuo/",
		"icecast.vrtcdn.be/stubru": "/vrtmax/livestream/audio/stubru/",
		"icecast.vrtcdn.be/mnm": "/vrtmax/livestream/audio/mnm/",
		"icecast.vrtcdn.be/mnm_hits": "/vrtmax/livestream/audio/mnm-hits/",
	]

	private static let sortedKeys = streamToPage.keys.sorted {
		$0.count > $1.count
	}

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		return Self.sortedKeys.contains { s.contains($0) }
	}

	private func pagePath(from streamUrl: URL) -> String? {
		let s = streamUrl.absoluteString

		guard let key = Self.sortedKeys.first(where: { s.contains($0) }) else {
			return nil
		}

		return Self.streamToPage[key]
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let pagePath = pagePath(from: streamUrl),
			let apiUrl = URL(
				string: "https://www.vrt.be/vrtnu-api/graphql/public/v1"
			)
		else { return }

		let query = """
			{
			  "query": "query AudioLivestreamPage($path: ID!) { page(id: $path) { ... on AudioLivestreamPage { player { title subtitle maxAge } } } }",
			  "variables": { "path": "\(pagePath)" }
			}
			"""

		guard let bodyData = query.data(using: .utf8) else { return }

		var request = URLRequest.noCacheRequest(url: apiUrl)
		request.httpMethod = "POST"
		request.httpBody = bodyData
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		request.setValue("https://www.vrt.be", forHTTPHeaderField: "Origin")
		request.setValue(
			"https://www.vrt.be\(pagePath)",
			forHTTPHeaderField: "Referer"
		)
		request.setValue("WEB", forHTTPHeaderField: "x-vrt-client-name")
		request.setValue("1.5.17", forHTTPHeaderField: "x-vrt-client-version")
		request.setValue("default", forHTTPHeaderField: "x-vrt-zone")
		request.setValue(
			"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
			forHTTPHeaderField: "User-Agent"
		)

		URLSession.shared.dataTask(with: request) { data, response, error in
			guard let data else { return }
			guard
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let dataObj = json["data"] as? [String: Any],
				let page = dataObj["page"] as? [String: Any],
				let player = page["player"] as? [String: Any]
			else {
				return
			}

			let title = (player["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let artist = (player["subtitle"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)

			guard !title.isEmpty,
				!StreamInfo.shared.junkMetadata(title)
			else { return }

			completion(artist, title)
		}.resume()
	}
}
