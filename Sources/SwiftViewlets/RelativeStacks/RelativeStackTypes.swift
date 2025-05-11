//
//  RelativeStackTypes.swift
//  SwiftViewlets
//
//  Created by Kevin Hayes on 2025-05-10.
//

import SwiftUI

/// Cache used by RelativeStacks to store sizing and layout information
///
/// This should never need to be created manually.
public class RelativeCacheInfo {
	var errorState: Bool = false
	var nonRelativeMultiplier: CGFloat = 1.0
	var spacerLength: CGFloat = 0.0
	var subviewInfo: [SubviewInfo]
	var maxAlignmentOffset: CGFloat = 0.0
	var totalLength: CGFloat = 0.0

	init() {
		subviewInfo = []
	}

	struct SubviewInfo {
		let length: CGFloat
		var type: SubviewType
		let alignmentOffset: CGFloat

		mutating func updateType(_ type: SubviewType) {
			self.type = type
		}
	}

	enum SubviewType {
		case relative
		case regular(canGrow: Bool)
		case spacer
	}
}

struct RelativePortionKey: LayoutValueKey {
	static let defaultValue: Double? = nil
}

public extension View {
	/// Specifies the retalive portion to occupy inside a RelativeStack
	/// - Parameter multiplier: the portion of the stack to occupy.
	/// Valid values are between 0.0 and 1.0, non-inclusively
	func relativeStackPortion(_ multiplier: Double?) -> some View {
		layoutValue(key: RelativePortionKey.self, value: multiplier)
	}
}
