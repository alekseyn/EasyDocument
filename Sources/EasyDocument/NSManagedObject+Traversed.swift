//
//  NSManagedObject+Traversed.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 3/11/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//

import Foundation
import CoreData

struct LeafNode {
	var managedObject: NSManagedObject
	var archiveID: String
	var relationshipKey: String
	var index: Int?
}

// Keep a list of managed objects to automatically ensure no circular references
// are created when encoding the properties of a managed object. For object graphs
// that are not simple trees, leaf nodes are later resolved using an archiveID.

extension NSManagedObject {
	// Key is represented by archiveID
	static var traversedObjects = [String: NSManagedObject]()
	
	// Used when inflating object graph from a dictionary
	static var leafNodes = [LeafNode]()
	
	static func clearTraversedObjects() {
		traversedObjects = [String: NSManagedObject]()
	}
	
	static func clearLeafNodes() {
		leafNodes = [LeafNode]()
	}
	
	static func append(leafNode: LeafNode) {
		leafNodes.append(leafNode)
	}
	
	var archiveID: String? {
		let objects = NSManagedObject.traversedObjects.filter({ $0.value == self })
		return objects.first?.key
	}
	
	func markAsTraversed(with archiveID: String) {
		NSManagedObject.traversedObjects[archiveID] = self
	}
	
	func hasBeenTraversed() -> Bool {
		return NSManagedObject.traversedObjects.contains(where: { $1 == self })
	}
	
	func archiveIDs(for objects: [NSManagedObject]) -> [String] {
		objects.compactMap { $0.archiveID }
	}
}

