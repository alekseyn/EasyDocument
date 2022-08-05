//
//  NSManagedObjectContext+Decoding.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 3/11/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
	public func insertedObjects(from array: [NSDictionary]) -> [NSManagedObject] {
		let topLevelEntityName = array.first?.entityName
		assert(topLevelEntityName != nil, "First inserted object entity name is missing.")

		// Make a copy of objects already inserted in the managed object context
		let previouslyInsertedObjects = Array(insertedObjects)
		
		// Track order of inflated top level objects
		var inflatedObjects = [NSManagedObject]()
		
		NSManagedObject.clearLeafNodes()
		NSManagedObject.clearTraversedObjects()

		for dictionary in array {
			if let managedObject = dictionary.inflate(into: self) {
				inflatedObjects.append(managedObject)
			}
		}
		resolveLeafNodes()

		// Clear out memory
		NSManagedObject.clearLeafNodes()
		NSManagedObject.clearTraversedObjects()

		// Return all of the fresh top level objects that have been inserted
		let topLevelObjects = insertedObjects.subtracting(previouslyInsertedObjects).filter({ $0.entity.name == topLevelEntityName })
		assert(inflatedObjects.count == topLevelObjects.count, "Unexpected failure after inflating top level objects")
		
		return inflatedObjects
	}
	
	func entityDescription(for entityName: String) -> NSEntityDescription? {
		let managedObjectModel = persistentStoreCoordinator?.managedObjectModel
		return managedObjectModel?.entitiesByName[entityName]
	}
	
	func relationshipDescription(for key: String, in entityName: String) -> NSRelationshipDescription? {
		let entity = entityDescription(for: entityName)
		return entity?.relationshipsByName[key]
	}
	
	func isRelationship(for key: String, in entityName: String) -> Bool {
		relationshipDescription(for: key, in: entityName) != nil
	}
	
	func resolveLeafNodes() {
		for leafNode in NSManagedObject.leafNodes {
			let traversedObjects = NSManagedObject.traversedObjects
			let source = leafNode.managedObject
			
			if let entityName = source.entity.name,
			   let relationship = relationshipDescription(for: leafNode.relationshipKey, in: entityName),
			   let destination = traversedObjects.first(where: { leafNode.archiveID == $0.key })?.value {
				
				if relationship.isToMany {
					if relationship.isOrdered {
						let orderedSet = source.value(forKey: relationship.name) as? NSMutableOrderedSet
						
						if let index = leafNode.index {
							orderedSet?.insert(destination, at: index)
						}
					}
					else {
						let unorderedSet = source.value(forKey: relationship.name) as? NSMutableSet
						unorderedSet?.add(destination)
					}
				}
				else {
					source.setValue(destination, forKey: relationship.name)
				}
				source.setInverseRelationship(for: destination)
			}
			else {
				assertionFailure("Leaf node is corrupted!")
			}
		}
	}
}

// MARK: - Array

extension Array where Element: Equatable {
	func subtracting(_ array: Array<Element>) -> Array<Element> {
		self.filter { !array.contains($0) }
	}
}
