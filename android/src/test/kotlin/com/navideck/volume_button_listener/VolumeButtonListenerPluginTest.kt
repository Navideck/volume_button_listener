package com.navideck.volume_button_listener

import android.app.Activity
import android.view.Window
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry.WindowFocusChangedListener
import org.mockito.Mockito
import org.mockito.Mockito.`when`
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/*
 * Exercises the Android interceptor bookkeeping behind [isListening],
 * [stopListener], and focus recovery without an emulator. The window callback
 * is the only thing that actually receives key events, so "listening" must mean
 * "the window still delegates to our interceptor", not merely "we once
 * installed one".
 *
 * Run with `./gradlew testDebugUnitTest` from `example/android/`.
 */

internal class VolumeButtonListenerPluginTest {

    private class Fixture {
        val activity: Activity = Mockito.mock(Activity::class.java)
        val window: Window = Mockito.mock(Window::class.java)
        val delegate: Window.Callback = Mockito.mock(Window.Callback::class.java)
        val binding: ActivityPluginBinding = Mockito.mock(ActivityPluginBinding::class.java)
        var installed: Window.Callback? = null
        var focusListener: WindowFocusChangedListener? = null

        init {
            `when`(activity.window).thenReturn(window)
            `when`(window.callback).thenReturn(delegate)
            Mockito.doAnswer { invocation ->
                installed = invocation.getArgument(0) as Window.Callback
                null
            }.`when`(window).setCallback(Mockito.any(Window.Callback::class.java))
            `when`(binding.activity).thenReturn(activity)
            Mockito.doAnswer { invocation ->
                focusListener = invocation.getArgument(0) as WindowFocusChangedListener
                null
            }.`when`(binding)
                .addOnWindowFocusChangedListener(Mockito.any(WindowFocusChangedListener::class.java))
        }

        fun plugin(): VolumeButtonListenerPlugin {
            return VolumeButtonListenerPlugin().also { it.onAttachedToActivity(binding) }
        }

        /** Simulates the host replacing `window.callback` with its own. */
        fun clobber(callback: Window.Callback) {
            `when`(window.callback).thenReturn(callback)
        }

        /** Makes `window.callback` report whatever was installed. */
        fun acceptInstalled() {
            installed?.let { `when`(window.callback).thenReturn(it) }
        }

        /** Delivers a window focus change like the host activity would. */
        fun focus(hasFocus: Boolean) {
            focusListener?.onWindowFocusChanged(hasFocus)
        }
    }

    @Test
    fun isListening_isFalseBeforeStart() {
        assertFalse(Fixture().plugin().isListening())
    }

    @Test
    fun isListening_isTrueWhileWindowDelegatesToInterceptor() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()

        assertTrue(plugin.isListening())
    }

    @Test
    fun isListening_isFalseAfterWindowCallbackIsReplaced() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()
        assertTrue(plugin.isListening())

        // The host installs its own callback over ours (as Android XR does when
        // it moves input focus between surfaces or spaces).
        fixture.clobber(Mockito.mock(Window.Callback::class.java))

        assertFalse(plugin.isListening())
    }

    @Test
    fun focusGain_reinstallsInterceptorAfterHostReplacedCallback() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()
        fixture.clobber(Mockito.mock(Window.Callback::class.java))
        assertFalse(plugin.isListening())

        // Focus returns to the panel (Horizon OS / Android XR): the plugin must
        // take the window callback again instead of staying dead.
        fixture.focus(true)
        fixture.acceptInstalled()

        assertTrue(plugin.isListening())
    }

    @Test
    fun focusGain_doesNotStartListeningWhenNeverStarted() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        fixture.focus(true)

        assertFalse(plugin.isListening())
        Mockito.verify(fixture.window, Mockito.never())
            .setCallback(Mockito.any(Window.Callback::class.java))
    }

    @Test
    fun focusGain_doesNothingAfterStopListener() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()
        plugin.stopListener()

        fixture.focus(true)

        assertFalse(plugin.isListening())
    }

    @Test
    fun detach_removesWindowFocusListener() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.onDetachedFromActivity()

        Mockito.verify(fixture.binding).removeOnWindowFocusChangedListener(
            Mockito.any(WindowFocusChangedListener::class.java),
        )
    }

    @Test
    fun stopListener_clearsStateEvenWhenTheInterceptorWasReplaced() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.clobber(Mockito.mock(Window.Callback::class.java))

        plugin.stopListener()

        assertFalse(plugin.isListening())
        // Must not overwrite the callback that replaced ours.
        Mockito.verify(fixture.window, Mockito.never()).setCallback(fixture.delegate)
    }

    @Test
    fun stopListener_restoresOriginalCallbackWhileStillInstalled() {
        val fixture = Fixture()
        val plugin = fixture.plugin()

        plugin.startListener()
        fixture.acceptInstalled()

        plugin.stopListener()

        Mockito.verify(fixture.window).setCallback(fixture.delegate)
        assertFalse(plugin.isListening())
    }
}
