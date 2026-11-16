package com.navideck.volume_button_listener

import android.app.Activity
import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry.WindowFocusChangedListener
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
    private var useVolumeEvents: Boolean = false
    private var volumeButtonListener: VolumeButtonListener? = null

    // Whether the activity window currently has input focus. `volumeEvents`
    // mode observes the system audio stream, so it must be suspended while the
    // panel is unfocused or it would report (and revert) volume changes made by
    // other panels and the system.
    private var windowHasFocus: Boolean = false

    // Set when the activity is detached while the listener was active, so it
    // can be re-installed on reattach. Without this the interceptor is torn
    // down and volume keys stop reaching the app for the rest of the session.
    private var restartListenerOnReattach: Boolean = false

    // Window focus is the earliest signal that this activity can receive key
    // events again. Used to recover when the host replaces `window.callback`
    // while the activity stays alive.
    private var activityBinding: ActivityPluginBinding? = null
    private var windowFocusListener: WindowFocusChangedListener? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        VolumeButtonListenerPlatformChannel.setUp(flutterPluginBinding.binaryMessenger, this)
        callbackChannel = VolumeButtonListenerCallbackChannel(flutterPluginBinding.binaryMessenger)
        mainThreadHandler = Handler(Looper.getMainLooper())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Tear down anything that outlives the engine. In volumeEvents mode the
        // kit would otherwise keep observing (and reverting) system volume with
        // no channel left to report to.
        stopListener()
        VolumeButtonListenerPlatformChannel.setUp(binding.binaryMessenger, null)
        callbackChannel = null
        mainThreadHandler = null
        applicationContext = null
    }

    override fun setAndroidListeningMode(useVolumeEvents: Boolean) {
        android.util.Log.d("VolumeButtonKit", "setAndroidListeningMode(useVolumeEvents=$useVolumeEvents), current=$this.useVolumeEvents")
        if (this.useVolumeEvents == useVolumeEvents) return
        val wasActive = interceptorCallback != null || volumeButtonListener != null
        if (wasActive) {
            stopListener()
        }
        this.useVolumeEvents = useVolumeEvents
        if (wasActive) {
            startListener()
        }
    }

    override fun startListener() {
        android.util.Log.d("VolumeButtonKit", "startListener() useVolumeEvents=$useVolumeEvents")
        if (useVolumeEvents) {
            val ctx = applicationContext ?: activity
                ?: throw Exception("Context is null. VolumeButtonListenerPlugin requires an application context or activity.")
            // Reuse an existing kit so repeated start calls keep the learned
            // baseline instead of restarting from the current stream volume.
            val kitListener = volumeButtonListener ?: VolumeButtonListener(ctx, mainThreadHandler).apply {
                this.showsVolumeUi = this@VolumeButtonListenerPlugin.showVolumeUi
                this.volumeButtonPressed = { direction ->
                    mainThreadHandler?.post {
                        callbackChannel?.onVolumeButtonPressed(direction == VolumeButtonDirection.UP) {}
                    }
                }
                this.volumeButtonReleased = { direction ->
                    mainThreadHandler?.post {
                        callbackChannel?.onVolumeButtonReleased(direction == VolumeButtonDirection.UP) {}
                    }
                }
            }.also { volumeButtonListener = it }

            if (windowHasFocus) {
                kitListener.resume()
                kitListener.startListening()
            } else {
                kitListener.pause()
            }
            return
        }

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
        volumeButtonListener?.showsVolumeUi = showVolumeUi
    }

    override fun stopListener() {
        volumeButtonListener?.stopListening()
        volumeButtonListener = null

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
        if (useVolumeEvents) {
            // Report the listener as active while it is suspended on focus
            // loss: reporting false would make the Dart layer treat it as dead
            // and either restart it or, worse, never stop it when the last
            // listener is removed while the panel is unfocused.
            return volumeButtonListener != null
        }
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
        // In volumeEvents mode the kit is the source of truth: it tracks the
        // neutral baseline the volume is reverted to.
        if (useVolumeEvents) {
            volumeButtonListener?.let { return it.getVolume() }
        }
        val ctx = applicationContext ?: return 0.0
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return 0.0
        val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return (current.toDouble() / max).coerceIn(0.0, 1.0)
    }

    override fun setVolume(volume: Double) {
        // Route through the kit in volumeEvents mode: it records the new
        // baseline and ignores the resulting observer callback, so an
        // app-initiated change is neither reported as a button press nor
        // reverted as if it came from a physical button.
        if (useVolumeEvents) {
            volumeButtonListener?.let {
                it.setVolume(volume)
                return
            }
        }
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

    /**
     * Re-installs the interceptor when the window stopped delegating to it but
     * the plugin is still supposed to be listening. Called on window focus
     * gain, which is when a host that replaced `window.callback` is ready to
     * deliver key events again.
     */
    private fun restartListenerIfReplaced() {
        if (useVolumeEvents) return
        if (interceptorCallback == null) return
        if (activity == null) return
        if (isListening()) return
        startListener()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // Defensive: drop a listener left from a previous binding so repeated
        // attach calls never stack callbacks.
        windowFocusListener?.let { old -> activityBinding?.removeOnWindowFocusChangedListener(old) }
        activity = binding.activity
        activityBinding = binding
        windowHasFocus = binding.activity.hasWindowFocus()
        // Focus can move between surfaces or spaces without recreating the
        // activity (2D panels on Horizon OS and Android XR both do this) and
        // give `window.callback` back to the host. Re-install the interceptor
        // when focus returns so volume keys reach the app again.
        val focusListener = WindowFocusChangedListener { hasFocus ->
            windowHasFocus = hasFocus
            if (useVolumeEvents) {
                // The kit observes the system audio stream rather than key
                // events, so it has to be suspended explicitly while the panel
                // is unfocused.
                if (hasFocus) {
                    volumeButtonListener?.let { kit ->
                        kit.resume()
                        kit.startListening()
                    }
                } else {
                    volumeButtonListener?.pause()
                }
            } else if (hasFocus) {
                restartListenerIfReplaced()
            }
        }
        windowFocusListener = focusListener
        binding.addOnWindowFocusChangedListener(focusListener)
        // Re-install the interceptor after any activity recreation if it was
        // listening before the detach.
        if (restartListenerOnReattach) {
            restartListenerOnReattach = false
            startListener()
        }
    }

    override fun onDetachedFromActivity() {
        windowFocusListener?.let { listener ->
            activityBinding?.removeOnWindowFocusChangedListener(listener)
        }
        windowFocusListener = null
        activityBinding = null
        windowHasFocus = false
        // Capture this for every detach, not just configuration changes: a
        // plain destroy/recreate of the host activity otherwise drops the
        // interceptor, so volume keys never reach the app again. Use the
        // interceptor field rather than isListening(), which is false whenever
        // the host already replaced the window callback.
        if (interceptorCallback != null || volumeButtonListener != null) {
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
