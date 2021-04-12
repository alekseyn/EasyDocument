//
//  NSDictionary+Decoding.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 3/11/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//

import Foundation
import CoreData

let EntityNameKey = "entity"
let ArchiveIDKey = "archiveID"

// Each dictionary representation of a managed object and it's properties
// also includes the 'entity' name of the managed object, and an 'archiveID'
// used to resolve leaf nodes.

extension NSDictionary {
	@objc var entityName: String? {
		(object(forKey: EntityNameKey) as! String).components(separatedBy: ".").last
	}
	
	@objc var archiveID: String {
		object(forKey: ArchiveIDKey) as! String
	}
	
	func isLeafNode(matching key: String) -> Bool {
		count == 1
			&& (allKeys.first as? String) == key
			&& (allValues.first as? String) != nil
	}
	
	@discardableResult
	func inflate(into context: NSManagedObjectContext?) ->NSManagedObject? {
		guard let context = context else { return nil }
		
		if entityName != nil {
			let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName!, into: context)
			
			// Track object so that leaf nodes can be later resolved
			newObject.markAsTraversed(with: archiveID)
			
			for (key, value) in self {
				if let keyString = key as? String,
				   let entityName = entityName,
				   keyString != EntityNameKey, keyString != ArchiveIDKey {
					
					let isRelationship = context.isRelationship(for: keyString, in: entityName)
					
					if let dictionary = value as? NSDictionary {
						newObject.inflateToOneRelationship(key: keyString, value: dictionary)
					}
					else if let array = value as? [NSDictionary] {
						newObject.inflateToManyRelationship(key: keyString, value: array)
					}
					else if !isRelationship {
						newObject.inflateManagedAttribute(key: keyString, value: value)
					}
					else {
						// Must be leaf node. Needs to be resolved in a secondary pass
						
						if let destinationArchiveID = value as? String {
							let leafNode = LeafNode(managedObject: newObject,
													archiveID: destinationArchiveID,
													relationshipKey: keyString)
							
							NSManagedObject.append(leafNode: leafNode)
						}
						else {
							assertionFailure("Unexpected leaf node failure!")
						}
					}
				}
			}
			return newObject
		}
		return nil
	}
}

extension NSMutableDictionary {
	override var entityName: String? {
		get {
			(object(forKey: EntityNameKey) as! String).components(separatedBy: ".").last
		}
		set {
			setObject(newValue as Any, forKey: EntityNameKey as NSCopying)
		}
	}
	
	override var archiveID: String {
		get {
			if let archiveID = object(forKey: ArchiveIDKey) as? String {
				return archiveID
			}
			else {
				let archiveID = UUID().uuidString
				setObject(archiveID, forKey: ArchiveIDKey as NSCopying)
				return archiveID
			}
		}
		set {
			setObject(newValue, forKey: ArchiveIDKey as NSCopying)
		}
	}
}


