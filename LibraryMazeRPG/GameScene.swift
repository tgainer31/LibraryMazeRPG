import SpriteKit
import AVFoundation

// MARK: - Bitmasks
struct Category {
    static let none:   UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let wall:   UInt32 = 1 << 1
    static let page:   UInt32 = 1 << 2
    static let book:   UInt32 = 1 << 3
}

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: tuneables
    private let tile: CGFloat      = 64
    private let moveSpeed: CGFloat = 180
    private let dropCooldown      : TimeInterval = 1      // sec per shelf
    private let fallChance: CGFloat = 0.25
    private let totalPages = 5

    // MARK: nodes
    private var player: PlayerNode!
    private let cam      = SKCameraNode()
    private let pad      = DirectionPad()
    private let hud      = SKLabelNode(fontNamed: "Avenir-Heavy")
    private let timerLbl = SKLabelNode(fontNamed: "Avenir-Heavy")

    private var startTime: TimeInterval = 0
    private var pagesFound = 0 { didSet { hud.text = "Pages \(pagesFound) / \(totalPages)" } }

    private var bgMusic: AVAudioPlayer?

    // MARK: lifecycle -------------------------------------------------
    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        anchorPoint = .init(x: 0.5, y: 0.5)

        buildBackground()
        buildMaze()
        spawnPlayer()
        setupCamera()
        setupHUD()
        setupAudio()

        fadeIn()
        startTime = CACurrentMediaTime()
    }

    // MARK: build world ----------------------------------------------
    private func buildBackground() {
        let tex = SKTexture(imageNamed: "background")
        tex.filteringMode = .nearest
        let bg = SKSpriteNode(texture: tex)
        bg.size = CGSize(width: tile * 13, height: tile * 11) // Matches map dimensions
        bg.zPosition = -10
        addChild(bg)
    }

    private func buildMaze() {
        let map = [
            "#############",
            "#..P....#...#",
            "#.###.#.#.#.#",
            "#.....#.P.#.#",
            "###.#.#####.#",
            "#P..#.....P.#",
            "#.#.#####.#.#",
            "#.#.....#.#.#",
            "#.#####.#.#.#",
            "#.....P.#...#",
            "#############"
        ]
        for (r, row) in map.enumerated() {
            for (c, ch) in row.enumerated() {
                let p = CGPoint(x: CGFloat(c)*tile - CGFloat(row.count/2)*tile,
                                y: CGFloat(-r)*tile + CGFloat(map.count/2)*tile)
                switch ch {
                case "#":
                    let shelf = BookshelfNode(size: .init(width: tile, height: tile))
                    shelf.position = p
                    addChild(shelf)
                case "P":
                    let page  = PageNode(size: .init(width: tile*0.6, height: tile*0.6))
                    page.position = p
                    addChild(page)
                default: break
                }
            }
        }
    }

    private func spawnPlayer() {
        player = PlayerNode()
        // centre-ish start location
        player.position = CGPoint(x: -tile*5, y: tile*4)
        addChild(player)
    }

    private func setupCamera() {
        camera = cam
        addChild(cam)
        cam.addChild(pad)
        pad.position = CGPoint(x: -size.width*0.35 + 40, y: -size.height*0.33)
    }

    private func setupHUD() {
        let topOffset: CGFloat = 100

        hud.fontSize = 26
        hud.horizontalAlignmentMode = .center
        hud.position = CGPoint(x: 0, y: size.height/2 - topOffset)
        cam.addChild(hud)
        hud.text = "Pages 0 / \(totalPages)"

        timerLbl.fontSize = 26
        timerLbl.horizontalAlignmentMode = .left
        timerLbl.position = CGPoint(x: -size.width/2 + 20, y: size.height/2 - topOffset)
        cam.addChild(timerLbl)
    }


    private func setupAudio() {
        if let url = Bundle.main.url(forResource: "bgMusic", withExtension: "mp3") {
            bgMusic = try? AVAudioPlayer(contentsOf: url)
            bgMusic?.numberOfLoops = -1
            bgMusic?.volume = 0.4
            bgMusic?.play()
        }
    }

    // MARK: per-frame -------------------------------------------------
    override func update(_ currentTime: TimeInterval) {
        // timer
        let elapsed = Int(currentTime - startTime)
        let mins = elapsed / 60
        let secs = elapsed % 60
        timerLbl.text = String(format: "%d:%02d", mins, secs)

        // movement
        if pad.currentVector == .zero {
            player.stop()
        } else {
            player.move(in: pad.currentVector, speed: moveSpeed)
        }
        cam.position = player.position
    }

    // MARK: physics contacts -----------------------------------------
    func didBegin(_ contact: SKPhysicsContact) {
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if mask == (Category.player | Category.wall),
           let shelf = (contact.bodyA.node as? BookshelfNode) ??
                       (contact.bodyB.node as? BookshelfNode) {
            maybeDropBook(from: shelf)
        } else if mask == (Category.player | Category.page),
                  let page = (contact.bodyA.node as? PageNode) ??
                             (contact.bodyB.node as? PageNode) {
            collect(page)
        } else if mask == (Category.player | Category.book) {
            gameOver(won: false)
        }
    }

    private func maybeDropBook(from shelf: BookshelfNode) {
        let now = CACurrentMediaTime()
        guard now >= shelf.nextDrop, CGFloat.random(in: 0...1) < fallChance else { return }
        shelf.nextDrop = now + dropCooldown

        // Shake before dropping book
        let shake = SKAction.sequence([
            .moveBy(x: 5, y: 0, duration: 0.05),
            .moveBy(x: -10, y: 0, duration: 0.05),
            .moveBy(x: 10, y: 0, duration: 0.05),
            .moveBy(x: -5, y: 0, duration: 0.05)
        ])
        shelf.run(shake)

        run(.wait(forDuration: 1)) { [weak self] in
            guard let self = self else { return }

            let book = BookNode(size: .init(width: self.tile*0.5, height: self.tile*0.7))
            let dx = player.position.x - shelf.position.x
            let dy = player.position.y - shelf.position.y
            let offset: CGPoint = abs(dx) > abs(dy)
                ? CGPoint(x: dx > 0 ? tile/2 + 10 : -tile/2 - 10, y: 0)
                : CGPoint(x: 0, y: dy > 0 ? tile/2 + 10 : -tile/2 - 10)

            book.position = shelf.position + offset
            self.addChild(book)

            // Add spin animation
            let spin = SKAction.repeatForever(.rotate(byAngle: .pi, duration: 0.5))
            book.run(spin)

            // Apply impulse after short fall
            book.physicsBody?.applyImpulse(.init(dx: .random(in: -20...20), dy: 0))
            book.scheduleRemoval()
            self.run(.playSoundFileNamed("bookFall.wav", waitForCompletion: false))
        }
    }


    private func collect(_ page: PageNode) {
        run(.playSoundFileNamed("collect.wav", waitForCompletion: false))
        page.removeFromParent()
        pagesFound += 1
        if pagesFound == totalPages { gameOver(won: true) }
    }

    // MARK: end states & UI ------------------------------------------
    private func gameOver(won: Bool) {
        pad.isUserInteractionEnabled = false
        player.stop()
        player.removeAllActions()

        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = .black
        overlay.alpha = 0
        overlay.zPosition = 100
        cam.addChild(overlay)
        overlay.run(.fadeAlpha(to: 0.75, duration: 0.3))

        let msg = SKLabelNode(fontNamed: "Avenir-Heavy")
        msg.fontSize = 36
        msg.zPosition = 101
        msg.text = won ? "✨  You found all the pages!  ✨" : "💥  Buried by books!  💥"
        msg.position = CGPoint(x: 0, y: size.height / 4)
        cam.addChild(msg)

        let prompt = SKLabelNode(fontNamed: "Avenir-Heavy")
        prompt.fontSize = 24
        prompt.zPosition = 101
        prompt.text = "Tap anywhere to restart"
        prompt.position = CGPoint(x: 0, y: -size.height / 4)
        cam.addChild(prompt)

        run(.playSoundFileNamed(won ? "win.wav" : "hit.wav", waitForCompletion: false))

        // wait for tap
        isUserInteractionEnabled = true
    }

    // simple tap to restart
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard pad.isUserInteractionEnabled == false else { return } // still playing
        // fade out & reset scene
        bgMusic?.stop()
        let newScene = GameScene(size: size)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }

    private func fadeIn() {
        cam.alpha = 0
        cam.run(.fadeIn(withDuration: 0.3))
    }
}
