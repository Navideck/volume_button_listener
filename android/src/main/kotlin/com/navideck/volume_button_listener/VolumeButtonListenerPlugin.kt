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

    // The interceptor this plugin installed as `window.callback`. Tracked
    // separately from `originalCallback` so `isListening()` can tell whether the
    // window still delegates to us, and `stopListener()` can avoid clobbering a
    // callback someone else installed in the meantime.
    private var interceptorCallback: Callback? = null
    private var showVolumeUi: Boolean = false

    // Set when the activity is detached while the listener was active, so it
    // can be re-installed on reattach. Without this the interceptor is torn
    // down and volume keys stop reaching the app for the rest of the session.
    private var restartListenerOnReattach: Boolean = false

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

        // Drop any previous interceptor first so wrappers never stack.
        if (interceptorCallback != null) {
            stopListener()
        }

        val delegate = currentActivity.window.callback
        originalCallback = delegate

        val interceptor = object : Callback by delegate {
            override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
                if (event?.action == KeyEvent.ACTION_DOWN || event?.action == KeyEvent.ACTION_UP) {
                    when (event.keyCode) {
                        KeyEvent.KEYCODE_VOLUME_UP -> {
                            mainThreadHandler?.post {
                                if (event.action == KeyEvent.ACTION_DOWN) {
                                    callbackChannel?.onVolumeButtonPressed(true) {}
                                } else {
                                    callbackChannel?.onVolumeButtonReleased(true) {}
                                }
                            }
                            return !showVolumeUi
                        }

                        KeyEvent.KEYCODE_VOLUME_DOWN -> {
                            mainThreadHandler?.post {
                                if (event.action == KeyEvent.ACTION_DOWN) {
                                    callbackChannel?.onVolumeButtonPressed(false) {}
                                } else {
                                    callbackChannel?.onVolumeButtonReleased(false) {}
                                }
                            }
                            return !showVolumeUi
                        }
                    }
                }
                return delegate.dispatchKeyEvent(event)
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

        interceptorCallback = interceptor
        currentActivity.window.callback = interceptor
    }

    override fun setShowVolumeUi(showVolumeUi: Boolean) {
        this.showVolumeUi = showVolumeUi
    }

    override fun stopListener() {
        val interceptor = interceptorCallback
        val currentActivity = activity
        val original = originalCallback
        // Only restore the previous callback if the window still delegates to
        // us; if something else replaced it, leave that in place.
        if (interceptor != null && currentActivity != null && original != null &&
            currentActivity.window.callback === interceptor
        ) {
            currentActivity.window.callback = original
        }
        // Clear state even when the activity is already gone, otherwise
        // isListening() would report a dead interceptor forever.
        interceptorCallback = null
        originalCallback = null
    }

    override fun isListening(): Boolean {
        // The window callback is the only thing that actually receives key
        // events, so report listening only while the window still delegates to
        // the interceptor we installed. A plain `originalCallback != null` check
        // would keep returning true after the host replaced `window.callback`
        // (e.g. Android XR moving input focus between surfaces/spaces), leaving
        // callers with an interceptor that never fires.
        val interceptor = interceptorCallback ?: return false
        return activity?.window?.callback === interceptor
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
        // Re-install the interceptor after any activity recreation if it was
        // listening before the detach.
        if (restartListenerOnReattach) {
            restartListenerOnReattach = false
            startListener()
        }
    }

    override fun onDetachedFromActivity() {
        // Capture this for every detach, not just configuration changes: a
        // plain destroy/recreate of the host activity otherwise drops the
        // interceptor, so volume keys never reach the app again. Use the
        // interceptor field rather than isListening(), which is false whenever
        // the host already replaced the window callback.
        if (interceptorCallback != null) {
            restartListenerOnReattach = true
        }
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
