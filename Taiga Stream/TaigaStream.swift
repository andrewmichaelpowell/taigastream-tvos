//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import SwiftUI
import UIKit

@main

struct TaigaStream: App {
	init() {
		let appearance = UITabBarAppearance()
		appearance.configureWithTransparentBackground()
		appearance.selectionIndicatorTintColor = .taigaGreen
		for item in [
			appearance.stackedLayoutAppearance,
			appearance.inlineLayoutAppearance,
			appearance.compactInlineLayoutAppearance,
		] {
			item.normal.iconColor = .white
			item.selected.iconColor = .white
			item.focused.iconColor = .white
		}
		UITabBar.appearance().standardAppearance = appearance
	}

	var body: some Scene {
		WindowGroup {
			MainView()
		}
	}
}
