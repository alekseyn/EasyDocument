//
//  CustomEasyDocument.swift
//  EasyDocument
//
//  Created by Aleksey Novicov on 1/21/21.
//  Copyright © 2021 Aleksey Novicov. All rights reserved.
//
// An example of how to use EasyDocument. See EasyDocumentTests for further detail.

import Foundation
import EasyDocument
import UIKit
import CoreData

// Your application should support opening files, and should declare whether it supports
// opening them in place. You can add an LSSupportsOpeningDocumentsInPlace entry or an
// UISupportsDocumentBrowser entry to your Info.plist to declare support.

let OriginalFormatVersion = "1.0"
let CurrentFormatVersion = "1.0"
let OriginalCopyrightMessage = "© 2021 Your Company Name"
let CurrentCopyrightMessage = "© 2021 Your Company Name"

class CustomEasyDocument: EasyDocument {

	override func postProcess(managedObjects: [NSManagedObject], in context: NSManagedObjectContext) {
		// Sometimes new objects from an EasyDocument that have been ingested
		// and inserted in the managed object context need attributes to be updated,
		// or relationships to be set.
	}
	
	// MARK: - EasyDocumentTemplate
	
	override var template: NSMutableDictionary {
		get {
			let template = NSMutableDictionary.init(capacity: 4)
			
			template["version"] 	= CurrentFormatVersion
			template["namespace"] 	= "com.yourcompanyname.app"
			template["token"] 		= UUID().uuidString
			template["copyright"] 	= CurrentCopyrightMessage
			
			return template
		}
	}
	
	override var templateObjectsKey: String {
		get { return "objects" }
	}
	
	override func isValid(template dictionary: NSDictionary) -> Bool {
		guard 	let version = dictionary["version"] as? String,
			let copyright = dictionary["copyright"] as? String else { return false }
		
		let firstFormat = (version == OriginalFormatVersion) && (copyright == OriginalCopyrightMessage)
		let currentFormat = (version == CurrentFormatVersion) && (copyright == CurrentCopyrightMessage)
		let isValid = firstFormat || currentFormat
		
		if !isValid {
			showUnsupportedAlertMessage()
		}
		return isValid
	}

	func showUnsupportedAlertMessage() {
		// Custom implementation goes here
	}
}
