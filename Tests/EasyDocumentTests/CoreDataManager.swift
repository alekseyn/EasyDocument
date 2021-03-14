//
//  CoreDataManager.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 1/21/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//

import CoreData

public enum StorageType {
	case persistent, inMemory, swiftPackage
}

public final class CoreDataManager {
	public static let dataModelName = "Model"
	public static var shared: CoreDataManager?

    // MARK: - Properties

    private let modelName: String
	private let storageType: StorageType
	private let forceCleanStart: Bool

    // MARK: - Initialization

	@discardableResult
	public init(_ storageType: StorageType = .persistent, forceCleanStart: Bool = false, modelName: String = CoreDataManager.dataModelName) {
        self.modelName = modelName
		self.storageType = storageType
		self.forceCleanStart = forceCleanStart
		
		if Self.shared == nil { Self.shared = self }
    }

	// MARK: - Core Data stack

	lazy var persistentContainer: NSPersistentContainer = {
		let bundle = (storageType == .swiftPackage) ? Bundle.module : Bundle(for: type(of: self))
		
		guard let modelURL = bundle.url(forResource: CoreDataManager.dataModelName, withExtension:"momd") else {
			fatalError("Error loading model from bundle")
		}

		guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
			fatalError("Error initializing mom from: \(modelURL)")
		}

	    let container = NSPersistentContainer(name: CoreDataManager.dataModelName, managedObjectModel: mom)
		
		if storageType == .inMemory || storageType == .swiftPackage {
			let description = NSPersistentStoreDescription()
			description.url = URL(fileURLWithPath: "/dev/null")
			container.persistentStoreDescriptions = [description]
		}
		else {
			if forceCleanStart {
				container.destroyStores(ofType: NSSQLiteStoreType)
			}
		}
		
	    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
	        if let error = error as NSError? {

				// WARNING! Do not include this line in production code.
				container.destroyStores(ofType: NSSQLiteStoreType)
				
	            fatalError("Unresolved error \(error), \(error.userInfo)")
	        }
	    })
		
		container.viewContext.automaticallyMergesChangesFromParent = true

		// Pin the viewContext to the current generation token and
		// set it to keep itself up to date with local changes.
		if storageType == .persistent {
			do {
				try container.viewContext.setQueryGenerationFrom(.current)
			}
			catch {
				fatalError("###\(#function): Failed to pin viewContext to current generation:\(error)")
			}
		}
	    return container
	} ()

	public var managedObjectModel: NSManagedObjectModel {
		persistentContainer.managedObjectModel
	}
	
	public var viewContext: NSManagedObjectContext {
		persistentContainer.viewContext
	}
	
	// MARK: - Core Data contexts

	public func saveViewContext() {
	    if viewContext.hasChanges {
	        do {
	            try viewContext.save()
	        } catch {
	            // Replace this implementation with code to handle the error appropriately.
	            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	            let nserror = error as NSError
	            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
	        }
	    }
	}
	
	public func newPrivateContext(for parent: NSManagedObjectContext) -> NSManagedObjectContext {
		let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		context.parent = parent
		return context
	}
	
	public func performBackgroundChildTask(for parent: NSManagedObjectContext, block: @escaping (NSManagedObjectContext) -> Void) {
		let privateChildContext = newPrivateContext(for: parent)
		
		privateChildContext.perform {
			block(privateChildContext)
		}
	}
	
	public func performBackgroundTask(block: @escaping (NSManagedObjectContext) -> Void) {
		persistentContainer.performBackgroundTask(block)
	}
}

// MARK: - NSPersistentContainer

extension NSPersistentContainer {
	func destroyStores(ofType storeType: String) {
		let descriptions = persistentStoreDescriptions.filter { $0.type == storeType }
		
		for description in descriptions {
			if let url = description.url {
				try? persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: storeType, options: nil)
			}
		}
	}
}

// MARK: - NSManagedObject

// NOTE: Cannot be used with inMemory store.
extension NSManagedObject {
	static var managedObjectModel: NSManagedObjectModel? {
		return CoreDataManager.shared?.managedObjectModel
	}
}


