//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct ABCRadioProvider: MetadataProvider {
	var pollInterval: TimeInterval? { 15 }

	private static let streamToApi: [String: String] = {
		let base = "https://www.abc.net.au/core-next/api/musicNowPlaying"
		return [
			"mediahubaustralia.com/CTRW":
				"\(base)/COUNTRY?tz=Australia%2FSydney",
			"mediahubaustralia.com/JAZW": "\(base)/JAZZ?tz=Australia%2FSydney",
			"mediahubaustralia.com/2FMW":
				"\(base)/CLASSIC?tz=Australia%2FSydney",
			"mediahubaustralia.com/3FMW":
				"\(base)/CLASSIC?tz=Australia%2FSydney",
			"mediahubaustralia.com/4FMW":
				"\(base)/CLASSIC?tz=Australia%2FBrisbane",
			"mediahubaustralia.com/5FMW":
				"\(base)/CLASSIC?tz=Australia%2FAdelaide",
			"mediahubaustralia.com/6FMW":
				"\(base)/CLASSIC?tz=Australia%2FPerth",
			"mediahubaustralia.com/8FMW":
				"\(base)/CLASSIC?tz=Australia%2FDarwin",
			"mediahubaustralia.com/FM2W":
				"\(base)/CLASSIC2?tz=Australia%2FSydney",
			"mediahubaustralia.com/DJDW":
				"\(base)/DOUBLEJ?tz=Australia%2FSydney",
			"mediahubaustralia.com/3DJW":
				"\(base)/DOUBLEJ?tz=Australia%2FSydney",
			"mediahubaustralia.com/4DJW":
				"\(base)/DOUBLEJ?tz=Australia%2FBrisbane",
			"mediahubaustralia.com/5DJW":
				"\(base)/DOUBLEJ?tz=Australia%2FAdelaide",
			"mediahubaustralia.com/6DJW":
				"\(base)/DOUBLEJ?tz=Australia%2FPerth",
			"mediahubaustralia.com/8DJW":
				"\(base)/DOUBLEJ?tz=Australia%2FDarwin",
			"mediahubaustralia.com/2TJW":
				"\(base)/TRIPLEJ?tz=Australia%2FSydney",
			"mediahubaustralia.com/3TJW":
				"\(base)/TRIPLEJ?tz=Australia%2FSydney",
			"mediahubaustralia.com/4TJW":
				"\(base)/TRIPLEJ?tz=Australia%2FBrisbane",
			"mediahubaustralia.com/5TJW":
				"\(base)/TRIPLEJ?tz=Australia%2FAdelaide",
			"mediahubaustralia.com/6TJW":
				"\(base)/TRIPLEJ?tz=Australia%2FPerth",
			"mediahubaustralia.com/8TJW":
				"\(base)/TRIPLEJ?tz=Australia%2FDarwin",
			"mediahubaustralia.com/TJHW": "\(base)/H100?tz=Australia%2FSydney",
			"mediahubaustralia.com/UNEW":
				"\(base)/UNEARTHED?tz=Australia%2FSydney",
		]
	}()

	private static let stationCodeToApi: [String: String] = {
		let base = "https://www.abc.net.au/core-next/api/musicNowPlaying"
		return [
			"abccountry": "\(base)/COUNTRY?tz=Australia%2FSydney",
			"abcjazz": "\(base)/JAZZ?tz=Australia%2FSydney",
			"classicfmnsw": "\(base)/CLASSIC?tz=Australia%2FSydney",
			"classicfmnt": "\(base)/CLASSIC?tz=Australia%2FDarwin",
			"classicfmqld": "\(base)/CLASSIC?tz=Australia%2FBrisbane",
			"classicfmsa": "\(base)/CLASSIC?tz=Australia%2FAdelaide",
			"classicfmvic": "\(base)/CLASSIC?tz=Australia%2FSydney",
			"classicfmwa": "\(base)/CLASSIC?tz=Australia%2FPerth",
			"classic2": "\(base)/CLASSIC2?tz=Australia%2FSydney",
			"doublejnsw": "\(base)/DOUBLEJ?tz=Australia%2FSydney",
			"doublejnt": "\(base)/DOUBLEJ?tz=Australia%2FDarwin",
			"doublejqld": "\(base)/DOUBLEJ?tz=Australia%2FBrisbane",
			"doublejsa": "\(base)/DOUBLEJ?tz=Australia%2FAdelaide",
			"doublejvic": "\(base)/DOUBLEJ?tz=Australia%2FSydney",
			"doublejwa": "\(base)/DOUBLEJ?tz=Australia%2FPerth",
			"triplejnsw": "\(base)/TRIPLEJ?tz=Australia%2FSydney",
			"triplejnt": "\(base)/TRIPLEJ?tz=Australia%2FDarwin",
			"triplejqld": "\(base)/TRIPLEJ?tz=Australia%2FBrisbane",
			"triplejsa": "\(base)/TRIPLEJ?tz=Australia%2FAdelaide",
			"triplejvic": "\(base)/TRIPLEJ?tz=Australia%2FSydney",
			"triplejwa": "\(base)/TRIPLEJ?tz=Australia%2FPerth",
			"triplejhottest": "\(base)/H100?tz=Australia%2FSydney",
			"triplejunearthed": "\(base)/UNEARTHED?tz=Australia%2FSydney",
		]
	}()

	private static let sortedKeys = streamToApi.keys.sorted {
		$0.count > $1.count
	}

	private static let slugHosts = [
		"akamaized.net",
		"streamguys1.com",
		"streaming.abc-cdn.net.au",
	]

	private func stationCode(from streamUrl: URL) -> String? {
		let components = streamUrl.pathComponents

		if let liveIndex = components.firstIndex(of: "live") {
			for offset in [1, 2] {
				let index = liveIndex + offset
				guard index < components.count else { continue }
				let candidate = components[index]
				if Self.stationCodeToApi[candidate] != nil {
					return candidate
				}
			}
		}

		if let last = components.last(where: { $0 != "/" && !$0.isEmpty }),
			let code = last.components(separatedBy: ".").first,
			Self.stationCodeToApi[code] != nil
		{
			return code
		}

		return nil
	}

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		guard let host = streamUrl.host else { return false }

		if Self.slugHosts.contains(where: { host.contains($0) }) {
			return stationCode(from: streamUrl) != nil
		}
		return Self.sortedKeys.contains(where: { s.contains($0) })
	}

	private func apiUrl(from streamUrl: URL) -> URL? {
		let s = streamUrl.absoluteString
		guard let host = streamUrl.host else { return nil }

		if Self.slugHosts.contains(where: { host.contains($0) }) {
			guard let code = stationCode(from: streamUrl),
				let urlString = Self.stationCodeToApi[code]
			else { return nil }
			return URL(string: urlString)
		}

		guard let key = Self.sortedKeys.first(where: { s.contains($0) }),
			let urlString = Self.streamToApi[key]
		else { return nil }
		return URL(string: urlString)
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let apiUrl = apiUrl(from: streamUrl) else { return }

		URLSession.shared.dataTask(with: .noCacheRequest(url: apiUrl)) {
			data,
			_,
			error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let mapiNow = json["mapiNow"] as? [String: Any]
			else { return }

			let title = (mapiNow["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let artist = (mapiNow["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			if let imageString = mapiNow["primaryImage"] as? String,
				!imageString.isEmpty,
				let imageUrl = URL(string: imageString)
			{
				URLSession.shared.dataTask(with: imageUrl) { imageData, _, _ in
					if let imageData, let image = UIImage(data: imageData) {
						DispatchQueue.main.async {
							StreamInfo.shared.applyArtwork(image)
						}
					}
				}.resume()
			}

			completion(artist, title)
		}.resume()
	}
}
