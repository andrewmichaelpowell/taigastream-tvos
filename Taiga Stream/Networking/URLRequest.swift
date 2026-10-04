//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

extension URLRequest {
	static func noCacheRequest(url: URL) -> URLRequest {
		URLRequest(
			url: url,
			cachePolicy: .reloadIgnoringLocalCacheData,
			timeoutInterval: 10
		)
	}
}
