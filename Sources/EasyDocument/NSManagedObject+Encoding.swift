//
//  NSManagedObject+Encoding.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 12/9/18.
//  Copyright © 2018 Yodel Code LLC. All rights reserved.
//

import Foundation
import CoreData

let ArchivePropertyMethodPrefix = "shouldArchive"
let ArchiveDictionaryInfoKey = "shouldArchive"

extension NSManagedObject {

	private func archivableAttributes() -> NSDictionary {
		// Put all of the attributes in a mutable dictionary
		let attributeDescriptions = self.entity.attributesByName
		let copyKeys = Array(attributeDescriptions.keys)
		
		var dictionary = self.dictionaryWithValues(forKeys: copyKeys)
		var keysToRemove: [String] = []
		
		for (key, value) in dictionary {
			
			// Identify key of any attributes that are null, to be removed later
			
			if value as? NSNull != nil {
				keysToRemove.append(key)
			}
			else {
				do {
					try dictionary[key] = encodedManagedValue(value, forKey: key)
				}
				catch ArchiveEncodingError.invalidValue(key) {
					assertionFailure("Failed to archive attribute for " + key)
				}
				catch {
					assertionFailure("Unexpected error: \(error)")
				}
			}
		}
		
		// Remove any attribute that is null, or cannot be transformed
		for key in keysToRemove {
			dictionary.removeValue(forKey: key)
		}
		return dictionary as NSDictionary
	}
	
	private func shouldArchive(relationship: NSRelationshipDescription) -> Bool {
		let userInfo = relationship.userInfo
		
		if let shouldArchiveString = userInfo?[ArchiveDictionaryInfoKey] as? String {
		   return shouldArchiveString.boolValue
		}
		return false
	}
	
	private func doNotArchive(relationship: NSRelationshipDescription) -> Bool {
		let shouldArchiveString = ArchivePropertyMethodPrefix + relationship.name.capitalizeFirstLetter()
		let shouldArchive = NSSelectorFromString(shouldArchiveString)
		
		// Might not work with Swift Core Data objects.
		// https://www.tomdalling.com/blog/cocoa/why-performselector-is-more-dangerous-than-i-thought/

		if self.responds(to: shouldArchive) {
			return (self.perform(shouldArchive) == nil)
		}
		return false
	}
	
	private func archivableRelationships() -> [NSRelationshipDescription] {
		let relationships = self.entity.relationshipsByName
		var relationshipsToRemove: [NSRelationshipDescription] = []
		
		for relationship in relationships {
			if doNotArchive(relationship: relationship.value) {
				relationshipsToRemove.append(relationship.value)
			}
			else if relationship.value.deleteRule != .cascadeDeleteRule {
				
				// Only remove the relationship if it's not explicitly overridden
				if !shouldArchive(relationship: relationship.value) {
					relationshipsToRemove.append(relationship.value)
				}
			}
		}
		return  relationships.values.filter ({ !relationshipsToRemove.contains($0) })
	}
	
	private func normalizedObjectsForRelationship(key: String) -> [NSManagedObject] {
		let items = value(forKey: key)
		let managedObjects: [NSManagedObject]
		
		// Sometimes the relationships may be an NSSet, NSOrderedSet, or even an Array if customized

		if let objects = items as? NSOrderedSet {
			managedObjects = objects.array as! [NSManagedObject]
		}
		else if let objects = items as? NSSet {
			managedObjects = objects.allObjects as! [NSManagedObject]
		}
		else if let objects = items as? Array<Any> {
			managedObjects = objects as! [NSManagedObject]
		}
		else {
			managedObjects = []
		}
		return managedObjects
	}
	

	// Encode to-one relationships as a dictionary, with the key as the destination entity name

	private func encodeToOneRelationship(_ relationship: NSRelationshipDescription, into dictionary: NSMutableDictionary) {
		if let managedObject = self.value(forKey: relationship.name) as? NSManagedObject {
			
			if !managedObject.hasBeenTraversed() {
				
				// Recursively encode
				let toOneDictionary = managedObject.encoded()
				dictionary.setObject(toOneDictionary, forKey: relationship.name as NSCopying)
			}
			else {
				// Create a relationship stub to be resolved during inflation
				if let archiveID = managedObject.archiveID {
					dictionary.setObject(archiveID, forKey: relationship.name as NSCopying)
				}
				else {
					assertionFailure("A traversed NSManagedObject should always have an archiveID!")
				}
			}
		}
	}

	// Encode to-many relationships as an array of dictionaries, with the key as the destination entity name.
	// Treat Set and NSOrderedSet as the same. It will get sorted out when decoded.
	
	private func encodeToManyRelationship(_ relationship: NSRelationshipDescription, into dictionary: NSMutableDictionary) {
		let objectsToArchive = normalizedObjectsForRelationship(key: relationship.name)
												
		if objectsToArchive.count > 0 {
			var dictionaries: [NSDictionary] = []
			
			for managedObject in objectsToArchive {
				if !managedObject.hasBeenTraversed() {
					
					// Recursively encode
					let toManyDictionary = managedObject.encoded()
					dictionaries.append(toManyDictionary)
				}
				else {
					// Create a relationship stub to be resolved during inflation
					if let archiveID = managedObject.archiveID {
						let toManyDictionary = NSMutableDictionary.init(capacity: managedObject.entity.properties.count)
						toManyDictionary.setObject(archiveID, forKey: relationship.name as NSCopying)
						dictionaries.append(toManyDictionary)
					}
					else {
						assertionFailure("A traversed NSManagedObject should always have an archiveID!")
					}
				}
			}
			if dictionaries.count > 0 {
				dictionary.setObject(dictionaries, forKey: relationship.name as NSCopying)
			}
		}
	}
	
	private func encoded() -> NSDictionary {
		let dictionary = NSMutableDictionary(capacity: entity.properties.count)
		
		// Set control parameters (archiveID set automatically)
		dictionary.entityName = entity.name
		
		// Add it to the list to prevent circular references
		markAsTraversed(with: dictionary.archiveID)
		
		// Encode all of the attributes
		let attributes = archivableAttributes()
		dictionary.addEntries(from: attributes as! [AnyHashable : Any])
		
		// Encode the relationships
		let relationships = archivableRelationships()
		for relationship in relationships {
			if relationship.isToMany {
				encodeToManyRelationship(relationship, into: dictionary)
			}
			else {
				encodeToOneRelationship(relationship, into: dictionary)
			}
		}
		return dictionary
	}
	
	public func archiveAsDictionary(fresh: Bool = true) -> NSDictionary? {
		var archiveDictionary: NSDictionary?
		
		// Clear list of any possible old objects
		if (fresh) { NSManagedObject.clearTraversedObjects() }
		
		// Start archiving process, but only if this part of the object graph has not already been visited
		if !hasBeenTraversed() {
			archiveDictionary = encoded()
		}
		
		// Clear list of traversed objects to free up memory
		if fresh { NSManagedObject.clearTraversedObjects() }
		
		return archiveDictionary
	}
}

// MARK: - String

extension String {
	var boolValue: Bool { return (self as NSString).boolValue }
	
	func capitalizeFirstLetter() -> String {
		return prefix(1).uppercased() + self.dropFirst()
	}
}
