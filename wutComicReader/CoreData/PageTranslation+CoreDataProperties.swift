//
//  PageTranslation+CoreDataProperties.swift
//  
//
//  Created by Daniel on 9/2/22.
//
//

import Foundation
import CoreData


extension PageTranslation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PageTranslation> {
        return NSFetchRequest<PageTranslation>(entityName: "PageTranslation")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var frameWidth: Float
    @NSManaged public var frameHeight: Float
    @NSManaged public var frameX: Float
    @NSManaged public var frameY: Float
    @NSManaged public var ofPageTranslationGroup: PageTranslationGroup?

}
