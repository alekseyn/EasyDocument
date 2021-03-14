//
//  ColorValueTransformer.swift
//  PortableDocumentDemo
//
//  Created by Aleksey Novicov on 2/28/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//
// REF: https://www.kairadiagne.com/2020/01/13/nssecurecoding-and-transformable-properties-in-core-data.html

import Foundation
import UIKit

@objc(UIColorValueTransformer)
final class ColorValueTransformer: NSSecureUnarchiveFromDataTransformer {

	/// The name of the transformer. This is the name used to register the transformer using `ValueTransformer.setValueTrandformer(_"forName:)`.
	static let name = NSValueTransformerName(rawValue: String(describing: ColorValueTransformer.self))

	// 2. Make sure `UIColor` is in the allowed class list.
	override static var allowedTopLevelClasses: [AnyClass] {
		return [UIColor.self]
	}

	class override func allowsReverseTransformation() -> Bool {
		true
	}
	
	/// Registers the transformer.
	public static func register() {
		let transformer = ColorValueTransformer()
		ValueTransformer.setValueTransformer(transformer, forName: name)
	}
}
