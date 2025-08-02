import SwiftUI
import UIKit
import AVFoundation
import Foundation
import Combine
import UniformTypeIdentifiers

enum SwipeDirection { case left, right }

struct Soundboard: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var rows: Int
    var columns: Int
    var buttonStates: [SoundButtonState]
}

class SoundboardPersistence {
    static let shared = SoundboardPersistence()
    private let key = "Soundboards"

    func loadBoards() -> [Soundboard] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Soundboard].self, from: data) else {
            return []
        }
        return decoded
    }

    func saveBoards(_ boards: [Soundboard]) {
        if let encoded = try? JSONEncoder().encode(boards) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

struct SoundButtonState: Codable, Equatable {
    var emoji: String
    var colorHex: String
    var customSoundFileName: String?
}

extension Color {
    var hexString: String {
        UIColor(self).toHexString()
    }
    init?(hex: String) {
        guard let uiColor = UIColor(hex: hex) else { return nil }
        self = Color(uiColor)
    }
}

extension UIColor {
    func toHexString() -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgb:Int = (Int)(red*255)<<16 | (Int)(green*255)<<8 | (Int)(blue*255)<<0
        return String(format:"#%06x", rgb)
    }
    convenience init?(hex: String) {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") { cString.removeFirst() }
        if cString.count != 6 { return nil }
        var rgb: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0)
    }
}

class SoundButtonPersistence {
    static let shared = SoundButtonPersistence()
    private let key = "SoundButtonStates"
    func loadStates(count: Int) -> [SoundButtonState] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SoundButtonState].self, from: data),
              decoded.count == count else {
            // Return default states with empty emoji, blue color hex, and no custom sound file
            return Array(repeating: SoundButtonState(emoji: "", colorHex: Color.blue.hexString, customSoundFileName: nil), count: count)
        }
        return decoded
    }
    func saveStates(_ states: [SoundButtonState]) {
        if let encoded = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    var player: AVAudioPlayer?
    
    override init() {
        super.init()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    func playSound(named soundName: String) {
        guard let path = Bundle.main.path(forResource: soundName, ofType: nil) else {
            print("path not created")
            return
        }
        let url = URL(fileURLWithPath: path)
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.1
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
    func playSound(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }
}
struct OnboardingItem: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var image: String
}

struct SoundboardView: View {
    @Binding var soundboard: Soundboard
    let soundNames: [String]
    var onSwipe: ((SwipeDirection) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var titleIsFocused: Bool
    
    @State private var stopAllTrigger: UUID = UUID()

    init(soundboard: Binding<Soundboard>, soundNames: [String], onSwipe: ((SwipeDirection) -> Void)? = nil) {
        _soundboard = soundboard
        self.soundNames = soundNames
        self.onSwipe = onSwipe
    }

    func stopAllSounds() {
        stopAllTrigger = UUID()
    }

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                TextField("put a title here twin", text: $soundboard.title)
                    .font(.title)
                    .bold()
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)
                    .focused($titleIsFocused)
                    .autocorrectionDisabled(!titleIsFocused)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.plain)
                    .padding(.bottom, 2)
                let columns = Array(repeating: GridItem(.fixed(100), spacing: 16), count: soundboard.columns)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<(soundboard.rows * soundboard.columns), id: \.self) { i in
                        SoundButton(
                            soundName: i < soundNames.count ? soundNames[i] : "",
                            state: $soundboard.buttonStates[i],
                            persist: { SoundboardPersistence.shared.saveBoards([soundboard]) },
                            stopAllTrigger: $stopAllTrigger
                        )
                    }
                }
                Button(action: stopAllSounds) {
                    Label("Stop Sounds", systemImage: "speaker.slash.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.title3)
                        .foregroundStyle(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 44)
                        .glassEffect(.regular.tint(.red).interactive())
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Stop All Sounds")
            }
            .padding()
            .onTapGesture { titleIsFocused = false }
            .gesture(DragGesture().onChanged { _ in titleIsFocused = false })
        }
    }
}

struct ContentView: View {
    @State private var soundboards: [Soundboard] = SoundboardPersistence.shared.loadBoards().isEmpty ? [Soundboard(id: UUID(), title: "My Soundboard", rows: 3, columns: 3, buttonStates: Array(repeating: SoundButtonState(emoji: "", colorHex: Color.blue.hexString, customSoundFileName: nil), count: 9))] : SoundboardPersistence.shared.loadBoards()
    @State private var selectedBoardIndex: Int = 0
    @State private var showingNewBoardSheet = false
    @State private var newBoardTitle = ""
    @State private var newRows = 3
    @State private var newColumns = 3

    let soundNames = [
        "yippee.mp3", "awhellnaw.mp3", "getout.mp3", "hehehehaw.mp3", "wahhhhh.mp3", "cooked.mp3", "sound7.mp3", "sound8.mp3", "sound92.mp3"
    ]

    func persist() {
        SoundboardPersistence.shared.saveBoards(soundboards)
    }

    var body: some View {
        NavigationView {
            VStack {
                TabView(selection: $selectedBoardIndex) {
                    ForEach(soundboards.indices, id: \.self) { idx in
                        SoundboardView(
                            soundboard: $soundboards[idx],
                            soundNames: soundNames,
                            onSwipe: { direction in
                                if direction == .left && selectedBoardIndex < soundboards.count - 1 {
                                    selectedBoardIndex += 1
                                } else if direction == .right && selectedBoardIndex > 0 {
                                    selectedBoardIndex -= 1
                                }
                            }
                        )
                        .tag(idx)
                        .onChange(of: soundboards[idx]) { persist() }
                    }
                }
                .tabViewStyle(.page)
                .contentShape(Rectangle())
                VStack {
                    HStack {
                        Button(action: { showingNewBoardSheet = true }) {
                            Label("Add Board", systemImage: "plus")
                        }
                        .padding()
                        .frame(minWidth: 140)
                        .foregroundStyle(.white)
                        .glassEffect(.regular.tint(.blue).interactive())
                        if soundboards.count > 1 {
                            Button(action: {
                                soundboards.remove(at: selectedBoardIndex)
                                selectedBoardIndex = max(0, selectedBoardIndex - 1)
                                persist()
                            }) {
                                Label("Delete Board", systemImage: "trash")
                            }
                            .padding()
                            .frame(minWidth: 140)
                            .foregroundStyle(.black)
                            .glassEffect(.regular.tint(.red).interactive())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Soundboards")
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $showingNewBoardSheet) {
                VStack(spacing: 16) {
                    Text("New Soundboard").font(.title2).bold()
                    TextField("Board Title", text: $newBoardTitle)
                        .textFieldStyle(.roundedBorder)
                    Stepper("Rows: \(newRows)", value: $newRows, in: 1...4)
                    Stepper("Columns: \(newColumns)", value: $newColumns, in: 1...5)
                    Button("ship it") {
                        let buttonCount = newRows * newColumns
                        let board = Soundboard(
                            id: UUID(),
                            title: newBoardTitle.isEmpty ? "u didnt put a name twin" : newBoardTitle,
                            rows: newRows,
                            columns: newColumns,
                            buttonStates: Array(repeating: SoundButtonState(emoji: "", colorHex: Color.blue.hexString, customSoundFileName: nil), count: buttonCount)
                        )
                        soundboards.append(board)
                        selectedBoardIndex = soundboards.count - 1
                        persist()
                        showingNewBoardSheet = false
                        newBoardTitle = ""
                        newRows = 3
                        newColumns = 3
                    }
                    .buttonStyle(.borderedProminent)
                    Button("ditch it", role: .cancel) {
                        showingNewBoardSheet = false
                    }
                }
                .padding()
                .ignoresSafeArea(.keyboard)
            }
        }
    }
}

struct SoundButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var manager = AudioPlayerManager()
    let soundName: String
    

    @Binding var state: SoundButtonState
    let persist: () -> Void
    
    @Binding var stopAllTrigger: UUID
    
    @State private var showingEmojiPicker = false
    @State private var showingFileImporter = false
    @State private var showError = false
    @State private var wiggle = false
    
    @State private var showImportErrorAlert = false
    @State private var importErrorMessage = ""
    
    @State private var showingFileName = false
    
    private var hasSoundFile: Bool {
        Bundle.main.path(forResource: soundName, ofType: nil) != nil
    }
    
    private var currentColor: Color {
        Color(hex: state.colorHex) ?? .blue
    }
    
    private var customSoundURL: URL? {
        guard let fileName = state.customSoundFileName else { return nil }
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docDir.appendingPathComponent(fileName)
    }
    
    private var hasAudioNow: Bool {
        if let custom = customSoundURL, FileManager.default.fileExists(atPath: custom.path) { return true }
        return hasSoundFile
    }
    
    var body: some View {
        Button(action: {
            let soundURL = customSoundURL ?? Bundle.main.url(forResource: soundName, withExtension: nil)
            guard let playURL = soundURL, FileManager.default.fileExists(atPath: playURL.path) else {
                showError = true
                print("u done fucked up cuh there no sound here cuh")
                withAnimation(.default) { wiggle.toggle() }
                triggerErrorHaptic()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showError = false
                    withAnimation(.default) { wiggle.toggle() }
                }
                return
            }
            showError = false
            manager.playSound(url: playURL)
            triggerSuccessHaptic()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(showError ? Color.red : (manager.isPlaying ? currentColor.opacity(0.5) : (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(manager.isPlaying ? currentColor : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 4)
                    )
                    .animation(.easeInOut, value: showError)
                if state.emoji.isEmpty {
                    Image(systemName: !hasAudioNow ? "speaker.badge.exclamationmark.fill" : (manager.isPlaying ? "speaker.wave.3.fill" : "speaker.fill"))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .labelStyle(.iconOnly)
                        .contentTransition(.symbolEffect(.replace))
                        .rotationEffect(.degrees(wiggle ? -10 : 0))
                        .animation(showError ? Animation.easeInOut(duration: 0.07).repeatCount(6, autoreverses: true) : .default, value: wiggle)
                } else {
                    Text(state.emoji)
                        .font(.largeTitle)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .transition(.scale)
                        .rotationEffect(.degrees(wiggle ? -10 : 0))
                        .animation(showError ? Animation.easeInOut(duration: 0.07).repeatCount(6, autoreverses: true) : .default, value: wiggle)
                }
            }
            .frame(width: 80, height: 80)
            .animation(.spring(), value: manager.isPlaying)
        }
        .onChange(of: stopAllTrigger) { _ in
            manager.stop()
        }
        .onLongPressGesture {
            showingFileName = true
        }
        .popover(isPresented: $showingFileName) {
            Text(state.customSoundFileName ?? soundName)
                .font(.body)
                .padding()
        }
        .contextMenu {
            Text(state.customSoundFileName ?? soundName)
                .padding(4)
                .disabled(true)
            Button(action: { showingEmojiPicker = true }) {
                Label("Choose Emoji", systemImage: "face.smiling")
            }
            Button(action: {
                state.emoji = ""
                persist()
            }) {
                Label("Reset Icon", systemImage: "speaker.fill")
            }
            Button(action: { showingFileImporter = true }) {
                Label("Choose Custom Sound", systemImage: "music.note")
            }
            if state.customSoundFileName != nil {
                Button(action: {
                    state.customSoundFileName = nil
                    persist()
                }) {
                    Label("Reset to Default Sound", systemImage: "arrow.uturn.left")
                }
            }
            Menu {
                Button {
                    state.colorHex = Color.blue.hexString
                    persist()
                } label: {
                    Label("Blue", systemImage: "circle.fill")
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
                .tint(.blue)
                Button {
                    state.colorHex = Color.red.hexString
                    persist()
                } label: {
                    Label("Red", systemImage: "circle.fill")
                }
                .tint(.red)
                Button {
                    state.colorHex = Color.green.hexString
                    persist()
                } label: {
                    Label("Green", systemImage: "circle.fill")
                }
                .tint(.green)
                Button {
                    state.colorHex = Color.orange.hexString
                    persist()
                } label: {
                    Label("Orange", systemImage: "circle.fill")
                }
                .tint(.orange)
                Button {
                    state.colorHex = Color.purple.hexString
                    persist()
                } label: {
                    Label("Purple", systemImage: "circle.fill")
                }
                .tint(.purple)
                Button {
                    state.colorHex = Color.pink.hexString
                    persist()
                } label: {
                    Label("Pink", systemImage: "circle.fill")
                }
                .tint(.pink)
                Button {
                    state.colorHex = Color.yellow.hexString
                    persist()
                } label: {
                    Label("Yellow", systemImage: "circle.fill")
                }
                .tint(.yellow)
                Button {
                    state.colorHex = Color.gray.hexString
                    persist()
                } label: {
                    Label("Gray", systemImage: "circle.fill")
                }
                .tint(.gray)
            } label: {
                Label("Highlight Color", systemImage: "circle.fill")
            }
            .tint(currentColor)
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: $state.emoji, persist: persist)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.mp3, UTType(filenameExtension: "ogg")!] ,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let fileURL = urls.first else { return }
                guard fileURL.startAccessingSecurityScopedResource() else {
                    print("tim apple does not want you to have ts")
                    return
                }
                defer { fileURL.stopAccessingSecurityScopedResource() }
                do {
                    let previouslyHadNoSound = (state.customSoundFileName == nil && Bundle.main.path(forResource: soundName, ofType: nil) == nil)

                    let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let fileName = fileURL.lastPathComponent
                    let destURL = docDir.appendingPathComponent(fileName)
                    var finalURL = destURL
                    var i = 1
                    while FileManager.default.fileExists(atPath: finalURL.path) {
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        let ext = fileURL.pathExtension
                        finalURL = docDir.appendingPathComponent("\(name)-\(i).\(ext)")
                        i += 1
                    }
                    try FileManager.default.copyItem(at: fileURL, to: finalURL)
                    
                    var isPlayable = false
                    let testPlayer: AVAudioPlayer?
                    do {
                        testPlayer = try AVAudioPlayer(contentsOf: finalURL)
                        isPlayable = testPlayer != nil
                    } catch {
                        isPlayable = false
                    }
                    if !isPlayable {
                        // Remove the file if it's not valid
                        try? FileManager.default.removeItem(at: finalURL)
                        importErrorMessage = "yoooo ts didnt work twin. select yoself another file cuh"
                        showImportErrorAlert = true
                        return
                    }
                    
                    state.customSoundFileName = finalURL.lastPathComponent
                    if previouslyHadNoSound {
                        state.emoji = "" // Triggers update to use the default icon
                    }
                    persist()
                } catch {
                    print("yeah so how bout fuck you: \(error)")
                }
            case .failure(let error):
                print("yeah fuck you again: \(error)")
            }
        }
        .alert(isPresented: $showImportErrorAlert) {
            Alert(title: Text("nuh uh"), message: Text(importErrorMessage), dismissButton: .default(Text("damn ok twin")))
        }
    }
    
    private func triggerErrorHaptic() {
    #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    #endif
    }
    private func triggerSuccessHaptic() {
    #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    #endif
    }
}

struct EmojiPickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedEmoji: String
    var persist: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var tempEmoji: String = ""
    var body: some View {
        VStack(spacing: 24) {
            Text("what emoji u want chat").font(.headline)
                .foregroundStyle(colorScheme == .dark ? .white : .black)
            TextField("you gotta type it idk", text: $tempEmoji)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .keyboardType(.default)
                .submitLabel(.done)
                .onChange(of: tempEmoji) {
                    // Only keep the first emoji character
                    if let firstEmoji = tempEmoji.first, firstEmoji.isEmoji {
                        selectedEmoji = String(firstEmoji)
                        persist?() // Persist emoji change
                        dismiss()
                    }
                }
                .padding(8)
                .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                .cornerRadius(8)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Button("cancel", role: .cancel) { dismiss() }
        }
        .padding()
    }
}

extension Character {
    var isEmoji: Bool { unicodeScalars.first?.properties.isEmojiPresentation == true || unicodeScalars.first?.properties.isEmoji == true }
}
