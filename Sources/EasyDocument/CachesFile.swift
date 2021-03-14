//
//  CachesFile.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 6/25/19.
//  Copyright © 2019 Aleksey Novicov. All rights reserved.
//

import Foundation

/// Adapted from: https://oleb.net/blog/2018/03/temp-file-helper/

public struct CachesFile {
	public let directoryURL: URL?
	public let fileURL: URL?
	
	/// Creates a directory with a unique name (if none specified) in Caches directory
	/// and initializes the receiver with a `fileURL` representing a file named `filename` in that
	/// directory.
	
	public init(directoryName: String? = nil, filename: String, containerName: String? = nil) throws {
		let directory 		= try FileManager.default.urlForUniqueCachesDirectory(preferredName: directoryName, in: containerName)
		self.directoryURL 	= directory
		self.fileURL 		= (directory != nil) ? directory!.appendingPathComponent(filename) : nil
	}
	
	public func existingFiles() throws -> [URL] {
		if let url = directoryURL {
			let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
			return fileURLs
		}
		return []
	}
	
	public func cleanDirectory() throws {
		let fileManager = FileManager.default
		
		if let url = directoryURL {
			let fileURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
			for fileURL in fileURLs {
				try fileManager.removeItem(at: fileURL)
			}
		}
	}
	
	public func deleteDirectory() throws {
		if let url = directoryURL {
			try FileManager.default.removeItem(at: url)
		}
	}
}

extension FileManager {
	var cachesDirectory: URL? {
		get {
			return self.urls(for: .cachesDirectory, in: .userDomainMask).first
		}
	}
	
	/// Creates a temporary directory with a unique name and returns its URL.
	///
	/// - Returns: A tuple of the directory's URL and a delete function.
	///   Call the function to delete the directory after you're done with it.
	///
	/// - Note: You should not rely on the existence of the temporary directory
	///   after the app is exited.
	
	func urlForUniqueCachesDirectory(preferredName: String? = nil, in container: String?) throws -> URL? {
		let basename = preferredName ?? UUID().uuidString
		var createdSubdirectory: URL?
		
		var parentDirectory = cachesDirectory
		
		if container != nil {
			let containerDirectory = containerURL(forSecurityApplicationGroupIdentifier: container!)
			parentDirectory = containerDirectory?.appendingPathComponent("Library").appendingPathComponent("Caches")
		}
		
		if let subdirectory = parentDirectory?.appendingPathComponent(basename, isDirectory: true) {
			do {
				try createDirectory(at: subdirectory, withIntermediateDirectories: false)
			}
			catch CocoaError.fileWriteFileExists {
				// Directory already exists, nothing to do
			}
			createdSubdirectory = subdirectory
		}
		return createdSubdirectory
	}
}
