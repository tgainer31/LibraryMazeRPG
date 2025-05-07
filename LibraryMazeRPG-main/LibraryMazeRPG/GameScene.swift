//
//  Entities.swift
//  LibraryMazeRPG
//
//  Created by Kevin Buss & Terrence Gainer on 5/3/25.
//



import SpriteKit
import AVFoundation

struct Category {
    static let none:   UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let wall:   UInt32 = 1 << 1
    static let page:   UInt32 = 1 << 2
    static let book:   UInt32 = 1 << 3
}

final class GameScene: SKScene, SKPhysicsContactDelegate {

    private let tile: CGFloat = 64
    private let moveSpeed: CGFloat = 180
    private let dropCooldown: TimeInterval = 0.3
    private let fallChance: CGFloat = 1.5
    private let totalPages = 5
    

    private var player: PlayerNode!
    private let cam = SKCameraNode()
    private let pad = DirectionPad()
    private let hud = SKLabelNode(fontNamed: "Avenir-Heavy")
    private let timerLbl = SKLabelNode(fontNamed: "Avenir-Heavy")
    private let levelLbl = SKLabelNode(fontNamed: "Avenir-Heavy")

    private var pagesFound = 0
    private var bgMusic: AVAudioPlayer?
    private var startTime: TimeInterval = 0
    private var countdown: TimeInterval = 90
    private var level = 1
    private var highScore = UserDefaults.standard.integer(forKey: "HighScore")

    private var mazeSize = (cols: 13, rows: 11)
    private var playerStart: CGPoint = .zero
    private var openTiles: [CGPoint] = []
    private var didGameEnd = false
    
    private var pauseButton: SKLabelNode!

    
    private func showPauseOverlay() {
        let overlay = SKNode()
        overlay.name = "pauseOverlay"
        overlay.zPosition = 1000

        // Semi-transparent background
        let background = SKShapeNode(rectOf: size)
        background.fillColor = .black
        background.alpha = 0.75
        background.position = CGPoint.zero
        overlay.addChild(background)

        // "Game Paused" label
        let pauseLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        pauseLabel.text = "Game Paused"
        pauseLabel.fontSize = 36
        pauseLabel.position = CGPoint(x: 0, y: 40)
        overlay.addChild(pauseLabel)

        // "Resume" button
        let resumeButton = SKLabelNode(fontNamed: "Avenir-Heavy")
        resumeButton.text = "Tap to Resume"
        resumeButton.name = "resumeButton"
        resumeButton.fontSize = 28
        resumeButton.position = CGPoint(x: 0, y: -20)
        overlay.addChild(resumeButton)

        cam.addChild(overlay)
    }

    

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        anchorPoint = .init(x: 0.5, y: 0.5)

        buildWorld()
        spawnPlayer()
        setupCamera()
        setupHUD()
        setupAudio()
        fadeIn()
    }

    private func buildWorld() {
        // Remove all BookNode instances from the scene
        enumerateChildNodes(withName: "//BookNode") { node, _ in
            node.removeFromParent()
        }

        // Proceed with removing all other children and setting up the new level
        removeAllChildren()
        cam.removeAllChildren()
        addChild(cam)

        let bg = SKSpriteNode(texture: SKTexture(imageNamed: "background"))
        bg.size = CGSize(width: tile * CGFloat(mazeSize.cols), height: tile * CGFloat(mazeSize.rows))
        bg.zPosition = -10
        addChild(bg)

        let map = generateMaze(cols: mazeSize.cols, rows: mazeSize.rows)
        openTiles.removeAll()

        for (r, row) in map.enumerated() {
            for (c, ch) in row.enumerated() {
                let p = CGPoint(x: CGFloat(c)*tile - CGFloat(row.count/2)*tile,
                                y: CGFloat(-r)*tile + CGFloat(map.count/2)*tile)
                if ch == "#" {
                    let shelf = BookshelfNode(size: .init(width: tile, height: tile))
                    shelf.position = p
                    addChild(shelf)
                } else {
                    openTiles.append(p)
                }
            }
        }

        for _ in 0..<totalPages {
            if let pos = openTiles.randomElement() {
                let page = PageNode(size: .init(width: tile*0.6, height: tile*0.6))
                page.position = pos
                addChild(page)
            }
        }
    }


    private func generateMaze(cols: Int, rows: Int) -> [[Character]] {
        var maze: [[Character]] = Array(repeating: Array(repeating: "#", count: cols), count: rows)

        func inBounds(x: Int, y: Int) -> Bool {
            x >= 0 && x < cols && y >= 0 && y < rows
        }

        func carve(x: Int, y: Int) {
            maze[y][x] = "."
            let dirs = [(2, 0), (-2, 0), (0, 2), (0, -2)].shuffled()
            for (dx, dy) in dirs {
                let nx = x + dx, ny = y + dy
                if inBounds(x: nx, y: ny), maze[ny][nx] == "#" {
                    maze[y + dy / 2][x + dx / 2] = "."
                    carve(x: nx, y: ny)
                }
            }
        }

        let startX = cols % 2 == 0 ? 1 : 0
        let startY = rows % 2 == 0 ? 1 : 0
        carve(x: startX, y: startY)
        playerStart = CGPoint(x: CGFloat(startX)*tile - CGFloat(cols/2)*tile,
                              y: CGFloat(-startY)*tile + CGFloat(rows/2)*tile)
        return maze
    }
    
    
    private func constrainPlayerToMaze() {
        // Calculate the maze's width and height
        let mazeWidth = CGFloat(mazeSize.cols) * tile
        let mazeHeight = CGFloat(mazeSize.rows) * tile

        // Determine the minimum and maximum X and Y positions
        let minX = -mazeWidth / 2 + player.size.width / 2
        let maxX = mazeWidth / 2 - player.size.width / 2
        let minY = -mazeHeight / 2 + player.size.height / 2
        let maxY = mazeHeight / 2 - player.size.height / 2

        // Create constraints for X and Y positions
        let xRange = SKRange(lowerLimit: minX, upperLimit: maxX)
        let yRange = SKRange(lowerLimit: minY, upperLimit: maxY)

        // Apply the constraints to the player
        player.constraints = [
            SKConstraint.positionX(xRange),
            SKConstraint.positionY(yRange)
        ]
    }


    private func spawnPlayer() {
        player = PlayerNode()
        player.position = playerStart
        addChild(player)
        constrainPlayerToMaze()
    }

    private func setupCamera() {
        camera = cam
        cam.addChild(pad)
        pad.zPosition = 1000
        pad.position = CGPoint(x: -size.width*0.35 + 40, y: -size.height*0.33)
    }

    private func setupHUD() {
        let offset: CGFloat = 100

        hud.fontSize = 26
        hud.zPosition = 1001
        hud.position = CGPoint(x: 0, y: size.height/2 - offset)
        cam.addChild(hud)

        timerLbl.fontSize = 26
        timerLbl.zPosition = 1001
        timerLbl.horizontalAlignmentMode = .left
        timerLbl.position = CGPoint(x: -size.width/2 + 20, y: size.height/2 - offset)
        cam.addChild(timerLbl)

        levelLbl.fontSize = 26
        levelLbl.zPosition = 1001
        levelLbl.horizontalAlignmentMode = .right
        levelLbl.position = CGPoint(x: size.width/2 - 20, y: size.height/2 - offset)
        cam.addChild(levelLbl)

        // Position the pause button directly below the level label
        pauseButton = SKLabelNode(fontNamed: "Avenir-Heavy")
        pauseButton.text = "⏸️"
        pauseButton.fontSize = 32
        pauseButton.zPosition = 1001
        pauseButton.name = "pauseButton"
        pauseButton.horizontalAlignmentMode = .right
        pauseButton.verticalAlignmentMode = .top
        pauseButton.position = CGPoint(x: size.width/2 - 20, y: levelLbl.position.y - levelLbl.frame.height - 10)
        cam.addChild(pauseButton)

        updateHUD()
    }


    private func updateHUD() {
        hud.text = "Pages \(pagesFound) / \(totalPages)"
        levelLbl.text = "Level \(level)"
    }

    private func setupAudio() {
        if let url = Bundle.main.url(forResource: "bgMusic", withExtension: "mp3") {
            bgMusic = try? AVAudioPlayer(contentsOf: url)
            bgMusic?.numberOfLoops = -1
            bgMusic?.volume = 0.4
            bgMusic?.play()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !didGameEnd else { return }

        if startTime == 0 { startTime = currentTime }
        let remaining = countdown - (currentTime - startTime)
        if remaining <= 0 {
            gameOver()
            return
        }
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        timerLbl.text = String(format: "%d:%02d", mins, secs)

        if pad.currentVector == .zero {
            player.stop()
        } else {
            player.move(in: pad.currentVector, speed: moveSpeed)
        }
        cam.position = player.position
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard !didGameEnd else { return }

        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if mask == (Category.player | Category.wall),
           let shelf = (contact.bodyA.node as? BookshelfNode) ?? (contact.bodyB.node as? BookshelfNode) {
            maybeDropBook(from: shelf)
        } else if mask == (Category.player | Category.page),
                  let page = (contact.bodyA.node as? PageNode) ?? (contact.bodyB.node as? PageNode) {
            run(.playSoundFileNamed("collect.wav", waitForCompletion: false))
            page.removeFromParent()
            pagesFound += 1
            updateHUD()
            if pagesFound == totalPages {
                levelUp()
            }
        } else if mask == (Category.player | Category.book) {
            gameOver()
        }
    }

    private func maybeDropBook(from shelf: BookshelfNode) {
        let now = CACurrentMediaTime()
        guard now >= shelf.nextDrop else { return }

        let viableTargetExists = openTiles.contains { point in
            guard frame.contains(point) else { return false }
            if point == shelf.position { return false }

            let nodesAtPoint = nodes(at: point)
            let isBlocked = nodesAtPoint.contains { $0 is BookshelfNode || $0 is BookNode }
            return !isBlocked
        }

        guard viableTargetExists else { return }

        guard CGFloat.random(in: 0...1) < fallChance else { return }
        shelf.nextDrop = now + dropCooldown

        shelf.run(SKAction.sequence([
            .moveBy(x: 5, y: 0, duration: 0.05),
            .moveBy(x: -10, y: 0, duration: 0.05),
            .moveBy(x: 10, y: 0, duration: 0.05),
            .moveBy(x: -5, y: 0, duration: 0.05)
        ]))

        run(.wait(forDuration: 1)) { [weak self] in
            guard let self = self else { return }
            self.dropBookTowardPlayer(from: shelf)
        }
    }


    private func dropBookTowardPlayer(from shelf: BookshelfNode) {
        guard let player = player else { return }

        let searchRadius: CGFloat = tile * 3.0
        let maxAttempts = 5

        let nearbyOpenTiles = openTiles
            .filter { point in
                guard point.distance(to: player.position) <= searchRadius else { return false }
                guard frame.contains(point) else { return false }
                let nodesAtPoint = nodes(at: point)
                let blocked = nodesAtPoint.contains { $0 is BookshelfNode || $0 is BookNode }
                return !blocked
            }
            .sorted { $0.distance(to: player.position) < $1.distance(to: player.position) }

        var target: CGPoint? = nearbyOpenTiles.prefix(maxAttempts).first

        if target == nil {
            target = openTiles
                .filter { point in
                    guard frame.contains(point) else { return false }
                    let nodesAtPoint = nodes(at: point)
                    return !nodesAtPoint.contains { $0 is BookshelfNode || $0 is BookNode }
                }
                .min(by: { $0.distance(to: shelf.position) < $1.distance(to: shelf.position) })
        }

        guard let finalTarget = target else { return }

        let book = BookNode(size: CGSize(width: tile * 0.5, height: tile * 0.7))
        book.position = shelf.position
        addChild(book)

        let dx = finalTarget.x - shelf.position.x
        let dy = finalTarget.y - shelf.position.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0.1 else { return }

        let direction = CGVector(dx: dx / length, dy: dy / length)
        let impulse = CGVector(dx: direction.dx * 6.0, dy: direction.dy * 6.0)
        book.physicsBody?.applyImpulse(impulse)

        book.run(.repeatForever(.rotate(byAngle: .pi, duration: 0.5)))
        book.scheduleRemoval()
        run(.playSoundFileNamed("bookFall.wav", waitForCompletion: false))
    }





    private func levelUp() {
        run(.playSoundFileNamed("levelUp.wav", waitForCompletion: false))
        level += 1

        // Increase maze size by 50%
        mazeSize.cols = Int(CGFloat(mazeSize.cols) * 1.5)
        mazeSize.rows = Int(CGFloat(mazeSize.rows) * 1.5)

        // Increase countdown by 50%
        countdown *= 1.5

        pagesFound = 0
        startTime = 0

        buildWorld()

        if cam.parent == nil {
            addChild(cam)
        }

        camera = cam
        setupCamera()
        setupHUD()
        spawnPlayer()
        updateHUD()
        constrainPlayerToMaze()
    }


    private func gameOver() {
        guard !didGameEnd else { return }
        didGameEnd = true

        pad.isUserInteractionEnabled = false
        player.stop()
        player.removeAllActions()

        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = .black
        overlay.alpha = 0
        overlay.zPosition = 100
        cam.addChild(overlay)
        overlay.run(.fadeAlpha(to: 0.75, duration: 0.3))

        let isHighScore = level > highScore
        if isHighScore {
            highScore = level
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }

        let msg = SKLabelNode(fontNamed: "Avenir-Heavy")
        msg.fontSize = 28
        msg.numberOfLines = 3
        msg.preferredMaxLayoutWidth = size.width * 0.8
        msg.horizontalAlignmentMode = .center
        msg.verticalAlignmentMode = .center
        msg.zPosition = 101
        msg.text = """
        💥 Game Over!
        Reached Level \(level)
        Highest Level Reached: \(highScore)
        """
        msg.position = CGPoint(x: 0, y: size.height / 6)
        cam.addChild(msg)

        let prompt = SKLabelNode(fontNamed: "Avenir-Heavy")
        prompt.fontSize = 24
        prompt.zPosition = 101
        prompt.text = "Tap to restart"
        prompt.position = CGPoint(x: 0, y: -size.height / 4)
        cam.addChild(prompt)

        run(.playSoundFileNamed("hit.wav", waitForCompletion: false))
        isUserInteractionEnabled = true
    }


    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: cam)
        let nodesAtPoint = cam.nodes(at: location)

        for node in nodesAtPoint {
            if node.name == "pauseButton" {
                togglePause()
                return
            } else if node.name == "resumeButton" {
                togglePause()
                return
            }
        }

        // Existing touch handling for restarting the game
        if pad.isUserInteractionEnabled == false {
            bgMusic?.stop()
            let newScene = GameScene(size: size)
            newScene.scaleMode = scaleMode
            view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
        }
    }


    private func togglePause() {
        if isPaused {
            isPaused = false
            pauseButton.text = "⏸️"
            cam.childNode(withName: "pauseOverlay")?.removeFromParent()
        } else {
            isPaused = true
            pauseButton.text = "▶️"
            showPauseOverlay()
        }
    }




    private func fadeIn() {
        cam.alpha = 0
        cam.run(.fadeIn(withDuration: 0.3))
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(x - point.x, y - point.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        return CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}
