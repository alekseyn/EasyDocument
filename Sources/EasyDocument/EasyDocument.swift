//
//  EasyDocument.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 12/15/18.
//  Copyright © 2018 Yodel Code LLC. All rights reserved.
//
// To use EasyDocument, create your own custom class by subclassing EasyDocument.
// See CustomEasyDocument in EasyDocumentTests for an example.

import Foundation
import CoreData

public typealias ArchiveProgressHandler = (Int) -> Swift.Void

// MARK: EasyDocumentTemplate

public protocol EasyDocumentTemplate {
	var template: NSMutableDictionary { get }
	var templateObjectsKey: String { get }
	
	func isValid(template dictionary: NSDictionary) -> Bool
}

// MARK: - EasyDocument Protocol

public protocol EasyDocumentProtocol: EasyDocumentTemplate {
	var compressionAlorithm: NSData.CompressionAlgorithm? { get }
	
	func archiveManagedObjects(_ managedObjects: [NSManagedObject], to url: URL, overwrite: Bool) throws
	@discardableResult func insertedManagedObjects(from url: URL, into managedObjectContext: NSManagedObjectContext) -> [NSManagedObject]?

	func createArchive(of managedObjects: [NSManagedObject], inChunksOf chunkSize: Int, savedTo directory: String, in container: String?, progress: ArchiveProgressHandler?) throws
	func saveFromArchive(directory: String, in container: String?, into managedObjectContext: NSManagedObjectContext, progress: ArchiveProgressHandler?)
	func clearArchive(directory: String, in container: String?)
	func hasArchive(using directory: String, in container: String?) -> Bool
}

// MARK: - EasyDocument Protocol Extension

public extension EasyDocumentProtocol {
	static var defaultDirectoryName: String { "EasyDocument" }
	static var defaultFilename: String { "Chunk.plist" }

	/// Fetch root objects to archive by entity name

	func objects(withEntityName entityName: String, in context: NSManagedObjectContext) -> [NSManagedObject]? {
		let fetchRequest =  NSFetchRequest<NSFetchRequestResult>(entityName: entityName)

		do {
			if let objects = try context.fetch(fetchRequest) as? [NSManagedObject] {
				return objects
			}
		}
		catch {
			print("Error fetching objects by entity name: \(error)")
		}
		return nil
	}
	
	/// Archive and save to disk in chunks

	func createArchive(of managedObjects: [NSManagedObject], inChunksOf chunkSize: Int = 0, savedTo directory: String = Self.defaultDirectoryName, in container: String? = nil, progress: ArchiveProgressHandler? = nil) throws {
		let cachesFile = try CachesFile(directoryName: directory, filename: Self.defaultFilename, containerName: container)
		try cachesFile.cleanDirectory()
		
		if let url = cachesFile.fileURL  {
			if chunkSize <= 0 {
				try self.archiveManagedObjects(managedObjects, to: url, overwrite: true)
                progress?(managedObjects.count)
			}
			else {
				// Must duplicate array before chunking it
				let duplicateObjects = managedObjects
				let chunks = duplicateObjects.chunked(into: chunkSize)
				
				for (index, chunk) in chunks.enumerated() {
					try self.archiveManagedObjects(chunk, to: url, overwrite: false)
					
					let numObjects = min(managedObjects.count, (index + 1) * chunkSize)
					progress?(numObjects)
				}
			}
		}
	}
	
	/// Check for existing archive
	
	func hasArchive(using directory: String = Self.defaultDirectoryName, in container: String? = nil) -> Bool {
		do {
			let cachesFile = try CachesFile(directoryName: directory, filename: Self.defaultFilename, containerName: container)
			let fileURLs = try cachesFile.existingFiles()
			return fileURLs.count > 0
		}
		catch {
			print("EasyDocument existing archive error: \(error.localizedDescription)")
		}
		return false
	}
	
	/// Restore from archive
	
	func saveFromArchive(directory: String = Self.defaultDirectoryName, in container: String? = nil, into managedObjectContext: NSManagedObjectContext, progress: ArchiveProgressHandler? = nil) {
		do {
			let cachesFile = try CachesFile(directoryName: directory, filename: Self.defaultFilename, containerName: container)
			defer {
				try? cachesFile.deleteDirectory()
			}
			
			let fileURLs = try cachesFile.existingFiles()
			var count = 0
			
			for fileURL in fileURLs {
				autoreleasepool {
					if let importObjects = self.insertedManagedObjects(from: fileURL, into: managedObjectContext) {
						do {
							// If permanent IDs are not obtained, diffable data source may not function as expected
							try managedObjectContext.obtainPermanentIDs(for: importObjects)
							try managedObjectContext.save()
						}
						catch {
							print(error.localizedDescription)
						}
						
						// Reclaim memory
						managedObjectContext.reset()
						
						count += importObjects.count
						progress?(count)
					}
				}
			}
		}
		catch {
			print("EasyDocument save from archive error: \(error.localizedDescription)")
		}
	}
	
	/// Clear archive
	
	func clearArchive(directory: String = Self.defaultDirectoryName, in container: String? = nil) {
		do {
			let cachesFile = try CachesFile(directoryName: directory, filename: Self.defaultFilename, containerName: container)
			try cachesFile.deleteDirectory()
		}
		catch {
			print("EasyDocument delete archive error: \(error.localizedDescription)")
		}
	}

	func archiveManagedObjects(_ managedObjects: [NSManagedObject], to url: URL, overwrite: Bool = true) throws {
		try autoreleasepool {
			try save(archive: archive(managedObjects), to: url, overwrite: overwrite)
		}
	}
	
	func insertedManagedObjects(from url: URL, into managedObjectContext: NSManagedObjectContext) -> [NSManagedObject]? {
		var insertedObjects: [NSManagedObject]?
		
		autoreleasepool {
			if let plist = plist(from: url) {
				if isValid(template: plist) {
					if let archivedObjects = plist[templateObjectsKey] as? [NSDictionary] {
						insertedObjects = managedObjectContext.insertedObjects(from: archivedObjects)
					}
				}
			}
		}
		return insertedObjects
	}
	
	private func plist(from url: URL) -> NSDictionary? {
		if let data = FileManager.default.contents(atPath: url.path) {
			do {
				var dataToDeserialize = data
				
				if compressionAlorithm != nil {
					let decompressedData = try (data as NSData).decompressed(using: compressionAlorithm!)
					dataToDeserialize = decompressedData as Data
				}
				let plist = try PropertyListSerialization.propertyList(from: dataToDeserialize, options: [], format: nil)
				
				if let dictionary = plist as? NSDictionary {
					return dictionary
				}
			}
			catch { // error condition
				print("Error reading plist: \(error)")
			}
		}
		return nil
	}
	
	private func archive(_ managedObjects: [NSManagedObject]) -> NSDictionary {
		var archivedObjects: [NSDictionary] = []
		
		for managedObject in managedObjects {
			if let archivedObject = managedObject.dictionaryArchive() {
				archivedObjects.append(archivedObject)
			}
		}
		
		// Create a copy of the template
		let archive = template
		archive[templateObjectsKey] = archivedObjects
		
		return archive
	}
	
	private func save(archive: NSDictionary, to url: URL, overwrite: Bool) throws {
		var counter = 0
		var successful = false
		
		let filenameWithSuffix = url.lastPathComponent
		let directory = url.deletingLastPathComponent()
		let suffix = url.pathExtension
		let filename = (suffix == "") ? filenameWithSuffix : filenameWithSuffix.components(separatedBy: "." + suffix).first!
		
		repeat {
			let fullFilename = ((counter > 0) ? filename + " \(counter)" : filename) + "." + suffix
			let updatedURL = directory.appendingPathComponent(fullFilename)
			
			do {
				try autoreleasepool {
					let plist = try PropertyListSerialization.data(fromPropertyList: archive, format: .binary, options: 0)
					
					do {
						var dataToSave = plist
						
						if compressionAlorithm != nil {
							let compressedData = try (plist as NSData).compressed(using: compressionAlorithm!)
							dataToSave = compressedData as Data
						}
						
						// Overwrite the existing file if it exists
						if overwrite {
							try dataToSave.write(to: updatedURL, options: Data.WritingOptions.atomic)
						}
						else {
							try dataToSave.write(to: updatedURL, options: Data.WritingOptions.withoutOverwriting)
						}
						successful = true
					} catch {
						print(error.localizedDescription)
					}
				}
			}
			catch CocoaError.fileWriteFileExists {
				counter += 1
			}
			catch {
				print(error)
			}
		} while !successful
	}
}

// MARK: - EasyDocument Abstract Class

open class EasyDocument: NSObject, EasyDocumentProtocol {
	
	var url: URL?
	var documentObjects: [NSManagedObject]?
	public var compressionAlorithm: NSData.CompressionAlgorithm?
	
	@discardableResult
	public init(fromURL url: URL, into context: NSManagedObjectContext, compressionAlgorithm: NSData.CompressionAlgorithm? = nil) {
		self.compressionAlorithm = compressionAlgorithm
		self.url = url
		super.init()
		
		// Ingest managedObjects from an EasyDocument with a file URL
		if let documentObjects = insertedManagedObjects(from: url, into: context) {
			postProcess(managedObjects: documentObjects, in: context)
		}
	}
	
	@discardableResult
	public init(managedObjects: [NSManagedObject], toURL url: URL, compressionAlgorithm: NSData.CompressionAlgorithm? = nil) throws {
		self.compressionAlorithm = compressionAlgorithm
		self.url = url
		super.init()
		
		// Archive and save to disk as an EasyDocument
		try archiveManagedObjects(managedObjects, to: url)
	}
	
	// Data for managed objects that were saved in an EasyDocument
	var data: Data? {
		if let path = url?.path {
			return FileManager.default.contents(atPath: path)
		}
		return nil
	}
	
	open func postProcess(managedObjects: [NSManagedObject], in context: NSManagedObjectContext) {
		do {
			// If permanent IDs are not obtained, diffable data source may not function as expected
			try context.obtainPermanentIDs(for: managedObjects)
		}
		catch {
			print(error.localizedDescription)
		}

		// Override for custom modification. Calling super.postProcess() is recommended if using diffable data sources.
	}

	// MARK: - EasyDocumentTemplate Abstraction
	
	open var template: NSMutableDictionary {
		fatalError("template must be overridden in subclass")
	}
	
	open var templateObjectsKey: String {
		fatalError("templateObjectsKey must be overridden in subclass")
	}
	
	open func isValid(template dictionary: NSDictionary) -> Bool {
		fatalError("isValid() must be overridden in subclass")
	}
}

// MARK: - Array

private extension Array {
	func chunked(into size: Int) -> [[Element]] {
		return stride(from: 0, to: count, by: size).map {
			Array(self[$0 ..< Swift.min($0 + size, count)])
		}
	}
}
