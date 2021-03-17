//
//  NSManagedObject+Decoding.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 3/12/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObject {

	func setInverseRelationship(for destination: NSManagedObject) {
		let relationships = destination.entity.relationshipsByName.values.filter { $0.destinationEntity?.name == entity.name }
		
		if let relationship = relationships.first {
			if relationship.isToMany {
				
				if relationship.isOrdered {
					if let manyValues = destination.value(forKey: relationship.name) as? NSMutableOrderedSet {
						manyValues.add(self)
					}
					else if var manyValues = destination.value(forKey: relationship.name) as? Array<Any> {
						manyValues.append(self)
					}
					else {
						assertionFailure("Unexpected type for an ordered set.")
					}
				}
				else {
					if let manyValues = destination.value(forKey: relationship.name) as? NSMutableSet {
						manyValues.add(self)
					}
					else {
						assertionFailure("Unexpected type for an unordered set.")
					}
				}
			}
			else {
				destination.setValue(self, forKey: relationship.name)
			}
		}
		
		if relationships.count > 1 {
			assertionFailure("Multiple relationships between the same entities not currently supported.")
		}
	}
	
	func inflateManagedAttribute(key: String, value: Any) {
		do {
			let decodedValue = try decodedManagedValue(value, forKey: key)
			setValue(decodedValue, forKey: key)
		}
		catch ArchiveDecodingError.unknownAttribute(key) {
			assertionFailure("Decoded managed value unknown for " + key)
		}
		catch ArchiveDecodingError.dataCorrupted(key) {
			assertionFailure("Decoded managed value corrupted for " + key)
		}
		catch {
			assertionFailure("Unexpected error: \(error)")
		}
	}
	
	func inflateToOneRelationship(key: String, value: NSDictionary) {
		guard let context = self.managedObjectContext else { return }
		
		if let managedObject = value.inflate(into: context) {
			setValue(managedObject, forKey: key)
			setInverseRelationship(for: managedObject)
		}
	}
	
	func inflateToManyRelationship(key: String, value array: [NSDictionary]) {
		guard let context = self.managedObjectContext,
			  let isOrdered = entity.relationshipsByName[key]?.isOrdered
		else { return }

		let mutableSet = NSMutableSet()
		let mutableOrderedSet = NSMutableOrderedSet()
		
		for relatedObjectDictionary in array {
			if relatedObjectDictionary.isLeafNode(matching: key), let archiveID = relatedObjectDictionary[key] as? String {
				
				// Save a leaf node reference for later resolution
				let leafNode = LeafNode(managedObject: self,
										archiveID: archiveID,
										relationshipKey: key,
										index: array.firstIndex(of: relatedObjectDictionary))
				
				NSManagedObject.append(leafNode: leafNode)
			}
			else {
				if let relatedObject = relatedObjectDictionary.inflate(into: context) {
					if isOrdered {
						mutableOrderedSet.add(relatedObject)
					}
					else {
						mutableSet.add(relatedObject)
					}
				}
			}
		}
		
		// It appears we need to manually add the inverse relationship ourselves.
		// The special considerations for setPrimitiveValue:forKey seem to also apply to setValue:forKey
		// REF. https://developer.apple.com/documentation/coredata/nsmanagedobject/1506960-setprimitivevalue?changes=_9_5_1

		if isOrdered {
			setValue(mutableOrderedSet, forKey: key)
			
			for object in mutableOrderedSet {
				if let managedObject = object as? NSManagedObject {
					setInverseRelationship(for: managedObject)
				}
			}
		}
		else {
			setValue(mutableSet, forKey: key)
			
			for object in mutableSet.allObjects {
				if let managedObject = object as? NSManagedObject {
					setInverseRelationship(for: managedObject)
				}
			}
		}
	}
		
	// Use as: let duplicateObject: Example? = managedObject.duplicate()
	
	public func duplicate<T: NSManagedObject>() -> T? {
		if let archive = dictionaryArchive() {
			let managedObjects = managedObjectContext?.insertedObjects(from: [archive])

			return managedObjects?.first as? T
		}
		return T()
	}
}
