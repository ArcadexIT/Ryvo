import 'package:audioplayers/audioplayers.dart';

class JobAlertSound {
  JobAlertSound._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playIncomingJob() async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/notification_tone.mp3'));
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
