import AVFoundation
import AudioToolbox
import MacAmpKit

/// One connection to a radio stream. Asks for song titles (ICY), strips them
/// out of the audio, and decodes the audio to PCM.
nonisolated final class RadioStream: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let url: URL
    private let handler: @Sendable (RadioEvent) -> Void
    private let queue = OperationQueue()
    private var session: URLSession?
    private var parser = ICYStreamParser(metaInterval: 0)
    private var decoder: StreamDecoder?
    private var finished = false

    init(url: URL, handler: @escaping @Sendable (RadioEvent) -> Void) {
        self.url = url
        self.handler = handler
        queue.maxConcurrentOperationCount = 1
        super.init()
    }

    func start() {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.setValue("MacAmp/0.1", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: queue)
        self.session = session
        session.dataTask(with: request).resume()
    }

    func stop() {
        finished = true
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            completionHandler(.cancel)
            finish("The station answered with an error.")
            return
        }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key.lowercased()] = value }
        }
        let type = (headers["content-type"] ?? "").lowercased()
        let fileType: AudioFileTypeID?
        if type.contains("mpeg") || type.contains("mp3") {
            fileType = kAudioFileMP3Type
        } else if type.contains("aac") {
            fileType = kAudioFileAAC_ADTSType
        } else {
            fileType = nil
        }
        guard let fileType else {
            completionHandler(.cancel)
            if !finished { finished = true; handler(.unsupported) }
            return
        }
        parser = ICYStreamParser(metaInterval: Int(headers["icy-metaint"] ?? "") ?? 0)
        decoder = StreamDecoder(fileType: fileType, emit: handler)
        handler(.connected)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !finished else { return }
        let parts = parser.feed(data)
        for title in parts.titles { handler(.title(title)) }
        decoder?.feed(parts.audio)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !finished else { return }
        finish(error?.localizedDescription)
    }

    private func finish(_ reason: String?) {
        guard !finished else { return }
        finished = true
        handler(.ended(reason))
    }
}
