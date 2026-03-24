//
//  FriSpeakApp.swift
//  FriSpeak
//
//  Created by Kaushal Subedi on 3/23/26.
//

import SwiftUI
import CoreData

@main
struct FriSpeakApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
