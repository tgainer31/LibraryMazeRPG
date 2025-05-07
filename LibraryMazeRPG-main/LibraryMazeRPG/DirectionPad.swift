// DirectionPad.swift
// LibraryMazeRPG
//
// Created by Kevin Buss & Terrence Gainer on 5/3/25.
//

import SpriteKit

final class DirectionPad: SKNode {
    struct Arrow {
        let node: SKSpriteNode
        let vector: CGVector
    }
    private var arrows: [Arrow] = []
    var currentVector = CGVector.zero

    override init() {
        super.init()
        isUserInteractionEnabled = true
        alpha = 0.85
        let size: CGFloat = 64

        func arrowImage(name: String) -> SKTexture {
            if let image = UIImage(named: "arrow_\(name)") {
                return SKTexture(image: image)
            } else {
                let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
                    let cg = ctx.cgContext
                    cg.setStrokeColor(UIColor.red.cgColor)
                    cg.setLineWidth(8)
                    let center = CGPoint(x: size/2, y: size/2)
                    let arrowLength = size * 0.3

                    switch name {
                    case "up":
                        cg.move(to: CGPoint(x: center.x, y: center.y + arrowLength))
                        cg.addLine(to: CGPoint(x: center.x, y: center.y - arrowLength))
                    case "down":
                        cg.move(to: CGPoint(x: center.x, y: center.y - arrowLength))
                        cg.addLine(to: CGPoint(x: center.x, y: center.y + arrowLength))
                    case "left":
                        cg.move(to: CGPoint(x: center.x - arrowLength, y: center.y))
                        cg.addLine(to: CGPoint(x: center.x + arrowLength, y: center.y))
                    case "right":
                        cg.move(to: CGPoint(x: center.x + arrowLength, y: center.y))
                        cg.addLine(to: CGPoint(x: center.x - arrowLength, y: center.y))
                    default: break
                    }
                    cg.strokePath()
                }
                return SKTexture(image: image)
            }
        }

        func addArrow(name: String, dx: CGFloat, dy: CGFloat, pos: CGPoint) {
            let n = SKSpriteNode(texture: arrowImage(name: name))
            n.name = name
            n.size = .init(width: size, height: size)
            n.position = pos
            n.zPosition = 1000
            addChild(n)
            arrows.append(.init(node: n, vector: .init(dx: dx, dy: dy)))
        }

        addArrow(name: "up",    dx: 0, dy: 1,  pos: CGPoint(x: 0, y: size))
        addArrow(name: "down",  dx: 0, dy: -1, pos: CGPoint(x: 0, y: -size))
        addArrow(name: "left",  dx: -1,dy: 0,  pos: CGPoint(x: -size, y: 0))
        addArrow(name: "right", dx: 1, dy: 0,  pos: CGPoint(x: size, y: 0))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        update(for: touches, pressed: true)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        update(for: touches, pressed: true)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        update(for: touches, pressed: false)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        update(for: touches, pressed: false)
    }

    private func update(for touches: Set<UITouch>, pressed: Bool) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        for a in arrows {
            if a.node.contains(p) {
                a.node.alpha = pressed ? 0.5 : 1
                currentVector = pressed ? a.vector : .zero
                return
            }
        }
        if !pressed { currentVector = .zero }
    }
}
