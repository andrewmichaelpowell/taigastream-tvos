//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct BBCRadioProvider: MetadataProvider {
	private static let serviceMap: [String: String] = [
		"bbc_1xtra":
			"https://rms.api.bbc.co.uk/v2/services/bbc_1xtra/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_6music":
			"https://rms.api.bbc.co.uk/v2/services/bbc_6music/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_one":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_one/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_one_anthems":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_one_anthems/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_one_dance":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_one_dance/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_two":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_two/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_three":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_three/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_three_unwind":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_three_unwind/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_four_extra":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_four_extra/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_five_live":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_five_live/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_asian_network":
			"https://rms.api.bbc.co.uk/v2/services/bbc_asian_network/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_scotland":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_scotland/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_scotland_mw":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_scotland_mw/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_orkney":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_orkney/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_shetland":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_shetland/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_nan_gaidheal":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_nan_gaidheal/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_wales":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_wales/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_wales_am":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_wales_am/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_ulster":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_ulster/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_cymru":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_cymru/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_cymru_2":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_cymru_2/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_foyle":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_foyle/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_berkshire":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_berkshire/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_bristol":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_bristol/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_cambridge":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_cambridge/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_cornwall":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_cornwall/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_coventry_warwickshire":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_coventry_warwickshire/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_cumbria":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_cumbria/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_derby":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_derby/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_devon":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_devon/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_essex":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_essex/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_gloucestershire":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_gloucestershire/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_guernsey":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_guernsey/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_hereford_worcester":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_hereford_worcester/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_humberside":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_humberside/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_jersey":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_jersey/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_kent":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_kent/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_lancashire":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_lancashire/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_leeds":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_leeds/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_leicester":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_leicester/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_lincolnshire":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_lincolnshire/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_london":
			"https://rms.api.bbc.co.uk/v2/services/bbc_london/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_manchester":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_manchester/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_merseyside":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_merseyside/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_newcastle":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_newcastle/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_norfolk":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_norfolk/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_northampton":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_northampton/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_nottingham":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_nottingham/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_oxford":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_oxford/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_sheffield":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_sheffield/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_shropshire":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_shropshire/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_solent":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_solent/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_solent_west_dorset":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_west_dorset/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_somerset_sound":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_somerset_sound/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_stoke":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_stoke/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_suffolk":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_suffolk/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_surrey":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_surrey/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_sussex":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_sussex/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_tees":
			"https://rms.api.bbc.co.uk/v2/services/bbc_tees/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_three_counties_radio":
			"https://rms.api.bbc.co.uk/v2/services/bbc_three_counties_radio/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_wiltshire":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_wiltshire/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_wm":
			"https://rms.api.bbc.co.uk/v2/services/bbc_wm/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_radio_york":
			"https://rms.api.bbc.co.uk/v2/services/bbc_radio_york/segments/latest?experience=domestic&offset=0&limit=1",
		"bbc_world_service":
			"https://rms.api.bbc.co.uk/v2/services/bbc_world_service/segments/latest?experience=domestic&offset=0&limit=1",
	]

	private static let sortedKeys = serviceMap.keys.sorted {
		$0.count > $1.count
	}

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		return Self.sortedKeys.contains { s.contains($0) }
	}

	private func apiUrl(from streamUrl: URL) -> URL? {
		let s = streamUrl.absoluteString

		guard let key = Self.sortedKeys.first(where: { s.contains($0) }) else {
			return nil
		}

		return URL(string: Self.serviceMap[key]!)
	}

	func poll(
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		guard let apiUrl = apiUrl(from: streamUrl) else { return }
		var request = URLRequest.noCacheRequest(url: apiUrl)
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let dataArray = json["data"] as? [[String: Any]],
				let nowPlaying = dataArray.first(where: {
					($0["offset"] as? [String: Any])?["now_playing"] as? Bool
						== true
				}) ?? dataArray.first,
				let titles = nowPlaying["titles"] as? [String: Any]
			else { return }

			let artist = (titles["primary"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (titles["secondary"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			completion(artist, title)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
