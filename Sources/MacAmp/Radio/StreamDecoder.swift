import AVFoundation
import AudioToolbox

/// What a radio stream reports to the player.
enum RadioEvent: @unchecked Sendable {
    case connected
    case format(AVAudioFormat)
    case buffer(AVAudioPCMBuffer)
    case title(String)
    /// The stream is not MP3 or AAC: the player should use AVPlayer instead.
    case unsupported
    case ended(String?)
}

/// Turns the audio bytes of an MP3 or AAC (ADTS) stream into PCM buffers.
nonisolated final class StreamDecoder: @unchecked Sendable {
    private var stream: AudioFileStreamID?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var maxPacketSize: UInt32 = 4096
    private let emit: @Sendable (RadioEvent) -> Void

    init(fileType: AudioFileTypeID, emit: @escaping @Sendable (RadioEvent) -> Void) {
        self.emit = emit
        let client = Unmanaged.passUnretained(self).toOpaque()
        AudioFileStreamOpen(client, { client, stream, property, _ in
            Unmanaged<StreamDecoder>.fromOpaque(client).takeUnretainedValue().propertyChanged(stream, property)
        }, { client, bytes, packets, data, descriptions in
            Unmanaged<StreamDecoder>.fromOpaque(client).takeUnretainedValue()
                .receive(bytes: bytes, packets: packets, data: data, descriptions: descriptions)
        }, fileType, &stream)
    }

    deinit {
        if let stream { AudioFileStreamClose(stream) }
    }

    func feed(_ data: Data) {
        guard let stream, !data.isEmpty else { return }
        data.withUnsafeBytes { raw in
            _ = AudioFileStreamParseBytes(stream, UInt32(raw.count), raw.baseAddress, [])
        }
    }

    private func propertyChanged(_ stream: AudioFileStreamID, _ property: AudioFileStreamPropertyID) {
        switch property {
        case kAudioFileStreamProperty_PacketSizeUpperBound:
            var size = UInt32(0), length = UInt32(MemoryLayout<UInt32>.size)
            if AudioFileStreamGetProperty(stream, property, &length, &size) == noErr, size > 0 { maxPacketSize = size }
        case kAudioFileStreamProperty_DataFormat:
            var description = AudioStreamBasicDescription()
            var length = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            guard AudioFileStreamGetProperty(stream, property, &length, &description) == noErr,
                  let input = AVAudioFormat(streamDescription: &description),
                  let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: description.mSampleRate,
                                             channels: description.mChannelsPerFrame, interleaved: false),
                  let converter = AVAudioConverter(from: input, to: output) else { return }
            inputFormat = input
            outputFormat = output
            self.converter = converter
            emit(.format(output))
        default:
            break
        }
    }

    private func receive(bytes: UInt32, packets: UInt32, data: UnsafeRawPointer,
                         descriptions: UnsafePointer<AudioStreamPacketDescription>?) {
        guard let inputFormat, let outputFormat, let converter, packets > 0 else { return }
        let compressed = AVAudioCompressedBuffer(format: inputFormat, packetCapacity: packets,
                                                 maximumPacketSize: Int(max(maxPacketSize, bytes)))
        memcpy(compressed.data, data, Int(bytes))
        guard let target = compressed.packetDescriptions else { return }
        if let descriptions {
            for i in 0..<Int(packets) { target[i] = descriptions[i] }
        } else {
            // Constant packet size: build the descriptions.
            let size = inputFormat.streamDescription.pointee.mBytesPerPacket
            guard size > 0 else { return }
            for i in 0..<Int(packets) {
                target[i] = AudioStreamPacketDescription(mStartOffset: Int64(i) * Int64(size), mVariableFramesInPacket: 0, mDataByteSize: size)
            }
        }
        compressed.packetCount = packets
        compressed.byteLength = bytes

        let framesPerPacket = max(inputFormat.streamDescription.pointee.mFramesPerPacket, 1)
        guard let pcm = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: framesPerPacket * packets + 1152) else { return }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: pcm, error: &error) { _, outStatus in
            if supplied { outStatus.pointee = .noDataNow; return nil }
            supplied = true
            outStatus.pointee = .haveData
            return compressed
        }
        if status != .error, pcm.frameLength > 0 { emit(.buffer(pcm)) }
    }
}
