//
//  ContentView.swift
//  iMessage
//
//  Created by Tamara Osseiran on 3/19/25.
//

import SwiftUI
import SwiftData

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isFromMe: Bool
    let timestamp: Date
    var reaction: String?
}

struct ContentView: View {
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
        Message(content: "So should we book it??? This deal won't last long", isFromMe: false, timestamp: Date().addingTimeInterval(-3500), reaction: "❤️"),
        Message(content: "YES let's do it!!", isFromMe: true, timestamp: Date().addingTimeInterval(-3400)),
        Message(content: "I'm so excited! I've always wanted to go to Bali!", isFromMe: true, timestamp: Date().addingTimeInterval(-3350)),
        Message(content: "Same! I'll book the flights tonight", isFromMe: false, timestamp: Date().addingTimeInterval(-3300)),
    ]
    
    @State private var newMessageText = ""
    @State private var showingSharePrompt = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            ChatHeader(name: "Sophia", showSharePrompt: $showingSharePrompt)
            
            // Messages list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageRow(message: message)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Input field
            MessageInputField(text: $newMessageText, onSend: sendMessage)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = Message(content: newMessageText, isFromMe: true, timestamp: Date())
        messages.append(newMessage)
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
                // Profile picture - using a placeholder
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemBlue.withAlphaComponent(0.2)))
                        .frame(width: 50, height: 50)
                    
                    Text("👨🏽‍💻")
                        .font(.system(size: 24))
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

struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
                MessageBubble(message: message)
            } else {
                MessageBubble(message: message)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading) {
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(message.isFromMe ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isFromMe ? .white : .black)
                .cornerRadius(18)
            
            if let reaction = message.reaction {
                Text(reaction)
                    .font(.title3)
                    .padding(5)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.1), radius: 2)
                    .offset(y: -15)
            }
        }
        .overlay(
            Group {
                if message.reaction != nil {
                    EmptyView()
                }
            }
        )
    }
}

struct MessageInputField: View {
    @Binding var text: String
    var onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom) {
            // Plus button with grey circular background
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "plus")
                    .foregroundColor(.gray)
                    .font(.system(size: 20))
            }
            .padding(.trailing, 5)
            
            // Extended iMessage bar
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                
                HStack {
                    TextField("iMessage", text: $text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    
                    if text.isEmpty {
                        Button(action: {}) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 12)
                    } else {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 28))
                        }
                        .padding(.trailing, 8)
                    }
                }
            }
            .frame(height: 36)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4))
                .offset(y: -0.25),
            alignment: .top
        )
    }
}

// Preview
#Preview {
    ContentView()
}
