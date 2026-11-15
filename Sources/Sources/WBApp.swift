import SwiftUI
import SpriteKit

@main
struct GameApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
        }
    }
}

protocol GameSceneDelegate: AnyObject {
    func didUpdateScore(_ amount: Int)
    func didLoseLife()
}

final class GameController: ObservableObject, GameSceneDelegate {
    @Published var score = 0
    @Published var lives = 3
    @Published var isGameOver = false

    let scene: GameScene

    init() {
        let newScene = GameScene()
        newScene.size = CGSize(width: 414, height: 896)
        newScene.scaleMode = .resizeFill
        self.scene = newScene
        newScene.gameDelegate = self
    }

    func jump() {
        scene.jumpAll()
    }

    func restart() {
        score = 0
        lives = 3
        isGameOver = false
        scene.restartGame()
    }

    func didUpdateScore(_ amount: Int) {
        DispatchQueue.main.async {
            self.score = amount
        }
    }

    func didLoseLife() {
        DispatchQueue.main.async {
            if self.lives > 1 {
                self.lives -= 1
            } else {
                self.lives = 0
                self.isGameOver = true
                self.scene.isPaused = true
            }
        }
    }
}

struct GameView: View {
    @StateObject private var controller = GameController()

    var body: some View {
        ZStack {
            SpriteView(scene: controller.scene)
                .ignoresSafeArea()
                .onTapGesture {
                    if !controller.isGameOver {
                        controller.jump()
                    }
                }

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("СЧЁТ: \(controller.score)")
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundColor(.white)

                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: index < controller.lives ? "heart.fill" : "heart")
                                    .foregroundColor(.red)
                                    .font(.title3)
                            }
                        }
                    }

                    Spacer()

                    Text("ЗАБЕГ ДРУЗЕЙ")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45))
                        .cornerRadius(12)
                }
                .padding()

                Spacer()

                Button(action: {
                    controller.jump()
                }) {
                    Text("ПРЫЖОК ↗")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 44)
                        .background(Color.blue.opacity(0.85))
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                }
                .padding(.bottom, 36)
            }

            if controller.isGameOver {
                Color.black.opacity(0.82)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("ИГРА ОКОНЧЕНА")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundColor(.red)
                    Text("Финальный счёт: \(controller.score)")
                        .font(.title2)
                        .foregroundColor(.white)
                    Button(action: {
                        controller.restart()
                    }) {
                        Text("ИГРАТЬ СНОВА")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color.yellow)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: GameSceneDelegate?

    private var players: [SKSpriteNode] = []
    private var score = 0

    private let playerCategory: UInt32 = 0x1 << 0
    private let platformCategory: UInt32 = 0x1 << 1
    private let obstacleCategory: UInt32 = 0x1 << 2
    private let coinCategory: UInt32 = 0x1 << 3

    override func didMove(to view: SKView) {
        if children.isEmpty {
            setupScene()
        }
    }

    private func setupScene() {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -14.0)
        isPaused = false

        createBackground()
        createGround()
        spawnPlayers()
        startLoop()
    }

    func createBackground() {
        let bg = SKSpriteNode(color: UIColor(red: 0.10, green: 0.11, blue: 0.18, alpha: 1.0), size: self.size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -10
        addChild(bg)

        for _ in 0..<35 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.5))
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: 0...max(size.width, 414)),
                y: CGFloat.random(in: 200...max(size.height, 896))
            )
            star.alpha = CGFloat.random(in: 0.3...0.9)
            star.zPosition = -5
            addChild(star)
        }
    }

    func createGround() {
        let ground = SKSpriteNode(color: UIColor(red: 0.18, green: 0.65, blue: 0.32, alpha: 1.0), size: CGSize(width: 2000, height: 110))
        ground.position = CGPoint(x: 500, y: 55)
        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = platformCategory
        ground.physicsBody?.collisionBitMask = playerCategory
        ground.name = "ground"
        addChild(ground)
    }

    func spawnPlayers() {
        let configs: [(name: String, color: UIColor, xOffset: CGFloat)] = [
            ("friend1", .systemBlue, 75),
            ("friend2", .systemYellow, 135),
            ("friend3", .systemPurple, 195)
        ]

        for (idx, p) in configs.enumerated() {
            let body = SKSpriteNode(color: p.color, size: CGSize(width: 26, height: 42))
            body.position = CGPoint(x: p.xOffset, y: 150)

            let leftLeg = SKSpriteNode(color: .white, size: CGSize(width: 7, height: 14))
            leftLeg.position = CGPoint(x: -6, y: -24)
            let rightLeg = SKSpriteNode(color: .lightGray, size: CGSize(width: 7, height: 14))
            rightLeg.position = CGPoint(x: 6, y: -24)
            body.addChild(leftLeg)
            body.addChild(rightLeg)

            let stepUp = SKAction.moveBy(x: 0, y: 5, duration: 0.14)
            let stepDown = stepUp.reversed()
            let delay = SKAction.wait(forDuration: Double(idx) * 0.05)
            leftLeg.run(SKAction.sequence([delay, SKAction.repeatForever(SKAction.sequence([stepUp, stepDown]))]))
            rightLeg.run(SKAction.sequence([delay, SKAction.repeatForever(SKAction.sequence([stepDown, stepUp]))]))

            let cropNode = SKCropNode()
            let mask = SKShapeNode(circleOfRadius: 20)
            mask.fillColor = .white
            cropNode.maskNode = mask
            cropNode.position = CGPoint(x: 0, y: 38)

            if let img = UIImage(named: p.name) {
                let head = SKSpriteNode(texture: SKTexture(image: img), size: CGSize(width: 40, height: 40))
                cropNode.addChild(head)
            } else {
                let fallback = SKSpriteNode(color: .orange, size: CGSize(width: 40, height: 40))
                cropNode.addChild(fallback)
            }

            let border = SKShapeNode(circleOfRadius: 20)
            border.strokeColor = .white
            border.lineWidth = 2
            border.position = CGPoint(x: 0, y: 38)

            body.addChild(cropNode)
            body.addChild(border)

            body.physicsBody = SKPhysicsBody(rectangleOf: body.size)
            body.physicsBody?.allowsRotation = false
            body.physicsBody?.restitution = 0
            body.physicsBody?.categoryBitMask = playerCategory
            body.physicsBody?.collisionBitMask = platformCategory
            body.physicsBody?.contactTestBitMask = obstacleCategory | coinCategory
            body.name = "player"

            addChild(body)
            players.append(body)
        }
    }

    func jumpAll() {
        for (index, player) in players.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.07) {
                if let velocity = player.physicsBody?.velocity.dy, abs(velocity) < 5.0 {
                    player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 28))
                }
            }
        }
    }

    func restartGame() {
        removeAllActions()
        removeAllChildren()
        players.removeAll()
        score = 0
        setupScene()
    }

    func startLoop() {
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnObstacleAndCoins()
        }
        let wait = SKAction.wait(forDuration: 1.7)
        run(SKAction.repeatForever(SKAction.sequence([spawnAction, wait])), withKey: "gameLoop")
    }

    func spawnObstacleAndCoins() {
        let isObstacle = Bool.random()
        let travelDistance = max(size.width, 414) + 120
        let duration = Double(travelDistance / 240.0)

        if isObstacle {
            let barrier = SKSpriteNode(color: .systemRed, size: CGSize(width: 24, height: 34))
            barrier.position = CGPoint(x: max(size.width, 414) + 40, y: 127)
            barrier.physicsBody = SKPhysicsBody(rectangleOf: barrier.size)
            barrier.physicsBody?.isDynamic = false
            barrier.physicsBody?.categoryBitMask = obstacleCategory
            barrier.physicsBody?.collisionBitMask = 0
            barrier.physicsBody?.contactTestBitMask = playerCategory
            barrier.name = "obstacle"
            addChild(barrier)

            barrier.run(SKAction.sequence([
                SKAction.moveBy(x: -travelDistance, y: 0, duration: duration),
                SKAction.removeFromParent()
            ]))
        } else {
            let coin = SKShapeNode(circleOfRadius: 11)
            coin.fillColor = .systemYellow
            coin.strokeColor = .orange
            coin.lineWidth = 2
            coin.position = CGPoint(x: max(size.width, 414) + 40, y: CGFloat.random(in: 145...235))
            coin.physicsBody = SKPhysicsBody(circleOfRadius: 11)
            coin.physicsBody?.isDynamic = false
            coin.physicsBody?.categoryBitMask = coinCategory
            coin.physicsBody?.collisionBitMask = 0
            coin.physicsBody?.contactTestBitMask = playerCategory
            coin.name = "coin"
            addChild(coin)

            coin.run(SKAction.sequence([
                SKAction.moveBy(x: -travelDistance, y: 0, duration: duration),
                SKAction.removeFromParent()
            ]))
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let firstBody: SKPhysicsBody
        let secondBody: SKPhysicsBody

        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }

        if firstBody.categoryBitMask == playerCategory && secondBody.categoryBitMask == obstacleCategory {
            if let obstacle = secondBody.node, obstacle.parent != nil {
                obstacle.removeFromParent()
                gameDelegate?.didLoseLife()
            }
        } else if firstBody.categoryBitMask == playerCategory && secondBody.categoryBitMask == coinCategory {
            if let coin = secondBody.node, coin.parent != nil {
                coin.removeFromParent()
                score += 10
                gameDelegate?.didUpdateScore(score)
            }
        }
    }
}
