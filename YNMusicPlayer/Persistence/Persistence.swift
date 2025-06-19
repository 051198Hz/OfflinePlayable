//
//  Persistence.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/11/25.
//

import CoreData
import os.log

class PersistenceController {
    nonisolated(unsafe) static let shared = PersistenceController()

    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext { container.viewContext }
    var logger: Logger? = Logger()
    
    nonisolated(unsafe) static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newMusic = MusicAsset(context: viewContext)
            newMusic.createAt = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()


    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "YNMusicPlayer")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { [logger] (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                logger?.log("Unresolved error \(error.localizedDescription), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func deleteMusic(_ music: MusicAsset) -> Bool {
        viewContext.delete(music)
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            logger?.log("Unresolved error \(nsError.localizedDescription), \(nsError.userInfo)")
            return false
        }
        
        return true
    }
    
    func loadMusic() -> [MusicAsset]? {
        let request: NSFetchRequest<MusicAsset> = MusicAsset.fetchRequest()
        
        do {
            let results = try viewContext.fetch(request)
            return results
        } catch {
            let nsError = error as NSError
            logger?.log("🔴 Fetch 실패: \(nsError.localizedDescription), \(nsError.userInfo)")
            return []
        }
    }
    
    func addMusic(_ asset: Music) -> MusicAsset? {
        let newMusic = MusicAsset(context: viewContext)
        newMusic.createAt = Date()
        newMusic.fileName = asset.fileName
        newMusic.originalName = asset.originalName
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            logger?.log("🔴 Unresolved error \(nsError.localizedDescription), \(nsError.userInfo)")
            return nil
        }
        return newMusic
    }
}
