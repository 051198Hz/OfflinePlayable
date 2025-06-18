//
//  MusicAsset+CoreDataProperties.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/18/25.
//
//

import Foundation
import CoreData


extension MusicAsset {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MusicAsset> {
        return NSFetchRequest<MusicAsset>(entityName: "MusicAsset")
    }

    @NSManaged public var createAt: Date?
    @NSManaged public var fileName: String?
    @NSManaged public var originalName: String?

}

extension MusicAsset : Identifiable {

}
