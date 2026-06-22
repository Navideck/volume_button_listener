package com.navideck.volume_button_listener

import android.app.Activity
import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import android.view.KeyEvent
import android.view.KeyboardShortcutGroup
import android.view.Menu
import android.view.Window.Callback

class VolumeButtonListenerPlugin : FlutterPlugin, VolumeButtonListenerPlatformChannel,
    ActivityAware {
    private var callbackChannel: VolumeButtonListenerCallbackChannel? = null
    private var mainThreadHandler: Handler? = null
    private var activity: Activity? = null
    private var applicationContext: Context? = null
    private var originalCallback: Callback? = null
    private var showVolumeUi: Boolean = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        VolumeButtonListenerPlatformChannel.setUp(flutterPluginBinding.binaryMessenger, this)
        callbackChannel = VolumeButtonListenerCallbackChannel(flutterPluginBinding.binaryMessenger)
        mainThreadHandler = Handler(Looper.getMainLooper())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        VolumeButtonListenerPlatformChannel.setUp(binding.binaryMessenger, null)
        callbackChannel = null
        mainThreadHandler = null
        applicationContext = null
    }

    override fun startListener() {
        val currentActivity = activity
            ?: throw Exception("Activity is null. VolumeButtonListenerPlugin requires a foreground activity.")

        if (originalCallback != null) {
            stopListener()
        }

        originalCallback = currentActivity.window.callback

        currentActivity.window.callback =
            object : Callback by originalCallback as Callback {
                override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
                    if (event?.action == KeyEvent.ACTION_DOWN || event?.action == KeyEvent.ACTION_UP) {
                        when (event.keyCode) {
                            KeyEvent.KEYCODE_VOLUME_UP -> {
                                mainThreadHandler?.post {
                                    if (event?.action == KeyEvent.ACTION_DOWN) {
                                        callbackChannel?.onVolumeButtonPressed(true) {}
                                    } else {
                                        callbackChannel?.onVolumeButtonReleased(true) {}
                                    }
                                }
                                return !showVolumeUi
                            }

                            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                                mainThreadHandler?.post {
                                    if (event?.action == KeyEvent.ACTION_DOWN) {
                                        callbackChannel?.onVolumeButtonPressed(false) {}
                                    } else {
                                        callbackChannel?.onVolumeButtonReleased(false) {}
                                    }
                                }
                                return !showVolumeUi
                            }
                        }
                    }
                    return originalCallback?.dispatchKeyEvent(event) ?: false
                }

                override fun onPointerCaptureChanged(hasCapture: Boolean) {
                    super.onPointerCaptureChanged(hasCapture)
                }

                override fun onProvideKeyboardShortcuts(
                    data: List<KeyboardShortcutGroup?>?,
                    menu: Menu?,
                    deviceId: Int,
                ) {
                    super.onProvideKeyboardShortcuts(data, menu, deviceId)
                }
            }
    }

    override fun setShowVolumeUi(showVolumeUi: Boolean) {
        this.showVolumeUi = showVolumeUi
    }

    override fun stopListener() {
        if (originalCallback != null && activity != null) {
            activity?.window?.callback = originalCallback
            originalCallback = null
        }
    }

    override fun isListening(): Boolean {
        return originalCallback != null
    }

    override fun getVolume(): Double {
        val ctx = applicationContext ?: return 0.0
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return 0.0
        val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return (current.toDouble() / max).coerceIn(0.0, 1.0)
    }

    override fun setVolume(volume: Double) {
        val ctx = applicationContext ?: return
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val index = (volume.coerceIn(0.0, 1.0) * max).toInt().coerceIn(0, max)
        am.setStreamVolume(
            AudioManager.STREAM_MUSIC,
            index,
            AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE
        )
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        stopListener()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}
