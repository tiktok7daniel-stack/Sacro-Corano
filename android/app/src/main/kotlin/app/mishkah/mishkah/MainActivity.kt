package app.mishkah.mishkah

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity keeps the Flutter engine shared with the background
// playback service, so recitation continues with the screen off and can be
// controlled from the lock screen and headset buttons.
class MainActivity : AudioServiceActivity()
