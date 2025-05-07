//
//  ContentView.swift
//  LibraryMazeRPG
//
//  Created by Kevin Buss & Terrence Gainer on 5/3/25.


import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene: GameScene? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene = scene {
                    SpriteView(scene: scene,
                               transition: .crossFade(withDuration: 0.5),
                               debugOptions: [.showsFPS, .showsNodeCount])
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    let gameScene = GameScene(size: geo.size)
                    gameScene.scaleMode = .resizeFill
                    scene = gameScene
                }
            }
        }
    }
}
