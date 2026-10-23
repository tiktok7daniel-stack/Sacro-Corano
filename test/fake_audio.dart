import 'dart:async';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// In-memory just_audio backend: "plays" instantly and lets tests move the
/// current index to simulate the reciter advancing.
class FakeJustAudio extends JustAudioPlatform with MockPlatformInterfaceMixin {
  final players = <String, FakePlayer>{};

  FakePlayer get last => players.values.last;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => players[request.id] = FakePlayer(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    players.remove(request.id);
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async {
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

class FakePlayer extends AudioPlayerPlatform {
  FakePlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  int count = 0;
  int index = 0;
  bool playing = false;
  double speed = 1;
  final uris = <String>[];

  void _emit(ProcessingStateMessage s) => _events.add(PlaybackEventMessage(
        processingState: s,
        updateTime: DateTime.now(),
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: const Duration(seconds: 5),
        icyMetadata: null,
        currentIndex: index,
        androidAudioSessionId: null,
      ));

  /// Simulates the end of the current verse.
  void advance() {
    if (index < count - 1) index++;
    _emit(ProcessingStateMessage.ready);
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final src = request.audioSourceMessage;
    uris.clear();
    if (src is ConcatenatingAudioSourceMessage) {
      for (final c in src.children) {
        if (c is UriAudioSourceMessage) uris.add(c.uri);
      }
    } else if (src is UriAudioSourceMessage) {
      uris.add(src.uri);
    }
    count = uris.length;
    index = request.initialIndex ?? 0;
    _emit(ProcessingStateMessage.ready);
    return LoadResponse(duration: const Duration(seconds: 5));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playing = true;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    playing = false;
    return PauseResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    speed = request.speed;
    return SetSpeedResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async => SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(SetShuffleOrderRequest request) async => SetShuffleOrderResponse();
  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse> setAutomaticallyWaitsToMinimizeStalling(
          SetAutomaticallyWaitsToMinimizeStallingRequest request) async =>
      SetAutomaticallyWaitsToMinimizeStallingResponse();
  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse> setCanUseNetworkResourcesForLiveStreamingWhilePaused(
          SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request) async =>
      SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(SetPreferredPeakBitRateRequest request) async =>
      SetPreferredPeakBitRateResponse();
  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(SetAllowsExternalPlaybackRequest request) async =>
      SetAllowsExternalPlaybackResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(SetAndroidAudioAttributesRequest request) async =>
      SetAndroidAudioAttributesResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    if (request.index != null) index = request.index!;
    _emit(ProcessingStateMessage.ready);
    return SeekResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _events.close();
    return DisposeResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(ConcatenatingInsertAllRequest request) async =>
      ConcatenatingInsertAllResponse();
  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(ConcatenatingRemoveRangeRequest request) async =>
      ConcatenatingRemoveRangeResponse();
  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(ConcatenatingMoveRequest request) async => ConcatenatingMoveResponse();
}
