import AVFoundation
import Foundation

final class AudioPlaybackController: ObservableObject {
    private var player: AVAudioPlayer?
    private var remotePlayer: AVPlayer?

    func play(storedFileName: String?) {
        guard let storedFileName, !storedFileName.isEmpty else {
            return
        }

        let url = AudioFileStore.localURL(for: storedFileName)
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Audio playback failed: \(error.localizedDescription)")
        }
    }

    func play(remoteURL: URL) {
        remotePlayer = AVPlayer(url: remoteURL)
        remotePlayer?.play()
    }
}
