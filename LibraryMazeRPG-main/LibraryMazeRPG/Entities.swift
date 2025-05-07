//
//  Entities.swift
//  LibraryMazeRPG
//
//  Created by Kevin Buss & Terrence Gainer on 5/3/25.

import SpriteKit

// MARK: - Direction enum
enum Dir { case up, down, left, right }

// MARK: - Player
final class PlayerNode: SKSpriteNode {

    private let texUp    = SKTexture(imageNamed: "player_up")
    private let texDown  = SKTexture(imageNamed: "player_down")
    private let texLeft  = SKTexture(imageNamed: "player_left")
    private let texRight = SKTexture(imageNamed: "player_right")
    private var facing: Dir = .down

    init() {
        super.init(texture: texDown, color: .clear, size: texDown.size())
        zPosition = 10
        physicsBody = SKPhysicsBody(circleOfRadius: size.width * 0.4)
        physicsBody?.allowsRotation = false
        physicsBody?.linearDamping  = 3
        physicsBody?.categoryBitMask    = Category.player
        physicsBody?.collisionBitMask   = Category.wall
        physicsBody?.contactTestBitMask = Category.wall | Category.page | Category.book
    }
    required init?(coder: NSCoder) { fatalError() }

    func move(in dir: CGVector, speed s: CGFloat) {
        physicsBody?.velocity = dir.normalized * s
        updateTexture(for: dir)
    }
    func stop() { physicsBody?.velocity = .zero }

    private func updateTexture(for v: CGVector) {
        guard abs(v.dx) + abs(v.dy) > 0.1 else { return }
        let newFacing: Dir =
            abs(v.dx) > abs(v.dy) ? (v.dx > 0 ? .right : .left)
                                  : (v.dy > 0 ? .up    : .down)
        guard newFacing != facing else { return }
        facing = newFacing
        texture = switch facing {
            case .up: texUp; case .down: texDown
            case .left: texLeft; case .right: texRight
        }
    }
}

// MARK: - Bookshelf (wall)
final class BookshelfNode: SKSpriteNode {
    var nextDrop: TimeInterval = 0
    init(size: CGSize) {
        super.init(texture: SKTexture(imageNamed: "bookshelf"), color: .brown, size: size)
        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.isDynamic      = false
        physicsBody?.categoryBitMask = Category.wall
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Collectible page
final class PageNode: SKSpriteNode {
    init(size: CGSize) {
        super.init(texture: SKTexture(imageNamed: "page"), color: .yellow, size: size)
        zPosition = 5
        physicsBody = SKPhysicsBody(circleOfRadius: size.width/2)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask    = Category.page
        physicsBody?.contactTestBitMask = Category.player
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Falling book
final class BookNode: SKSpriteNode {
    init(size: CGSize) {
        super.init(texture: SKTexture(imageNamed: "book"), color: .red, size: size)
        zPosition = 8
        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = true
        physicsBody?.categoryBitMask = Category.book
        physicsBody?.contactTestBitMask = Category.player
        physicsBody?.collisionBitMask = Category.wall
        physicsBody?.restitution = 0.2
        physicsBody?.friction = 0.5
        physicsBody?.linearDamping = 0.8
        physicsBody?.angularDamping = 0.8
        physicsBody?.usesPreciseCollisionDetection = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func scheduleRemoval() {
        run(.sequence([
            .wait(forDuration: 5),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}


// MARK: - Math
extension CGVector {
    var normalized: CGVector {
        let m = sqrt(dx*dx + dy*dy)
        return m == 0 ? .zero : CGVector(dx: dx/m, dy: dy/m)
    }
    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }
}
extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }
}
