//
//  PageTranslationGroup+CoreDataProperties.swift
//  
//
//  Created by Daniel on 9/2/22.
//
//

import Foundation
import CoreData


extension PageTranslationGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PageTranslationGroup> {
        return NSFetchRequest<PageTranslationGroup>(entityName: "PageTranslationGroup")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var language: String?
    @NSManaged public var page: Int16
    @NSManaged public var pageTranslations: NSSet?
    @NSManaged public var ofComic: Comic?

}

// MARK: Generated accessors for pageTranslations
extension PageTranslationGroup {

    @objc(addPageTranslationsObject:)
    @NSManaged public func addToPageTranslations(_ value: PageTranslation)

    @objc(removePageTranslationsObject:)
    @NSManaged public func removeFromPageTranslations(_ value: PageTranslation)

    @objc(addPageTranslations:)
    @NSManaged public func addToPageTranslations(_ values: NSSet)

    @objc(removePageTranslations:)
    @NSManaged public func removeFromPageTranslations(_ values: NSSet)

}
