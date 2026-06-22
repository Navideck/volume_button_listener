import Flutter

public class VolumeButtonListenerPlugin: NSObject, FlutterPlugin, VolumeButtonListenerPlatformChannel {
  private let callbackChannel: VolumeButtonListenerCallbackChannel
  private let listener: VolumeButtonListener

  public static func register(with registrar: FlutterPluginRegistrar) {
    let callbackChannel = VolumeButtonListenerCallbackChannel(binaryMessenger: registrar.messenger())
    let api = VolumeButtonListenerPlugin(callbackChannel: callbackChannel, listener: VolumeButtonListener())
    VolumeButtonListenerPlatformChannelSetup.setUp(binaryMessenger: registrar.messenger(), api: api)
  }

  init(callbackChannel: VolumeButtonListenerCallbackChannel, listener: VolumeButtonListener) {
    self.callbackChannel = callbackChannel
    self.listener = listener
    super.init()
  }

  deinit {
    detachCallbacks()
    listener.pause()
  }

  func startListener() throws {
    attachCallbacks()
    try listener.resume()
  }

  func stopListener() throws {
    detachCallbacks()
    listener.pause()
  }

  func isListening() throws -> Bool {
    listener.listening()
  }

  func setShowVolumeUi(showVolumeUi: Bool) throws {
    listener.showsVolumeUi = showVolumeUi
  }

  func getVolume() throws -> Double {
    listener.getVolume()
  }

  func setVolume(volume: Double) throws {
    listener.setVolume(volume)
  }

  private func attachCallbacks() {
    listener.volumeButtonPressed = { [weak self] button in
      self?.callbackChannel.onVolumeButtonPressed(isVolumeUp: button == .up) { _ in }
    }
    listener.volumeButtonReleased = { [weak self] button in
      self?.callbackChannel.onVolumeButtonReleased(isVolumeUp: button == .up) { _ in }
    }
  }

  private func detachCallbacks() {
    listener.volumeButtonPressed = nil
    listener.volumeButtonReleased = nil
  }
}
