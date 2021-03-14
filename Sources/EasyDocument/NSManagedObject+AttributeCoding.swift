//
//  NSManagedObject+AttributeCoding.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 3/11/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//

import Foundation
import CoreData

// Adapted from something similar but which requires conformance to Codable
// https://github.com/rileytestut/Harmony/blob/master/Harmony/Extensions/KeyedContainers%2BManagedValues.swift

extension NSManagedObject {
	
	func encodedManagedValue(_ value: Any, forKey key: String) throws -> Any? {
		let attributeDescription = self.entity.attributesByName[key]

		let undefinedErrorString = "encodeManagedValue() does not support undefined attribute types."
		let unsupportedErrorString = "encodeManagedValue() does not support objectID attributes."
		let unknownErrorString = "encodeManagedValue() encountered unknown attribute type."
		
		var encodedValue: Any?
		
		if let attributeType = attributeDescription?.attributeType {
			switch (attributeType, value) {
			
			case (.integer16AttributeType, let value as Int16): encodedValue = value
			case (.integer32AttributeType, let value as Int32): encodedValue = value
			case (.integer64AttributeType, let value as Int64): encodedValue = value
			case (.decimalAttributeType, let value as Decimal): encodedValue = value
			case (.doubleAttributeType, let value as Double): encodedValue = value
			case (.floatAttributeType, let value as Float): encodedValue = value
			case (.stringAttributeType, let value as String): encodedValue = value
			case (.booleanAttributeType, let value as Bool): encodedValue = value
			case (.dateAttributeType, let value as Date): encodedValue = value
			case (.binaryDataAttributeType, let value as Data): encodedValue = value
			case (.UUIDAttributeType, let value as UUID): encodedValue = value
			case (.URIAttributeType, let value as URL): encodedValue = value.absoluteString
				
			case (.transformableAttributeType, let value as NSCoding):
				encodedValue = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)

			case (.transformableAttributeType, let value):
				guard
					let transformerName = attributeDescription?.valueTransformerName,
					let transformer = ValueTransformer(forName: NSValueTransformerName(transformerName))
				else { throw ArchiveEncodingError.invalidValue(key) }

				encodedValue = transformer.transformedValue(value)
					
			case (.integer16AttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.integer32AttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.integer64AttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.decimalAttributeType,_): throw ArchiveEncodingError.invalidValue(key)
			case (.doubleAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.floatAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.stringAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.booleanAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.dateAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.binaryDataAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.UUIDAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
			case (.URIAttributeType, _): throw ArchiveEncodingError.invalidValue(key)
				
			case (.undefinedAttributeType, _): fatalError(undefinedErrorString)
			case (.objectIDAttributeType, _): fatalError(unsupportedErrorString)
				
			@unknown default: fatalError(unknownErrorString)
			}
		}
		return encodedValue
	}
	
	func decodedManagedValue(_ value: Any, forKey key: String) throws -> Any? {
		let attributeDescription = self.entity.attributesByName[key]

		let undefinedErrorString = "decodeManagedAttribute() does not support undefined attribute types."
		let unsupportedErrorString = "decodeManagedAttribute() does not support objectID attributes."
		let unknownErrorString = "decodeManagedAttribute() encountered unknown attribute type."

		guard let attributeType = attributeDescription?.attributeType else {
			throw ArchiveDecodingError.unknownAttribute(key: key)
		}

		var decodedValue: Any? = value

		switch attributeType {
		case .integer16AttributeType: break
		case .integer32AttributeType: break
		case .integer64AttributeType: break
		case .decimalAttributeType: break
		case .doubleAttributeType: break
		case .floatAttributeType: break
		case .stringAttributeType: break
		case .booleanAttributeType: break
		case .dateAttributeType: break
		case .binaryDataAttributeType: break
		case .UUIDAttributeType: break

		case .URIAttributeType:
			if let urlString = value as? String {
				decodedValue = (URL(string: urlString))
			}
			else {
				throw ArchiveDecodingError.dataCorrupted(key: key)
			}

		case .transformableAttributeType where attributeDescription?.valueTransformerName == nil || attributeDescription?.valueTransformerName == NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue:
			
			if let data = value as? Data {
				decodedValue = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)
			}

		case .transformableAttributeType:
			guard
				let transformerName = attributeDescription?.valueTransformerName,
				let transformer = ValueTransformer(forName: NSValueTransformerName(transformerName))
			else { throw ArchiveDecodingError.dataCorrupted(key: key) }

			decodedValue = transformer.transformedValue(value)

		case .undefinedAttributeType: fatalError(undefinedErrorString)
		case .objectIDAttributeType: fatalError(unsupportedErrorString)
		@unknown default: fatalError(unknownErrorString)
		}

		return decodedValue
	}
}

public enum ArchiveEncodingError: Error {
	case invalidValue(String)
	case dataCorrupted(String)
}

public enum ArchiveDecodingError: Error {
	case dataCorrupted(key: String)
	case unknownAttribute(key: String)
}

