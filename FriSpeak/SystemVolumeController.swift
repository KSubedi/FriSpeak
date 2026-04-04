import CoreAudio
import Foundation

struct SystemVolumeController {
    private enum VolumeError: Error {
        case outputDeviceUnavailable
        case volumePropertyUnavailable
        case queryFailed(OSStatus)
        case setFailed(OSStatus)
    }

    func currentOutputVolume() throws -> Float32 {
        let deviceID = try defaultOutputDeviceID()
        var address = try volumeAddress(for: deviceID)
        var volume = Float32.zero
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &volume)
        guard status == noErr else {
            throw VolumeError.queryFailed(status)
        }

        return min(max(volume, 0), 1)
    }

    func setOutputVolume(_ volume: Float32) throws {
        let deviceID = try defaultOutputDeviceID()
        var address = try volumeAddress(for: deviceID)
        var clampedVolume = min(max(volume, 0), 1)
        let dataSize = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, dataSize, &clampedVolume)
        guard status == noErr else {
            throw VolumeError.setFailed(status)
        }
    }

    func canControlOutputVolume() -> Bool {
        do {
            let deviceID = try defaultOutputDeviceID()
            _ = try volumeAddress(for: deviceID)
            return true
        } catch {
            return false
        }
    }

    private func defaultOutputDeviceID() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID.zero
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr, deviceID != .zero else {
            throw VolumeError.outputDeviceUnavailable
        }

        return deviceID
    }

    private func volumeAddress(for deviceID: AudioDeviceID) throws -> AudioObjectPropertyAddress {
        let candidateAddresses = [
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 1
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 2
            )
        ]

        for address in candidateAddresses {
            var mutableAddress = address
            if AudioObjectHasProperty(deviceID, &mutableAddress) {
                return address
            }
        }

        throw VolumeError.volumePropertyUnavailable
    }
}
