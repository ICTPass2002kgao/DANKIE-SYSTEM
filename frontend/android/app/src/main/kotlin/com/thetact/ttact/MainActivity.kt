package com.thetact.ttact

// [FIX] Import the AudioService class
import com.ryanheise.audioservice.AudioServiceFragmentActivity

// [FIX] Extend AudioServiceFragmentActivity
// This replaces FlutterFragmentActivity but preserves the fragment functionality
// required by plugins like local_auth, while enabling background audio.
class MainActivity: AudioServiceFragmentActivity() {
}