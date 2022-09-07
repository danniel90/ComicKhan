//
//  DataService.swift
//  wutComicReader
//
//  Created by Sha Yan on 4/22/20.
//  Copyright © 2020 wutup. All rights reserved.
//

import UIKit
import CoreData

final class DataService {
    
    private let managedContext: NSManagedObjectContext!
    let groupForNewComicsName = ""
    private var groupForNewComics: ComicGroup?
    
    
    init(managedContext: NSManagedObjectContext? = nil) {
        ArrayOfStringsTransformer.register()
        self.managedContext = managedContext ?? DataService.configurePersistentContainer().viewContext
    }
    
    func configureFetchResultController() throws -> NSFetchedResultsController<Comic> {
        let fetchRequest = NSFetchRequest<Comic>(entityName: "Comic")
        
        let basedOnComicGroupName = NSSortDescriptor(key: #keyPath(Comic.ofComicGroup.name), ascending: true)
        let basedOnName = NSSortDescriptor(key: #keyPath(Comic.name), ascending: true)
        
        
        // Important: sectionNameKeyPath that we using to idenifie sections
        // SHOULD be in sortDescriptors to group comics correctly!
        fetchRequest.sortDescriptors = [basedOnComicGroupName, basedOnName]
        
        
        
        let comicFetchResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedContext, sectionNameKeyPath: #keyPath(Comic.ofComicGroup.name), cacheName: nil)
        
        do {
            try comicFetchResultController.performFetch()
        }catch let err {
            throw err
        }
        
        return comicFetchResultController
    }
    
    
    func fetchComicGroups() throws -> [ComicGroup] {
        let request = NSFetchRequest<ComicGroup>(entityName: "ComicGroup")
        do {
            let groups = try managedContext.fetch(request)
            return groups
        }catch let err {
            throw err
        }
    }
    
    func deleteComicFromCoreData(withName name: String) throws {
        
        let deletereq = NSFetchRequest<Comic>(entityName: "Comic")
        let predict = NSPredicate(format: "%K == %@", #keyPath(Comic.name) , name)
        deletereq.predicate = predict
        
        
        guard let comics = try? managedContext.fetch(deletereq) else { return }
        for comic in comics {
            managedContext.delete(comic)
        }
        do {
            try managedContext.save()
        }catch let err{
            throw err
        }
    }
    @discardableResult
    func createANewComicGroup(name: String, comics: [Comic]) throws -> ComicGroup {
        
        let newComicGroup = ComicGroup(context: managedContext)
        newComicGroup.id = UUID()
        newComicGroup.isForNewComics = false
        newComicGroup.name = name
        
        newComicGroup.addToComics(NSOrderedSet(array: comics))
        
        do {
            try managedContext.save()
            return newComicGroup
        }catch let err {
            throw err
        }
        
    }
    
    func createGroupForNewComics() throws {
        
        do {
            let newComicGroup = ComicGroup(context: managedContext)
            newComicGroup.id = UUID()
            newComicGroup.isForNewComics = true
            newComicGroup.name = groupForNewComicsName
            
            try managedContext.save()
        }catch let err {
            throw err
        }
        
    }
    
    func changeGroupOf(comics: [Comic], to group: ComicGroup) throws {
        let set = NSOrderedSet(array: comics)
        group.addToComics(set)
        
        for comic in comics {
            comic.groupName = group.name
        }
        
        do{
            try managedContext.save()
        }catch let err{
            throw err
        }
    }
    
    func deleteEmptyGroups() throws {
        
        let fetchRequest = NSFetchRequest<ComicGroup>(entityName: "ComicGroup")
        
        do{
            let allGroups = try managedContext.fetch(fetchRequest)
            
            let emptyGroups = allGroups.filter({
                $0.comics?.count == 0 && !$0.isForNewComics
            })
            for comic in emptyGroups {
                managedContext.delete(comic)
            }
            
            
            try managedContext.save()
        }catch let err {
            throw err
        }
        
    }
    
    func addNewComic(name: String, imageNames: [String], thumbnailNames: [String], toComicGroupWithName groupName: String?) throws {
        
        //check if we have a groupName or not
        if groupName == nil {
            try addNewComic(name: name, imageNames: imageNames, thumbnailNames: thumbnailNames, to: nil)
            return
        }
        
        //see if a group with groupName already exist
        let request = NSFetchRequest<ComicGroup>(entityName: "ComicGroup")
        let predicate = NSPredicate(format: "%K == %@", #keyPath(ComicGroup.name), groupName!)
        request.predicate = predicate
        
        let matchedGroups = try? managedContext.fetch(request)
        
        //if it is so, add comics to that group
        if let group = matchedGroups?.first {
            try addNewComic(name: name, imageNames: imageNames, thumbnailNames: thumbnailNames, to: group)
            
        }else {
            //otherwise create a new group with groupName and add comics to it
            let group = try? createANewComicGroup(name: groupName!, comics: [])
            try addNewComic(name: name, imageNames: imageNames, thumbnailNames: thumbnailNames, to: group)
        }
    }
    
    func addNewComic(name: String, imageNames: [String], thumbnailNames: [String], to comicGroup: ComicGroup?) throws {
        
        do {
            //FIXME: why fetch?
            try fetchGroupForNewComics()
            let comic = Comic(context: managedContext)
            comic.id = UUID()
            comic.name = name
            comic.lastVisitedPage = 0
            comic.imageNames = NSArray(array: imageNames)
            comic.thumbnailNames = NSArray(array: thumbnailNames)
            if let group = comicGroup {
                group.addToComics(comic)
                comic.groupName = group.name
            }else{
                groupForNewComics?.addToComics(comic)
                comic.groupName = groupForNewComics?.name
            }
            
            try managedContext.save()
        }catch let err {
            throw err
        }
        
    }
    
    private func fetchGroupForNewComics() throws -> ComicGroup? {
        let request = NSFetchRequest<ComicGroup>(entityName: "ComicGroup")
        let predicate = NSPredicate(format: "%K == true", #keyPath(ComicGroup.isForNewComics))
        request.predicate = predicate
        
        do{
            groupForNewComics = try managedContext.fetch(request).first
            return groupForNewComics
        }catch let err {
            throw err
        }
    }
    
    func saveLastPageOf(comic: Comic, lastPage: Int) throws {
        comic.lastVisitedPage = Int16(lastPage)
        do {
            try managedContext.save()
        }catch let err{
            throw err
        }
    }
    
    func saveInputLanguageOf(comic: Comic, inputLanguage: String) throws {
        comic.inputLanguage = inputLanguage
        do {
            try managedContext.save()
        }catch let err{
            throw err
        }
    }
    
    func saveTranslateSettingsOf(comic: Comic, sourcelanguage: String, targetlanguage: String, translateMode: TranslateMode) throws {
        comic.inputLanguage = sourcelanguage
        comic.lastOutputLanguage = targetlanguage
        comic.lastTranslateMode = Int16(translateMode.rawValue)
        do {
            try managedContext.save()
        }catch let err{
            throw err
        }
    }
    
    func comicAlreadyExistedInCoreData(withName comicname: String) -> Bool{
    
        let fetchRequest = NSFetchRequest<Comic>(entityName: "Comic")
        fetchRequest.predicate = NSPredicate(format: "name == %@", comicname)
        
        do{
            let sameComicsName = try managedContext.fetch(fetchRequest)
            return !sameComicsName.isEmpty
        }catch{
            return false
        }
    }
    
    static private func configurePersistentContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "coredata")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }
    
    func addNewPageTranslation(translationGroup: PageTranslationGroup, frame: CGRect, text: String) throws {
        do {
            let translation = PageTranslation(context: managedContext)
//            translation.id = UUID()
            translation.text = text
            translation.frameX = Float(frame.origin.x)
            translation.frameY = Float(frame.origin.y)
            translation.frameHeight = Float(frame.height)
            translation.frameWidth = Float(frame.width)
            translation.ofPageTranslationGroup = translationGroup
            
            try managedContext.save()
        } catch let err {
            throw err
        }
    }
    
    private func fetchTranslationGroup(comic: Comic, on page: Int16) throws -> PageTranslationGroup? {
        //fetch comic translationGroup for langugage and page
        let fetchTranslationGroupRequest = NSFetchRequest<PageTranslationGroup>(entityName: "PageTranslationGroup")
        let namePredicate = NSPredicate(format: "%K == %@", #keyPath(PageTranslationGroup.ofComic.name), comic.name!)
        let languagePredicate = NSPredicate(format: "%K == %@", #keyPath(PageTranslationGroup.language), comic.lastOutputLanguage ?? "")
        let pagePredicate = NSPredicate(format: "%K == %d", #keyPath(PageTranslationGroup.page), page)
        
        fetchTranslationGroupRequest.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                namePredicate,
                languagePredicate,
                pagePredicate
            ]
        )
        
        do {
            let translationGroup = try managedContext.fetch(fetchTranslationGroupRequest)
            return translationGroup.first
        } catch let err {
            throw err
        }
    }
    
    func addNewPageTranslationGroup(comic: Comic, language: String, page: Int16) throws -> PageTranslationGroup {
        do {
            let translationGroup = PageTranslationGroup(context: managedContext)
            translationGroup.id = UUID()
            translationGroup.language = language
            translationGroup.page = page
            translationGroup.ofComic = comic
            
            try managedContext.save()
            
            return translationGroup
        } catch let err {
            throw err
        }
    }
    
    func saveTranslationsToCoreData(comic: Comic?, translationsResult:[(CGRect, String)], with language: String, on page: Int16) throws {
        do {
            guard comic != nil else { return }
            var translationsGroupCoreData = try? fetchTranslationGroup(comic: comic!, on: page)
            if translationsGroupCoreData == nil {
                //addNew
                translationsGroupCoreData = try addNewPageTranslationGroup(comic: comic!, language: language, page: page)
            }
            
            if let translationsCoreData = translationsGroupCoreData?.pageTranslations?.allObjects as? [PageTranslation] {
                for translation in translationsCoreData {
                    managedContext.delete(translation)
                }
                try managedContext.save()
            }
            
            for translationsResult in translationsResult {
                let frame = translationsResult.0
                let text = translationsResult.1
                
                let translation = PageTranslation(context: managedContext)
                translation.id = UUID()
                translation.text = text
                translation.frameX = Float(frame.origin.x)
                translation.frameY = Float(frame.origin.y)
                translation.frameHeight = Float(frame.height)
                translation.frameWidth = Float(frame.width)
                translation.ofPageTranslationGroup = translationsGroupCoreData
                try managedContext.save()
            }
        } catch let err {
            throw err
        }
    }
    
    func fetchPageTranslationsOf(comic: Comic?, on page: Int16) throws -> [PageTranslation] {
        do {
            let translationGroup = try fetchTranslationGroup(comic: comic!, on: page)
            guard let translations = translationGroup?.pageTranslations?.allObjects as? [PageTranslation] else { return [] }
            return translations
        } catch let err {
            throw err
        }
    }
    
    //https://www.cocoanetics.com/2017/04/group-by-count-and-sum-in-coredata/
    func fetchPageTranslationsTotalsOf(comic: Comic?) throws -> [(String, Int)] {
        let keypathExp =  NSExpression(forKeyPath: #keyPath(PageTranslationGroup.page))
        
        let countDesc = NSExpressionDescription()
        countDesc.expression = NSExpression(forFunction: "count:", arguments: [keypathExp])
        countDesc.name = "count"
        countDesc.expressionResultType = .integer64AttributeType

        let request = NSFetchRequest<NSDictionary>(entityName: "PageTranslationGroup")
        request.propertiesToFetch = [#keyPath(PageTranslationGroup.language), countDesc]
        request.propertiesToGroupBy = [#keyPath(PageTranslationGroup.language)]
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(PageTranslationGroup.ofComic.name), comic!.name!)
        request.returnsObjectsAsFaults = false
        request.resultType = .dictionaryResultType
        
        do {
            let fetchResult = try managedContext.fetch(request)
            return fetchResult.compactMap { item in
                (
                    item.value(forKey: "language") as! String,
                    item.value(forKey: "count") as! Int
                )
            }
        } catch let err {
            throw err
        }
    }
    
    private func fetchTranslationGroup(comic: Comic, with language: String) throws -> [PageTranslationGroup?] {
        //fetch comic translationGroup for langugage and page
        let fetchTranslationGroupRequest = NSFetchRequest<PageTranslationGroup>(entityName: "PageTranslationGroup")
        let namePredicate = NSPredicate(format: "%K == %@", #keyPath(PageTranslationGroup.ofComic.name), comic.name!)
        let languagePredicate = NSPredicate(format: "%K == %@", #keyPath(PageTranslationGroup.language), language)
        
        
        let compoundPredicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                namePredicate,
                languagePredicate,
            ]
        )
        let sortDescriptor = NSSortDescriptor(key: #keyPath(PageTranslationGroup.language), ascending: true)
        
        fetchTranslationGroupRequest.predicate = compoundPredicate
        fetchTranslationGroupRequest.sortDescriptors = [sortDescriptor]
        
        do {
            let translationGroups = try managedContext.fetch(fetchTranslationGroupRequest)
            return translationGroups
        } catch let err {
            throw err
        }
    }
    
    func deletePageTranslationsFromCoreData(comic: Comic, with language: String) throws {
        do {
            let translationsGroupCoreData = try? fetchTranslationGroup(comic: comic, with: language)
            
            if let translationsGroupCoreData = translationsGroupCoreData as? [PageTranslationGroup] {
                for translationGroup in translationsGroupCoreData {
                    managedContext.delete(translationGroup)
                }
                try managedContext.save()
            }
        } catch let err {
            throw err
        }
    }
    
}


