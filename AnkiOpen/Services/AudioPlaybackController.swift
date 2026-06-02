import AVFoundation
import Foundation

final class AudioPlaybackController: ObservableObject {
    private var player: AVAudioPlayer?
    private var remotePlayer: AVPlayer?

    @discardableResult
    func play(storedFileName: String?) -> Bool {
        guard let storedFileName, !storedFileName.isEmpty else {
            return false
        }

        let url = AudioFileStore.localURL(for: storedFileName)
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            return player?.play() == true
        } catch {
            print("Audio playback failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func play(data: Data) -> Bool {
        guard !data.isEmpty else {
            return false
        }

        do {
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            return player?.play() == true
        } catch {
            print("Audio playback failed: \(error.localizedDescription)")
            return false
        }
    }

    func play(remoteURL: URL) {
        remotePlayer = AVPlayer(url: remoteURL)
        remotePlayer?.play()
    }
}
