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

// Структура персонажа
struct Friend {
    let name: String
    let imageName: String
    let color: Color
}

struct GameView: View {
    @State private var score = 0
    @State private var lives = 3
    @State private var isGameOver = false
    @State private var isGameStarted = false
    
    // Создаем игровую сцену SpriteKit
    var scene: GameScene {
        let scene = GameScene()
        scene.size = CGSize(width: 414, height: 896)
        scene.scaleMode = .resizeFill
        scene.gameDelegate = self
        return scene
    }
    
    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            
            // Интерфейс игры поверх SpriteKit
            VStack {
                // Хедер
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("СЧЁТ: \(score)")
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Image(systemName: index < lives ? "heart.fill" : "heart")
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
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(12)
                }
                .padding()
                
                Spacer()
                
                // Кнопки управления (только для примера, управление тапом)
                HStack {
                    Spacer()
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("JumpAction"), object: nil)
                    }) {
                        Text("ПРЫЖОК ↗")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 40)
                            .background(Color.blue.opacity(0.85))
                            .clipShape(Capsule())
                            .shadow(radius: 5)
                    }
                    .padding(.bottom, 40)
                    .padding(.trailing, 20)
                }
            }
            
            if isGameOver {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("ИГРА ОКОНЧЕНА 👾")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundColor(.red)
                    Text("Финальный счёт: \(score)")
                        .font(.title2)
                        .foregroundColor(.white)
                    Button(action: {
                        isGameOver = false
                        score = 0
                        lives = 3
                        NotificationCenter.default.post(name: NSNotification.Name("RestartGame"), object: nil)
                    }) {
                        Text("ИГРАТЬ СНОВА")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// Делегат для связи SpriteKit сцены с UI SwiftUI
extension GameView: GameSceneDelegate {
    func didUpdateScore(_ amount: Int) {
        self.score = amount
    }
    func didLoseLife() {
        if self.lives > 1 {
            self.lives -= 1
        } else {
            self.lives = 0
            self.isGameOver = true
        }
    }
}

protocol GameSceneDelegate: AnyObject {
    func didUpdateScore(_ amount: Int)
    func didLoseLife()
}

// Сама игровая сцена
class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: GameSceneDelegate?
    
    private var players: [SKSpriteNode] = []
    private var platforms: [SKSpriteNode] = []
    private var score = 0
    
    private let playerCategory: UInt32 = 0x1 << 0
    private let platformCategory: UInt32 = 0x1 << 1
    private let obstacleCategory: UInt32 = 0x1 << 2
    private let coinCategory: UInt32 = 0x1 << 3
    
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        
        createBackground()
        createGround()
        spawnPlayers()
        
        // Подписка на прыжок
        NotificationCenter.default.addObserver(self, selector: #selector(jumpAll), name: NSNotification.Name("JumpAction"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restartGame), name: NSNotification.Name("RestartGame"), object: nil)
        
        startLoop()
    }
    
    func createBackground() {
        let bg = SKSpriteNode(color: .darkGray, size: self.size)
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        bg.zPosition = -10
        addChild(bg)
        
        // Маленький градиент/звезды
        for _ in 0..<30 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: size.height/2...size.height))
            star.alpha = CGFloat.random(in: 0.3...1.0)
            addChild(star)
        }
    }
    
    func createGround() {
        let ground = SKSpriteNode(color: .green, size: CGSize(width: size.width * 2, height: 100))
        ground.position = CGPoint(x: size.width/2, y: 50)
        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = platformCategory
        ground.physicsBody?.contactTestBitMask = playerCategory
        ground.name = "ground"
        addChild(ground)
    }
    
    func spawnPlayers() {
        // У нас будет три друга, бегущих "паровозиком"
        let positions = [
            (name: "friend1", color: UIColor.blue, xOffset: CGFloat(100)),
            (name: "friend2", color: UIColor.yellow, xOffset: CGFloat(150)),
            (name: "friend3", color: UIColor.black, xOffset: CGFloat(200))
        ]
        
        for p in positions {
            // Тело
            let body = SKSpriteNode(color: p.color, size: CGSize(width: 30, height: 50))
            body.position = CGPoint(x: p.xOffset, y: 150)
            
            // Если есть лицо, добавляем поверх, иначе забавный кружок
            let face: SKSpriteNode
            if let img = UIImage(named: p.name) {
                let texture = SKTexture(image: img)
                face = SKSpriteNode(texture: texture, size: CGSize(width: 32, height: 32))
            } else {
                face = SKSpriteNode(color: .orange, size: CGSize(width: 32, height: 32))
            }
            face.position = CGPoint(x: 0, y: 35)
            body.addChild(face)
            
            body.physicsBody = SKPhysicsBody(rectangleOf: body.size)
            body.physicsBody?.allowsRotation = false
            body.physicsBody?.categoryBitMask = playerCategory
            body.physicsBody?.contactTestBitMask = platformCategory | obstacleCategory | coinCategory
            body.name = "player"
            
            addChild(body)
            players.append(body)
        }
    }
    
    @objc func jumpAll() {
        for player in players {
            // Разрешаем прыжок только если игрок на земле (проверка скорости Y)
            if let velocity = player.physicsBody?.velocity.dy, abs(velocity) < 0.1 {
                player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 180))
            }
        }
    }
    
    @objc func restartGame() {
        self.removeAllChildren()
        players.removeAll()
        score = 0
        createBackground()
        createGround()
        spawnPlayers()
        startLoop()
    }
    
    func startLoop() {
        // Спавн препятствий и монет каждые 2 секунды
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnObstacleAndCoins()
        }
        let wait = SKAction.wait(forDuration: 2.0)
        let sequence = SKAction.sequence([spawnAction, wait])
        run(SKAction.repeatForever(sequence), withKey: "gameLoop")
    }
    
    func spawnObstacleAndCoins() {
        guard let _ = players.first else { return }
        
        let isObstacle = Bool.random()
        let speed: CGFloat = 200.0
        
        if isObstacle {
            // Спавн барьера
            let barrier = SKSpriteNode(color: .red, size: CGSize(width: 25, height: 35))
            barrier.position = CGPoint(x: size.width + 50, y: 110)
            barrier.physicsBody = SKPhysicsBody(rectangleOf: barrier.size)
            barrier.physicsBody?.isDynamic = false
            barrier.physicsBody?.categoryBitMask = obstacleCategory
            barrier.physicsBody?.contactTestBitMask = playerCategory
            barrier.name = "obstacle"
            addChild(barrier)
            
            let move = SKAction.moveBy(x: -(size.width + 100), y: 0, duration: Double(size.width / speed))
            let destroy = SKAction.removeFromParent()
            barrier.run(SKAction.sequence([move, destroy]))
        } else {
            // Спавн монетки
            let coin = SKSpriteNode(color: .yellow, size: CGSize(width: 20, height: 20))
            coin.position = CGPoint(x: size.width + 50, y: CGFloat.random(in: 140...220))
            coin.physicsBody = SKPhysicsBody(circleOfRadius: 10)
            coin.physicsBody?.isDynamic = false
            coin.physicsBody?.categoryBitMask = coinCategory
            coin.physicsBody?.contactTestBitMask = playerCategory
            coin.name = "coin"
            addChild(coin)
            
            let move = SKAction.moveBy(x: -(size.width + 100), y: 0, duration: Double(size.width / speed))
            let destroy = SKAction.removeFromParent()
            coin.run(SKAction.sequence([move, destroy]))
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // Контакт игрока с препятствием
        if firstBody.categoryBitMask == playerCategory && secondBody.categoryBitMask == obstacleCategory {
            if let obstacle = secondBody.node {
                obstacle.removeFromParent()
                gameDelegate?.didLoseLife()
            }
        }
        
        // Контакт игрока с монеткой
        if firstBody.categoryBitMask == playerCategory && secondBody.categoryBitMask == coinCategory {
            if let coin = secondBody.node {
                coin.removeFromParent()
                score += 10
                gameDelegate?.didUpdateScore(score)
            }
        }
    }
}
