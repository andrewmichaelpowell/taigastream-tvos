//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI
import UIKit

extension UIColor {
	static let taigaGreen = UIColor(
		red: 4 / 255,
		green: 80 / 255,
		blue: 48 / 255,
		alpha: 1
	)
}

extension View {
	@ViewBuilder
	func badgeGlass() -> some View {
		if #available(tvOS 26.0, *) {
			glassEffect(.regular, in: Circle())
		} else {
			background(Circle().fill(Color.slot))
		}
	}

	@ViewBuilder
	func addButtonStyle() -> some View {
		if #available(tvOS 26.0, *) {
			buttonStyle(.glass).buttonBorderShape(.circle).tint(
				Color(white: 0.35).opacity(0.6)
			)
		} else {
			buttonStyle(.bordered).buttonBorderShape(.circle)
		}
	}
}
