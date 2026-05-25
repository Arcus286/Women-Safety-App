package com.example.coolapp

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // ── Channel name must match exactly what Dart uses
    private val CHANNEL = "com.example.coolapp/wakeword"

    // ── Only "help" triggers SOS — checked as a whole word to avoid
    //    false positives from words like "helpful", "shelter", "helping"
    private val TRIGGER_WORD = "recon"

    private var speechRecognizer: SpeechRecognizer? = null
    private var methodChannel: MethodChannel? = null
    private var isListening = false
    private var shouldRestart = true

    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Delay before restarting recognizer after it stops (ms)
    private val RESTART_DELAY_MS = 300L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        // Handle calls from Dart → Kotlin
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    shouldRestart = true
                    startSpeechRecognizer()
                    result.success(null)
                }
                "stopListening" -> {
                    shouldRestart = false
                    stopSpeechRecognizer()
                    result.success(null)
                }
                "isAvailable" -> {
                    result.success(
                        SpeechRecognizer.isRecognitionAvailable(this)
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    // ────────────────────────────────────────────────
    // Start / stop
    // ────────────────────────────────────────────────

    private fun startSpeechRecognizer() {
        if (isListening) return
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            notifyFlutter("error", "Speech recognition not available on this device")
            return
        }

        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer!!.setRecognitionListener(recognitionListener)
        beginListening()
    }

    private fun stopSpeechRecognizer() {
        isListening = false
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun beginListening() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            // Shorter minimum so a single screamed word registers quickly
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 800L)
            // Longer silence window gives time for a screamed word to be processed
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            // Partial results catch the trigger word faster
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        isListening = true
        speechRecognizer?.startListening(intent)
    }

    // ── Auto-restart after the recognizer naturally times out
    private fun scheduleRestart() {
        if (!shouldRestart) return
        mainHandler.postDelayed({
            if (shouldRestart && !isListening) {
                startSpeechRecognizer()
            }
        }, RESTART_DELAY_MS)
    }

    // ────────────────────────────────────────────────
    // Check recognised text for the "help" trigger word.
    // Uses word-boundary splitting so "helpful" / "shelter"
    // do NOT fire a false positive.
    // ────────────────────────────────────────────────

    private fun checkForTrigger(text: String) {
        val lower = text.lowercase().trim()
        // Split on any non-letter character to get individual words
        val words = lower.split("[^a-z]+".toRegex()).filter { it.isNotEmpty() }
        val matched = words.any { it == TRIGGER_WORD }
        if (matched) {
            shouldRestart = false   // stop listening once triggered
            stopSpeechRecognizer()
            notifyFlutter("triggered", lower)
        }
    }

    // ────────────────────────────────────────────────
    // Send event back to Dart
    // ────────────────────────────────────────────────

    private fun notifyFlutter(event: String, data: String = "") {
        mainHandler.post {
            methodChannel?.invokeMethod(event, data)
        }
    }

    // ────────────────────────────────────────────────
    // RecognitionListener
    // ────────────────────────────────────────────────

    private val recognitionListener = object : RecognitionListener {

        override fun onReadyForSpeech(params: Bundle?) {
            notifyFlutter("status", "listening")
        }

        override fun onPartialResults(partialResults: Bundle?) {
            // Check partial results immediately — catches "help" faster
            val partial = partialResults
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull() ?: return
            checkForTrigger(partial)
        }

        override fun onResults(results: Bundle?) {
            isListening = false
            val matches = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?: emptyList<String>()
            // Check all candidate results
            for (result in matches) {
                checkForTrigger(result)
                if (!shouldRestart) return   // already triggered
            }
            // No trigger found — restart and keep listening
            scheduleRestart()
        }

        override fun onError(error: Int) {
            isListening = false
            when (error) {
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                SpeechRecognizer.ERROR_CLIENT -> scheduleRestart()

                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> {
                    // Destroy and recreate to clear the busy state
                    speechRecognizer?.destroy()
                    speechRecognizer = null
                    isListening = false
                    mainHandler.postDelayed({ startSpeechRecognizer() }, 1000L)
                }

                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                    notifyFlutter("error", "Microphone permission denied")
                }

                else -> {
                    notifyFlutter("error", "Recognizer error code: $error")
                    scheduleRestart()
                }
            }
        }

        // ── Required by the interface
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() { isListening = false }
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    // ────────────────────────────────────────────────
    // Lifecycle — stop recognizer when app is destroyed
    // ────────────────────────────────────────────────

    override fun onDestroy() {
        shouldRestart = false
        stopSpeechRecognizer()
        super.onDestroy()
    }
}