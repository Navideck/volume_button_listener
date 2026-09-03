import Cocoa
import CoreAudio
import CoreGraphics
import FlutterMacOS

private let kNXSysDefinedEventMask: CGEventMask = .init(1 << 14)
private let NX_SUBTYPE_AUX_CONTROL_BUTTONS: Int16 = 8
private let NX_KEYTYPE_SOUND_UP: Int = 0
private let NX_KEYTYPE_SOUND_DOWN: Int = 1
private let NX_KEYDOWN: Int = 0x0A
private let NX_KEYUP: Int = 0x0B

public class VolumeButtonListenerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger
    let callbackChannel = VolumeButtonListenerCallbackChannel(binaryMessenger: messenger)
    let api = VolumeButtonHandler(callbackChannel: callbackChannel)
    VolumeButtonListenerPlatformChannelSetup.setUp(binaryMessenger: messenger, api: api)
  }
}

class VolumeButtonHandler: VolumeButtonListenerPlatformChannel {
  private let callbackChannel: VolumeButtonListenerCallbackChannel
  // TODO: `lastVolume` is currently assigned but never read; remove it or restore intended usage.
  private var lastVolume: Float32 = 0
  private var isStarted = false
  private var showVolumeUi = false
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?

  /// Used by the CGEvent tap callback (runs on main run loop) to reach this instance.
  private weak static var activeHandler: VolumeButtonHandler?

  init(callbackChannel: VolumeButtonListenerCallbackChannel) {
    self.callbackChannel = callbackChannel
  }

  deinit {
    try? stopListener()
  }

  func startListener() throws {
    guard !isStarted else { return }
    isStarted = true
    lastVolume = Self.getSystemVolume()
    VolumeButtonHandler.activeHandler = self

    guard let tap = CGEvent.tapCreate(
      tap: .cghidEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: kNXSysDefinedEventMask,
      callback: { _, type, event, _ in
        VolumeButtonHandler.volumeKeyTapCallback(type: type, event: event)
      },
      userInfo: nil
    ) else {
      VolumeButtonHandler.activeHandler = nil
      isStarted = false
      throw NSError(domain: "VolumeButtonListener", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Failed to create event tap. Enable Input Monitoring for this app in System Settings → Privacy & Security.",
      ])
    }
    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  func stopListener() throws {
    guard isStarted else { return }
    isStarted = false
    VolumeButtonHandler.activeHandler = nil
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
      runLoopSource = nil
    }
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
      eventTap = nil
    }
  }

  func isListening() throws -> Bool {
    isStarted
  }

  func setShowVolumeUi(showVolumeUi: Bool) throws {
    self.showVolumeUi = showVolumeUi
  }

  /// CGEvent tap callback: consume volume keys so the system never shows the volume OSD.
  private static func volumeKeyTapCallback(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Re-enable tap if it was disabled (e.g. timeout or user input)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let handler = VolumeButtonHandler.activeHandler, let tap = handler.eventTap {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return nil
    }
    guard type.rawValue == 14 else { return Unmanaged.passUnretained(event) }
    guard let nsEvent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
    guard nsEvent.type == .systemDefined, nsEvent.subtype.rawValue == NX_SUBTYPE_AUX_CONTROL_BUTTONS else {
      return Unmanaged.passUnretained(event)
    }
    let data1 = nsEvent.data1
    let keyType = (data1 >> 16) & 0xFF
    guard keyType == NX_KEYTYPE_SOUND_UP || keyType == NX_KEYTYPE_SOUND_DOWN else {
      return Unmanaged.passUnretained(event)
    }
    let keyState = (data1 >> 8) & 0xFF
    guard keyState == NX_KEYDOWN || keyState == NX_KEYUP else { return Unmanaged.passUnretained(event) }
    let isVolumeUp = keyType == NX_KEYTYPE_SOUND_UP
    if let handler = VolumeButtonHandler.activeHandler {
      if keyState == NX_KEYDOWN {
        handler.callbackChannel.onVolumeButtonPressed(isVolumeUp: isVolumeUp) { _ in }
      } else {
        handler.callbackChannel.onVolumeButtonReleased(isVolumeUp: isVolumeUp) { _ in }
      }
      if handler.showVolumeUi {
        return Unmanaged.passUnretained(event)
      }
    }
    return nil
  }

  func getVolume() throws -> Double {
    Double(Self.getSystemVolume())
  }

  func setVolume(volume: Double) throws {
    Self.setSystemVolume(Float(min(1, max(0, volume))))
  }

  private static func getSystemVolume() -> Float32 {
    let deviceID = getDefaultOutputDevice()
    return getVolume(deviceID: deviceID) ?? 0
  }

  private static func setSystemVolume(_ volume: Float32) {
    let deviceID = getDefaultOutputDevice()
    guard deviceID != kAudioObjectUnknown else { return }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    var vol = min(1, max(0, volume))
    let size = UInt32(MemoryLayout<Float32>.size)
    AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
  }

  private static func getDefaultOutputDevice() -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioDeviceID = kAudioObjectUnknown
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    _ = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )
    return deviceID
  }

  private static func getVolume(deviceID: AudioDeviceID) -> Float32? {
    guard deviceID != kAudioObjectUnknown else { return nil }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    var volume: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    let status = AudioObjectGetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      &size,
      &volume
    )
    return status == noErr ? volume : nil
  }
}
