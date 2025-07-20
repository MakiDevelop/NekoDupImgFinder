//
//  NekoDupImgFinderApp.swift
//  NekoDupImgFinder
//
//  Created by 千葉牧人 on 2025/7/20.
//

import SwiftUI

@main
struct NekoDupImgFinderApp: App {
    @State private var showingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showingSplash {
                    SplashView()
                        .onAppear {
                            // 顯示啟動畫面 2 秒
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showingSplash = false
                                }
                            }
                        }
                } else {
                    ContentView()
                        .navigationTitle("NekoDupImgFinder")
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
