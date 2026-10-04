//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct StarFMProvider: MetadataProvider {
	var pollInterval: TimeInterval? { nil }

	private static let streamToWebSocket: [String: String] = [
		"stream.starfm.de/berlin":
			"wss://api.streamabc.net/metadata/channel/30_vqtea82nbeon_wvxg",
		"stream.starfm.de/nbg":
			"wss://api.streamabc.net/metadata/channel/30_nbw9xzg7b53v_rgfj",
		"stream.starfm.de/sachsen":
			"wss://api.streamabc.net/metadata/channel/30_ngfg2edxug0a_dtze",
		"stream.starfm.de/nrw":
			"wss://api.streamabc.net/metadata/channel/30_7hciprr0pewh_dkmc",
		"stream.starfm.de/national":
			"wss://api.streamabc.net/metadata/channel/30_2d7qgd0rqsqd_w0dh",
		"stream.starfm.de/alternat":
			"wss://api.streamabc.net/metadata/channel/30_9cjjuqbztc7b_w6tv",
		"stream.starfm.de/90srock":
			"wss://api.streamabc.net/metadata/channel/30_eoplhpklkmnv_zqnc",
		"stream.regenbogen2.de/festivalradio":
			"wss://api.streamabc.net/metadata/channel/atsw_tit9bqllti_g79y",
		"stream.starfm.de/newmetal":
			"wss://api.streamabc.net/metadata/channel/30_nz784lvvrv58_unsh",
		"stream.starfm.de/hardrock":
			"wss://api.streamabc.net/metadata/channel/30_x7lg1zfcn9df_3swf",
		"stream.starfm.de/fromhell":
			"wss://api.streamabc.net/metadata/channel/30_lpuzm574hotr_d953",
		"stream.starfm.de/80srock":
			"wss://api.streamabc.net/metadata/channel/30_lu3nhavsoefx_avs0",
		"stream.starfm.de/classic":
			"wss://api.streamabc.net/metadata/channel/30_wiqder3bbvvp_amxb",
		"stream.starfm.de/blues":
			"wss://api.streamabc.net/metadata/channel/30_yn083yo8fisj_ccoq",
		"stream.starfm.de/ballads":
			"wss://api.streamabc.net/metadata/channel/30_7fh19amhhhoe_d25l",
		"stream.starfm.de/country":
			"wss://api.streamabc.net/metadata/channel/30_euch8c5krctp_dirs",
		"stream.starfm.de/xmas":
			"wss://api.streamabc.net/metadata/channel/30_1x9rkasxzg6m_isgi",
		"stream.starfm.de/newrock":
			"wss://api.streamabc.net/metadata/channel/30_etgneoupeuu8_vu9s",
		"stream.starfm.de/bbrock":
			"wss://api.streamabc.net/metadata/channel/30_vchltty8vm2i_1gq3",
	]

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		return Self.streamToWebSocket.keys.contains(where: { s.contains($0) })
	}

	private func wsUrl(from streamUrl: URL) -> URL? {
		let s = streamUrl.absoluteString
		guard
			let urlString = Self.streamToWebSocket.first(where: {
				s.contains($0.key)
			})?.value
		else { return nil }
		return URL(string: urlString)
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let wsUrl = wsUrl(from: streamUrl) else { return }

		let session = URLSession(configuration: .default)
		let task = session.webSocketTask(with: wsUrl)

		func receive() {
			task.receive { result in
				guard StreamInfo.shared.currentStreamUrl == streamUrl else {
					task.cancel()
					return
				}
				switch result {
				case .success(let message):
					if case .string(let text) = message,
						let data = text.data(using: .utf8),
						let json = try? JSONSerialization.jsonObject(with: data)
							as? [String: Any]
					{
						let artist = (json["artist"] as? String ?? "")
							.trimmingCharacters(in: .whitespaces)
						let title = (json["song"] as? String ?? "")
							.trimmingCharacters(in: .whitespaces)
						if !title.isEmpty
							&& !StreamInfo.shared.junkMetadata(title)
						{
							completion(artist, title)
						}
					}
					receive()
				case .failure:
					task.cancel()
				}
			}
		}

		task.resume()
		receive()
	}
}
