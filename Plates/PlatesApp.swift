//
//  PlatesApp.swift
//  Plates
//
//  Created by Kyle on 2025/6/17.
//

import SwiftUI

@main
struct PlatesApp: App {
    @StateObject private var viewModel = PlateViewModel()
    
    var body: some Scene {
        WindowGroup {
            PlateListView()
                .environmentObject(viewModel)
                .onAppear {
                    // Trigger migration once when app starts
                    Task {
                        await viewModel.migrateExistingImagesToCloud()
                    }
                }
        }
    }
}
