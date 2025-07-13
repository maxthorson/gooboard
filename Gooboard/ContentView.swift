import SwiftUI
import AVFoundation

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    var player: AVAudioPlayer?
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
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}

struct ContentView: View {
    @State private var audioManagers = (0..<9).map { _ in AudioPlayerManager() }
    
    let columns = Array(repeating: GridItem(.fixed(100), spacing: 16), count: 3)

    var body: some View {
        VStack(spacing: 20) {
            Text("poo poo pee pee fart")
                .font(.title)
                .bold()
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<9, id: \.self) { i in
                    let manager = audioManagers[i]
                    Button(action: {
                        manager.playSound(named: "yippee.mp3")
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                            Image(systemName: manager.isPlaying ? "speaker.wave.3.fill" : "speaker.fill")
                                .foregroundStyle(.white)
                                .labelStyle(.iconOnly)
                                .offset(x: manager.isPlaying ? 18 : 0)
                        }
                        .frame(width: 80, height: 80)
                        .animation(.spring(), value: manager.isPlaying)
                    }
                }
            }
        }
        .padding()
    }
}

