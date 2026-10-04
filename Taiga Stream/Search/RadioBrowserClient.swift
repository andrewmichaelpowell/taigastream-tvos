//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import CFNetwork
import Darwin
import Foundation

class RadioBrowserClient {
	static let shared = RadioBrowserClient()

	private var baseUrl = "https://de1.api.radio-browser.info"
	private var serverResolved = false

	init() {
		resolveServer()
	}

	private func resolveServer() {
		DispatchQueue.global(qos: .utility).async { [weak self] in
			guard let self else { return }
			let host = CFHostCreateWithName(
				nil,
				"all.api.radio-browser.info" as CFString
			).takeRetainedValue()
			CFHostStartInfoResolution(host, .addresses, nil)
			var resolved = DarwinBoolean(false)
			guard
				let addresses = CFHostGetAddressing(host, &resolved)?
					.takeUnretainedValue() as? [Data],
				resolved.boolValue
			else {
				return
			}

			var hostnames: [String] = []
			for addressData in addresses {
				let hostname = addressData.withUnsafeBytes { ptr -> String? in
					var hostBuffer = [CChar](
						repeating: 0,
						count: Int(NI_MAXHOST)
					)
					let sockaddr = ptr.baseAddress!.assumingMemoryBound(
						to: sockaddr.self
					)
					let result = getnameinfo(
						sockaddr,
						socklen_t(addressData.count),
						&hostBuffer,
						socklen_t(hostBuffer.count),
						nil,
						0,
						NI_NAMEREQD
					)
					return result == 0 ? String(cString: hostBuffer) : nil
				}
				if let hostname, !hostname.isEmpty {
					hostnames.append(hostname)
				}
			}

			guard !hostnames.isEmpty else { return }
			let chosen = hostnames.shuffled().first!
			let url = "https://\(chosen)"
			self.baseUrl = url
			self.serverResolved = true
		}
	}

	struct SearchParams {
		var name: String = ""
		var limit: Int = 50
		var offset: Int = 0
		var order: String = "votes"
		var reverse: Bool = true
		var hidebroken: Bool = true
	}

	func search(
		params: SearchParams,
		completion: @escaping ([RadioBrowserStation]) -> Void
	) {
		if !serverResolved {
			DispatchQueue.global(qos: .utility).asyncAfter(
				deadline: .now() + 1.0
			) { [weak self] in
				self?.search(params: params, completion: completion)
			}
			return
		}

		var components = URLComponents(
			string: "\(baseUrl)/json/stations/search"
		)!
		var items: [URLQueryItem] = [
			URLQueryItem(name: "limit", value: String(params.limit)),
			URLQueryItem(name: "offset", value: String(params.offset)),
			URLQueryItem(name: "order", value: params.order),
			URLQueryItem(
				name: "reverse",
				value: params.reverse ? "true" : "false"
			),
			URLQueryItem(
				name: "hidebroken",
				value: params.hidebroken ? "true" : "false"
			),
		]
		if !params.name.isEmpty {
			items.append(URLQueryItem(name: "name", value: params.name))
		}
		components.queryItems = items

		guard let url = components.url else { return }
		var request = URLRequest.noCacheRequest(url: url)
		request.setValue("TaigaStream/1.0", forHTTPHeaderField: "User-Agent")

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [[String: Any]]
			else {
				completion([])
				return
			}
			let stations = json.compactMap { dict -> RadioBrowserStation? in
				guard
					let url = dict["url_resolved"] as? String ?? dict["url"]
						as? String,
					!url.isEmpty
				else { return nil }
				return RadioBrowserStation(
					id: dict["stationuuid"] as? String ?? UUID().uuidString,
					name: dict["name"] as? String ?? "",
					url: url,
					faviconUrl: dict["favicon"] as? String ?? "",
					country: dict["country"] as? String ?? "",
					state: dict["state"] as? String ?? "",
					language: dict["language"] as? String ?? "",
					tags: dict["tags"] as? String ?? "",
					votes: dict["votes"] as? Int ?? 0,
					bitrate: dict["bitrate"] as? Int ?? 0
				)
			}
			completion(stations)
		}.resume()
	}

	func recordClick(stationId: String) {
		guard let url = URL(string: "\(baseUrl)/json/url/\(stationId)") else {
			return
		}
		var request = URLRequest(url: url)
		request.setValue("TaigaStream/1.0", forHTTPHeaderField: "User-Agent")
		URLSession.shared.dataTask(with: request).resume()
	}
}
