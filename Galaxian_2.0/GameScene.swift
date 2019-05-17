//
//  GameScene.swift
//  Galaxian_2.0
//
//  Created by Alex Kolovatov on 17/05/2019.
//  Copyright © 2019 Alex Kolovatov. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: Properties
    private var score:Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    private var gameTimer: Timer!
    private var possibleAliens = ["alien", "alien2", "alien3"]
    
    // MARK: 7. Bimasks
    private let alienCategory: UInt32 = 0x1 << 1
    private let photonTorpedoCategory: UInt32 = 0x1 << 0
    
    // MARK: Player Motion
    private let motionManger = CMMotionManager()
    private var xAcceleration: CGFloat = 0
    
    // MARK: 1. Background
    lazy var starfield: SKEmitterNode = {
        guard let node = SKEmitterNode(fileNamed: "Starfield") else { return SKEmitterNode() }
        node.advanceSimulationTime(10)
        node.zPosition = -1
        return node
    }()
    
    // MARK: 2. Player
    lazy var player: SKSpriteNode = {
        let node = SKSpriteNode(imageNamed: "shuttle")
        return node
    }()
    
    // MARK: 3. Score Label
    lazy var scoreLabel: SKLabelNode = {
        let label = SKLabelNode(text: "Score: 0")
        label.fontName = "AmericanTypewriter-Bold"
        label.fontSize = 28
        label.fontColor = UIColor.white
        return label
    }()
    
    override func didMove(to view: SKView) {
        
        addChild(starfield)
        addChild(player)
        addChild(scoreLabel)
        
        starfield.position = CGPoint(x: 0, y: frame.height)
        player.position = CGPoint(x: frame.width / 2, y: player.size.height / 2 + 20)
        scoreLabel.position = CGPoint(x: 100, y: frame.size.height - 30)
        
        // MARK: 4. GRAVITY
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        
        // MARK: 6. Timer
        gameTimer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(addAlien), userInfo: nil, repeats: true)
        
        motionManger.accelerometerUpdateInterval = 0.2
        motionManger.startAccelerometerUpdates(to: OperationQueue.current!) { (data:CMAccelerometerData?, error:Error?) in
            if let accelerometerData = data {
                let acceleration = accelerometerData.acceleration
                self.xAcceleration = CGFloat(acceleration.x) * 0.75 + self.xAcceleration * 0.25
            }
        }
    }
    
    // MARK: 5. Add aliens
    @objc func addAlien () {
        guard let aliens = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: possibleAliens) as? [String] else { return }
        possibleAliens = aliens
        
        guard let randomAlien = possibleAliens.first else { return }
        let alien = SKSpriteNode(imageNamed: randomAlien)
        let randomAlienPosition = GKRandomDistribution(lowestValue: 0, highestValue: Int(frame.height))
        let position = CGFloat(randomAlienPosition.nextInt())
        
        alien.position = CGPoint(x: position, y: self.frame.size.height + alien.size.height)
        
        alien.physicsBody = SKPhysicsBody(rectangleOf: alien.size)
        alien.physicsBody?.isDynamic = true
        
        alien.physicsBody?.categoryBitMask = alienCategory
        alien.physicsBody?.contactTestBitMask = photonTorpedoCategory
        alien.physicsBody?.collisionBitMask = 0
        
        addChild(alien)
        
        let animationDuration: TimeInterval = 6
        
        var actionArray = [SKAction]()
        actionArray.append(SKAction.move(to: CGPoint(x: position, y: -alien.size.height), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        alien.run(SKAction.sequence(actionArray))
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fireTorpedo()
    }
    
    func fireTorpedo() {
        self.run(SKAction.playSoundFileNamed("torpedo.mp3", waitForCompletion: false))
        
        let torpedoNode = SKSpriteNode(imageNamed: "torpedo")
        torpedoNode.position = player.position
        torpedoNode.position.y += 5
        
        torpedoNode.physicsBody = SKPhysicsBody(circleOfRadius: torpedoNode.size.width / 2)
        torpedoNode.physicsBody?.isDynamic = true
    
        torpedoNode.physicsBody?.categoryBitMask = photonTorpedoCategory
        torpedoNode.physicsBody?.contactTestBitMask = alienCategory
        torpedoNode.physicsBody?.collisionBitMask = 0
        torpedoNode.physicsBody?.usesPreciseCollisionDetection = true
        
        self.addChild(torpedoNode)
        
        let animationDuration:TimeInterval = 0.3
        
        
        var actionArray = [SKAction]()
        
        actionArray.append(SKAction.move(to: CGPoint(x: player.position.x, y: self.frame.size.height + 10), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        
        torpedoNode.run(SKAction.sequence(actionArray))
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody:SKPhysicsBody
        var secondBody:SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        if (firstBody.categoryBitMask & photonTorpedoCategory) != 0 && (secondBody.categoryBitMask & alienCategory) != 0 {
            torpedoDidCollideWithAlien(torpedoNode: firstBody.node as! SKSpriteNode, alienNode: secondBody.node as! SKSpriteNode)
        }
        
    }
    
    
    func torpedoDidCollideWithAlien (torpedoNode:SKSpriteNode, alienNode:SKSpriteNode) {
        guard let explosion = SKEmitterNode(fileNamed: "Explosion") else { return }
        explosion.position = alienNode.position
        addChild(explosion)
        
        run(SKAction.playSoundFileNamed("explosion.mp3", waitForCompletion: false))
        
        torpedoNode.removeFromParent()
        alienNode.removeFromParent()
        
        run(SKAction.wait(forDuration: 2)) {
            explosion.removeFromParent()
        }
        
        score += 5
    }
    
    override func didSimulatePhysics() {
        
        player.position.x += xAcceleration * 50
        
        if player.position.x < -20 {
            player.position = CGPoint(x: self.size.width + 20, y: player.position.y)
        }else if player.position.x > self.size.width + 20 {
            player.position = CGPoint(x: -20, y: player.position.y)
        }
        
    }


}
