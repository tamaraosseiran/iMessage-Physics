//
//  ContentView.swift
//  iMessage
//
//  Created by Tamara Osseiran on 3/19/25.
//

import SwiftUI
import SwiftData
import UIKit

struct Message: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromMe: Bool
    let timestamp: Date
    
    // Add Equatable conformance
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.isFromMe == rhs.isFromMe &&
               lhs.timestamp == rhs.timestamp
    }
}

// First, add a physics state manager to handle all message interactions
class MessagePhysicsManager: ObservableObject {
    @Published var messageOffsets: [UUID: CGSize] = [:]
    @Published var messageVelocities: [UUID: CGSize] = [:]
    
    // Add reference to messages
    private var messages: [Message] = []
    
    // Function to update messages reference
    func updateMessages(_ newMessages: [Message]) {
        messages = newMessages
    }
    
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    
    // Adjust physics constants for faster settling
    let springStiffness: CGFloat = 12.0      // Increased for faster return
    let damping: CGFloat = 0.9               // More damping for faster settling
    let mass: CGFloat = 0.6                  // Lighter mass for quicker response
    let collisionElasticity: CGFloat = 0.5   // Less bounce
    let maxVelocity: CGFloat = 12000         // Keep high initial velocity
    let minMessageSpacing: CGFloat = 60.0
    
    func startPhysics() {
        guard displayLink == nil else { return }
        
        let displayLink = CADisplayLink(target: PhysicsProxy(update: updateAllMessages),
                                      selector: #selector(PhysicsProxy.performUpdate))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
        lastUpdateTime = CACurrentMediaTime()
    }
    
    func stopPhysics() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func applyShove(to messageId: UUID, velocity: CGSize) {
        if messageOffsets[messageId] == nil {
            messageOffsets[messageId] = .zero
        }
        messageVelocities[messageId] = velocity
        startPhysics()
        
        // Gentler reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(
                .spring(
                    response: 0.4,         // Longer response time for softer movement
                    dampingFraction: 0.8,  // More damping for less bounce
                    blendDuration: 0.3     // Longer blend for smoother transition
                )
            ) {
                self.messageOffsets.removeAll()
                self.messageVelocities.removeAll()
                self.stopPhysics()
            }
        }
    }
    
    private func updateAllMessages() {
        let currentTime = CACurrentMediaTime()
        let rawDeltaTime = currentTime - lastUpdateTime
        let deltaTime = min(rawDeltaTime, 1.0/60.0) // Clamp deltaTime
        lastUpdateTime = currentTime
        
        var stillMoving = false
        
        // Improved physics update
        for (id, offset) in messageOffsets {
            var velocity = messageVelocities[id] ?? .zero
            
            // Spring force with improved calculations
            let springForceX = -springStiffness * offset.width
            let springForceY = -springStiffness * offset.height
            
            // Apply forces with improved accuracy
            let accelerationX = springForceX / mass
            let accelerationY = springForceY / mass
            
            // Update velocity with clamping
            velocity.width = clampVelocity((velocity.width + CGFloat(accelerationX * deltaTime)) * damping)
            velocity.height = clampVelocity((velocity.height + CGFloat(accelerationY * deltaTime)) * damping)
            
            // Update position
            var newOffset = offset
            newOffset.width += velocity.width * CGFloat(deltaTime)
            newOffset.height += velocity.height * CGFloat(deltaTime)
            
            // Improved collision detection and response
            for (otherId, otherOffset) in messageOffsets where otherId != id {
                let dx = newOffset.width - otherOffset.width
                let dy = newOffset.height - otherOffset.height
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < 60 { // Collision threshold
                    // Proper collision response
                    let normal = CGSize(
                        width: dx / distance,
                        height: dy / distance
                    )
                    
                    // Relative velocity
                    let otherVelocity = messageVelocities[otherId] ?? .zero
                    let relativeVelocity = CGSize(
                        width: velocity.width - otherVelocity.width,
                        height: velocity.height - otherVelocity.height
                    )
                    
                    // Impact speed
                    let impactSpeed = relativeVelocity.width * normal.width +
                                    relativeVelocity.height * normal.height
                    
                    // Only collide if moving toward each other
                    if impactSpeed < 0 {
                        let impulse = -impactSpeed * collisionElasticity
                        
                        // Apply impulse to both objects
                        velocity.width += impulse * normal.width
                        velocity.height += impulse * normal.height
                        messageVelocities[otherId] = CGSize(
                            width: otherVelocity.width - impulse * normal.width,
                            height: otherVelocity.height - impulse * normal.height
                        )
                    }
                }
            }
            
            messageOffsets[id] = newOffset
            messageVelocities[id] = velocity
            
            // More precise movement detection
            let speed = sqrt(velocity.width * velocity.width +
                           velocity.height * velocity.height)
            if speed > 0.5 {
                stillMoving = true
            }
        }
        
        if !stillMoving {
            stopPhysics()
            messageOffsets.removeAll()
            messageVelocities.removeAll()
        }
        
        // Add order constraints
        let sortedMessages = Array(messageOffsets.keys).sorted { id1, id2 in
            // Find indices in the messages array
            guard let index1 = messages.firstIndex(where: { $0.id == id1 }),
                  let index2 = messages.firstIndex(where: { $0.id == id2 }) else {
                return false
            }
            return index1 < index2
        }
        
        // Enforce ordering constraints
        for i in 0..<sortedMessages.count-1 {
            let currentId = sortedMessages[i]
            let nextId = sortedMessages[i+1]
            
            if let currentOffset = messageOffsets[currentId],
               var nextOffset = messageOffsets[nextId] {
                // If next message is higher than current, push it down
                if nextOffset.height < currentOffset.height - minMessageSpacing {
                    nextOffset.height = currentOffset.height - minMessageSpacing
                    messageOffsets[nextId] = nextOffset
                    
                    // Adjust velocity to prevent bouncing
                    var velocity = messageVelocities[nextId] ?? .zero
                    if velocity.height < 0 {
                        velocity.height *= 0.5
                    }
                    messageVelocities[nextId] = velocity
                }
            }
        }
    }
    
    // Helper function to clamp velocity
    private func clampVelocity(_ value: CGFloat) -> CGFloat {
        return min(max(value, -maxVelocity), maxVelocity)
    }
}

struct ContentView: View {
    @StateObject private var physicsManager = MessagePhysicsManager()
    // Sample conversation data about planning a trip with double texting
    @State private var messages: [Message] = [
        Message(content: "Hey! I found some really good flight deals for our Bali trip", isFromMe: false, timestamp: Date().addingTimeInterval(-4200)),
        Message(content: "OMG really? How much?", isFromMe: true, timestamp: Date().addingTimeInterval(-4100)),
        Message(content: "$750 round trip if we go in April!", isFromMe: false, timestamp: Date().addingTimeInterval(-4000)),
        Message(content: "That's actually a steal for Bali wow", isFromMe: false, timestamp: Date().addingTimeInterval(-3950)),
        Message(content: "And I found this amazing villa on Airbnb", isFromMe: false, timestamp: Date().addingTimeInterval(-3900)),
        Message(content: "Hmm April could work! Let me check my work schedule", isFromMe: true, timestamp: Date().addingTimeInterval(-3800)),
        Message(content: "It has a private pool AND it's right by the beach", isFromMe: false, timestamp: Date().addingTimeInterval(-3650)),
        Message(content: "Omg that place looks incredible! 😍", isFromMe: true, timestamp: Date().addingTimeInterval(-3600)),
        Message(content: "And actually April is perfect! My project wraps up March 30", isFromMe: true, timestamp: Date().addingTimeInterval(-3550)),
        Message(content: "So should we book it??? This deal won't last long", isFromMe: false, timestamp: Date().addingTimeInterval(-3500)),
        Message(content: "YES let's do it!!", isFromMe: true, timestamp: Date().addingTimeInterval(-3400)),
        Message(content: "I'm so excited! I've always wanted to go to Bali!", isFromMe: true, timestamp: Date().addingTimeInterval(-3350)),
        Message(content: "Same! I'll book the flights tonight", isFromMe: false, timestamp: Date().addingTimeInterval(-3300)),
    ]
    
    @State private var newMessageText = ""
    @State private var showingSharePrompt = false
    @State private var dramaticMessageId: UUID? = nil
    
    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { message in
                        MessageRow(
                            message: message,
                            physicsManager: physicsManager,
                            isDramatic: message.id == dramaticMessageId
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ChatHeader(name: "Sophia", showSharePrompt: $showingSharePrompt)
                
                chatList
                
                MessageInputField(
                    text: $newMessageText,
                    onSend: sendMessage
                )
            }
            .background(Color(.systemGroupedBackground))
        }
        .onChange(of: messages) { _, newMessages in
            physicsManager.updateMessages(newMessages)
        }
    }
    
    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = Message(content: newMessageText, isFromMe: true, timestamp: Date())
        messages.append(newMessage)
        
        physicsManager.updateMessages(messages)
        
        if newMessageText.contains("!") {
            dramaticMessageId = newMessage.id
            
            // Count exclamation marks and calculate intensity with adjusted curve
            let exclamationCount = newMessageText.filter { $0 == "!" }.count
            let baseMultiplier = CGFloat(0.4) // Start with a lower base multiplier
            let intensityMultiplier = baseMultiplier + (CGFloat(min(exclamationCount, 5) - 1) * 0.9)
            
            // Scale initial force with adjusted multiplier
            physicsManager.applyShove(
                to: newMessage.id,
                velocity: CGSize(width: 0, height: -8000 * intensityMultiplier)
            )
            
            let messageCount = messages.count
            for (index, message) in messages.enumerated() {
                if message.id != newMessage.id && index < messageCount - 1 {
                    let distanceFromNew = messageCount - 1 - index
                    // Scale force magnitude with adjusted multiplier
                    let forceMagnitude = CGFloat(14000.0 * intensityMultiplier * exp(-Double(distanceFromNew) * 0.3))
                    let delay = 0.02 * Double(distanceFromNew)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.physicsManager.applyShove(
                            to: message.id,
                            velocity: CGSize(width: 0, height: -forceMagnitude)
                        )
                        
                        // Scale secondary push as well
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            self.physicsManager.applyShove(
                                to: message.id,
                                velocity: CGSize(
                                    width: 0,
                                    height: -forceMagnitude * 0.2 * intensityMultiplier
                                )
                            )
                        }
                    }
                }
            }
        }
        
        newMessageText = ""
    }
}

struct ChatHeader: View {
    let name: String
    @Binding var showSharePrompt: Bool
    
    var body: some View {
        ZStack {
            HStack {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                        Text("124")
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "video")
                        .foregroundColor(.blue)
                        .font(.system(size: 22))
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 2) {
                // Profile picture with blue background
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemBlue.withAlphaComponent(0.2)))
                        .frame(width: 50, height: 50)
                    
                    Image("profile") // Make sure to add this image to your assets
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)  // Slightly smaller than the background
                        .clipShape(Circle())
                }
                
                HStack {
                    Text(name)
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 5)
        
        if showSharePrompt {
            SharePrompt(isShowing: $showSharePrompt)
        }
        
        Divider()
    }
}

struct SharePrompt: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack {
            Image("profile_placeholder")
                .resizable()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Share your name and photo?")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Tamara Osseiran")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {}) {
                Text("Share")
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(15)
            }
            
            Button(action: { isShowing = false }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// First, add this physics-enabled message bubble
struct PhysicsMessageBubble: View {
    let message: Message
    let isDramatic: Bool
    @ObservedObject var physicsManager: MessagePhysicsManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading) {
            Text(message.content)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .rotation3DEffect(
                    isAnimating ? .degrees(-8) : .zero,
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.4
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(message.isFromMe ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isFromMe ? .white : .black)
                .cornerRadius(18)
                .offset(physicsManager.messageOffsets[message.id] ?? .zero)
                .onChange(of: isDramatic) { _, newValue in
                    if newValue {
                        // Use same spring parameters as reset
                        withAnimation(
                            .spring(
                                response: 0.2,
                                dampingFraction: 0.4,
                                blendDuration: 0.2
                            )
                        ) {
                            isAnimating = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(
                                .spring(
                                    response: 0.2,
                                    dampingFraction: 0.4,
                                    blendDuration: 0.2
                                )
                            ) {
                                isAnimating = false
                            }
                        }
                    }
                }
        }
    }
}

// Helper class for CADisplayLink
private class PhysicsProxy: NSObject {
    let update: () -> Void
    
    init(update: @escaping () -> Void) {
        self.update = update
        super.init()
    }
    
    @objc func performUpdate() {
        update()
    }
}

// Update MessageRow to use the physics manager
struct MessageRow: View {
    let message: Message
    @ObservedObject var physicsManager: MessagePhysicsManager
    var isDramatic: Bool = false
    @State private var isAnimating = false

    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
                PhysicsMessageBubble(message: message, isDramatic: isDramatic, physicsManager: physicsManager)
                    .scaleEffect(isAnimating ? 1.25 : 1.0)
                    .rotationEffect(isAnimating ? .degrees(2) : .zero)
                    .onChange(of: isDramatic) { _, newValue in
                        if newValue {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {  // Match bubble animation
                                isAnimating = true
                            }
                            // Match bubble reset timing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                                    isAnimating = false
                                }
                            }
                        }
                    }
            } else {
                PhysicsMessageBubble(message: message, isDramatic: isDramatic, physicsManager: physicsManager)
                Spacer()
            }
        }
        .padding(.vertical, 1)
    }
}

// Update the TextInputViewController to better handle text input
class TextInputViewController: UIViewController, UITextFieldDelegate {
    var textField: UITextField!
    var onTextChange: ((String) -> Void)?
    var onSend: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create text field
        textField = UITextField()
        textField.placeholder = "iMessage"
        textField.borderStyle = .none
        textField.returnKeyType = .send
        textField.delegate = self
        textField.backgroundColor = UIColor.systemGray6
        textField.layer.cornerRadius = 20
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        textField.leftViewMode = .always
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        // Add to view
        view.addSubview(textField)
        
        // Setup constraints
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: view.topAnchor),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    @objc func textFieldDidChange(_ sender: UITextField) {
        onTextChange?(sender.text ?? "")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onSend?()
        textField.text = ""
        // Ensure focus remains after sending
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        return false
    }
    
    // Make sure to re-enable text field after sending
    func resetTextField() {
        textField.text = ""
        textField.isEnabled = true
        textField.becomeFirstResponder()
    }
}

// Update NativeTextField to handle text field reset
struct NativeTextField: UIViewControllerRepresentable {
    @Binding var text: String
    var onSend: () -> Void
    
    func makeUIViewController(context: Context) -> TextInputViewController {
        let controller = TextInputViewController()
        controller.onTextChange = { newText in
            text = newText
        }
        controller.onSend = {
            onSend()
            // Reset text field after sending
            DispatchQueue.main.async {
                controller.resetTextField()
            }
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: TextInputViewController, context: Context) {
        if uiViewController.textField.text != text {
            uiViewController.textField.text = text
        }
    }
}

// Update MessageInputField to use our native text field
struct MessageInputField: View {
    @Binding var text: String
    var onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom) {
            Button(action: {}) {
                Image(systemName: "plus")
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .padding(.trailing, 5)
            
            // Main text input area
            HStack {
                // Use our UIKit native text field
                NativeTextField(text: $text, onSend: onSend)
                
                if !text.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                    .padding(.trailing, 8)
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .frame(height: 36)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// Preview
#Preview {
    ContentView()
}

