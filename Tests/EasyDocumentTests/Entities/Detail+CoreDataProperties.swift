//
//  Detail+CoreDataProperties.swift
//  
//
//  Created by Aleksey Novicov on 3/13/21.
//
//

import Foundation
import CoreData


extension Detail {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Detail> {
        return NSFetchRequest<Detail>(entityName: "Detail")
    }

    @NSManaged public var title: String?
    @NSManaged public var event: Event?

}
