//
//  Event+CoreDataProperties.swift
//  
//
//  Created by Aleksey Novicov on 3/13/21.
//
//

import Foundation
import CoreData
import UIKit

extension Event {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged public var anyBoolean: Bool
    @NSManaged public var anyColor: UIColor?
    @NSManaged public var anyDuration: Double
    @NSManaged public var anyInt16: Int16
    @NSManaged public var anyOptionalData: Data?
    @NSManaged public var anyString: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var detail: Detail?
}
