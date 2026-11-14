//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import SwiftUI
import UIKit

@main

struct TaigaStream: App {
	init() {
		let appearance = UITabBarAppearance()
		appearance.configureWithTransparentBackground()
		appearance.selectionIndicatorTintColor = UIColor.white
			.withAlphaComponent(0.80)
		for item in [
			appearance.stackedLayoutAppearance,
			appearance.inlineLayoutAppearance,
			appearance.compactInlineLayoutAppearance,
		] {
			item.normal.iconColor = .white
			item.selected.iconColor = .taigaGreen
			item.focused.iconColor = .taigaGreen
		}
		UITabBar.appearance().standardAppearance = appearance
	}

	var body: some Scene {
		WindowGroup {
			MainView()
		}
	}
}
