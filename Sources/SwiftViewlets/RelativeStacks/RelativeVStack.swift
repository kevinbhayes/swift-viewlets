//
//  RelativeVStack.swift
//  MacMessingAround
//
//  Created by Kevin Hayes on 2025-04-18.
//

import SwiftUI

/// A View Stack that arranges views in a vertical line and allows views to specify what portion of the stack to occupy.
///
/// Views can specify the portion of the stack they wish to occupy using the
/// `.relativeStackPortion(_:)` modifier that supplies a Double between 0 and 1.
/// Views that are unable to grow (e.g. a Text) will ignore this value.
///
/// The supplied relative heights across all views combined with the minimum
/// heights of the total views and the provided spacer may result in a the view
/// drawing below its bottom boundary if the Stack has a fixed frame that is
/// not tall enough to handle the supplied views and parameters.
///
/// Example usage:
/// ```
/// 	RelativeVStack(alignment: .center, spacing: 1.0) {
///			Color.green
///			  .relativeLayoutHeight(0.3)
///			  .frame(width: 50)
///		  	Color.yellow
///			  .frame(width: 250)
///		  	Color.orange
///		  	Color.red
///		  	Color.purple
///			  .frame(width: 250)
///		  	Color.blue
///			  .frame(width: 200)
///			  .relativeLayoutHeight(0.15)
///  	}
///  	.frame(width: 300, height: 300)
/// ```
public struct RelativeVStack: Layout {
	let alignment: HorizontalAlignment
	let spacing: CGFloat

	/// Creates an instance with the given spacing and horizontal alignment.
	/// - Parameter alignment: The guide for aligning the subviews in this stack.
	/// - Parameter spacing: The amount of space to place between each subview. The default is 0.0 points.
	public init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 0.0) {
		self.alignment = alignment
		self.spacing = spacing
	}


	public func makeCache(subviews: Subviews) -> RelativeCacheInfo {
		RelativeCacheInfo()
	}

	public static var layoutProperties: LayoutProperties {
		var properties = LayoutProperties()
		properties.stackOrientation = .vertical
		return properties
	}

	public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout RelativeCacheInfo) -> CGSize {
		let totalSpacing = spacing * CGFloat(subviews.count - 1)
		let width = proposal.width ?? .zero
		// if the height is not provided, get the minimum heights of the subviews
		// we detect a Spacer() based on a width of 0.0. Which probably isn’t
		// perfect, but a 0-width view draws nothing so it’s a fairly safe assumptions
		// similar views like Color have non-zero minimum widths
		let height = proposal.height ?? (subviews.reduce(.zero) { result, subview in
			let dimension = subview.dimensions(in: .unspecified)
			let infiniteDimension = subview.dimensions(in: .infinity)
			return result + ((dimension.width == 0 && infiniteDimension.width == 0) ? 0.0 : dimension.height)
		} + totalSpacing)

		// to calculate the widest view to return
		var maxWidth: CGFloat = .zero
		// initialize the cache
		updateCache(&cache, subviews: subviews)

		// total heights of views that have relativeStackPortion applied
		var totalRelativeHeight: CGFloat = .zero
		// total of all relativeStackPortion values
		var totalMultiplier: CGFloat = .zero
		// count of views that do not have relativeStackPortion applied and
		// have been determined to not be Spacer
		var countNonRelativeViews: Int = .zero
		// total height of views that do not have relativeStackPortion applied
		// and have been determined to not be spacers
		var totalNonRelativeHeight: CGFloat = .zero
		// the count of all Spacers()
		var countSpacers: Int = .zero
		// for alignment purposes, calculate the maximum offset of the x coordinate
		var maxXOffset: CGFloat = .zero

		// height of the view minus the spacing values as they are fixed
		let nonSpacingHeight = height - totalSpacing

		for subview in subviews {
			// find the minimum and maximum widths of the views for determining
			// the overall width of the view to return
			let subviewSize = subview.dimensions(in: .unspecified)
			let subviewSizeInfinity = subview.dimensions(in: .infinity)
			// if it can grow, then we want it to grow to the proposed width of the container
			maxWidth = max(maxWidth, min(subviewSizeInfinity.width, width))

			// for horizontal alignment
			let xOffset = subview.dimensions(in: proposal)[alignment]
			maxXOffset = max(maxXOffset, xOffset)

			// we have a view with relativeStackPortion applied
			if let relativeHeightMultiplier = subview[RelativePortionKey.self] {
				totalMultiplier += min(relativeHeightMultiplier, 1.0)
				totalRelativeHeight += subviewSize.height
				cache.subviewInfo.append(RelativeCacheInfo.SubviewInfo(length: height * relativeHeightMultiplier, type: .relative, alignmentOffset: xOffset))
			}
			else {
				// check for Spacer views
				if subviewSize.width == 0,
				   subview.dimensions(in: .infinity).width == 0 {
					// we likely have a spacer or spacer-like view
					countSpacers += 1
					cache.subviewInfo.append(RelativeCacheInfo.SubviewInfo(length: subviewSize.height, type: .spacer, alignmentOffset: xOffset))
				}
				else {
					// view that is not a Spacer and has not have relativeStackPortion applied
					countNonRelativeViews += 1
					totalNonRelativeHeight += subviewSize.height
					cache.subviewInfo.append(RelativeCacheInfo.SubviewInfo(length: subviewSize.height, type: .regular(canGrow: true), alignmentOffset: xOffset))
				}
			}
		}

		// we can return early, but we always want to set the alignment cache
		cache.maxAlignmentOffset = maxXOffset

		// total portion of the view height that has a relativeStackPortion applied
		let totalMultipliedHeight = totalMultiplier * height
		let remainingHeight = nonSpacingHeight - totalMultipliedHeight

		// we're at the full height of the view but no non-relative multiplied views
		// so we must report a larger size back to SwiftUI
		if totalMultipliedHeight == nonSpacingHeight,
		   countNonRelativeViews == 0 {
			cache.spacerLength = 0.0
			cache.totalLength = totalMultipliedHeight + totalNonRelativeHeight
			return CGSize(width: maxWidth, height: totalMultipliedHeight + totalNonRelativeHeight + totalSpacing)
		}

		// views with relative height multipliers exceed the height
		// so we must report a larger height back to SwiftUI
		guard remainingHeight > 0 else {
			cache.spacerLength = 0.0
			cache.totalLength = totalMultipliedHeight + totalNonRelativeHeight
			return CGSize(width: maxWidth, height: totalMultipliedHeight + totalNonRelativeHeight + totalSpacing)
		}

		// we’ve got room, so we’ll continue

		var totalFixedHeightRegular: CGFloat = .zero

		if countSpacers > 0 {
			// if we have Spacer views, their height is a split of the remaining
			// height in the proposed space
			cache.spacerLength = (remainingHeight - totalNonRelativeHeight) / CGFloat(countSpacers)
		}
		else {
			// no spacers, so we have to grow the views that don't have
			// relativeStackPortion applied, if they can grow
			for (index, subview) in subviews.enumerated() {
				if case .regular(_) = cache.subviewInfo[index].type {
					// figure out which can grow
					let subviewInfo = cache.subviewInfo[index]
					let height = subview.sizeThatFits(.infinity).height

					// if the max and current view are the same, the views can’t grow
					// update the cache for this view to indicate it cannot grow
					if subviewInfo.length == height {
						cache.subviewInfo[index].updateType(.regular(canGrow: false))
						totalNonRelativeHeight -= height
						totalFixedHeightRegular += height
					}
				}
			}

			// cache the multiplier for the remaining views without relativeStackPortion applied that are able to grow
			cache.nonRelativeMultiplier = (nonSpacingHeight - totalFixedHeightRegular - totalMultipliedHeight) / totalNonRelativeHeight
		}

		// set remaining cache values and return size

		cache.totalLength = height

		return CGSize(width: maxWidth, height: height)
	}

	public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout RelativeCacheInfo) {
		var bounds = bounds

		// sometimes SwiftUI will call placeSubviews with a size without first
		// calling sizeThatFits with that size, rendering the cache invalid
		// if tthat is the case, call sizeThatFits to update the cache
		if bounds.height != cache.totalLength {
			bounds.size = sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
		}

		var y: CGFloat = bounds.minY
		let nonRelativeMultiplier = cache.nonRelativeMultiplier


		for (index, subview) in subviews.enumerated() {
			let subviewInfo = cache.subviewInfo[index]

			let subviewHeight = switch subviewInfo.type {
				case .spacer:
					cache.spacerLength
				case .regular(let canGrow):
					subviewInfo.length * (canGrow ? nonRelativeMultiplier : 1.0)
				case .relative:
					subviewInfo.length
			}

			// alignments other than .leading will always “push” the subviews forward
			// let's bring them back based on the maximum alignment offset
			let x = bounds.minX - subviewInfo.alignmentOffset + cache.maxAlignmentOffset

			subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: proposal.width, height: subviewHeight))
			y += subviewHeight + spacing
		}
	}
}

#if DEBUG
#Preview {
	RelativeVStack(alignment: .center, spacing: 1.0) {
		Color.green
			.relativeStackPortion(0.3)
			.frame(width: 50)
		Color.yellow
			.frame(width: 250)
		Color.orange
		Color.red
		Color.purple
			.frame(width: 250)
		Color.blue
			.frame(width: 200)
			.relativeStackPortion(0.15)
	}
	.frame(width: 300, height: 300)
	.border(.black)
	.padding(100)
}
#endif
