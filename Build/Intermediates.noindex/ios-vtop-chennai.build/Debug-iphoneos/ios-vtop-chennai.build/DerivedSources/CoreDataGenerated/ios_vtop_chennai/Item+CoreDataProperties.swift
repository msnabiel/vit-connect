//
//  Item+CoreDataProperties.swift
//  
//
//  Created by Syed Nabiel Hasaan M on 05/08/26.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ItemCoreDataPropertiesSet = NSSet

extension Item {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged nonisolated public var timestamp: Date?

}

extension Item : Identifiable {

}
