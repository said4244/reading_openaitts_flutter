import 'dart:async';
import 'dart:convert';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import '../arabic_tts_reader.dart';
import 'utils/logger.dart';

class LiveKitAudioManager {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  RemoteParticipant? _ttsAgent;
  Completer<void>? _audioCompleter;
  bool _isConnected = false;
  StreamSubscription? _dataSubscription;

  Future<void> initialize() async {
    if (_isConnected) return;
    
    try {
      TTSLogger.info('Connecting to LiveKit for TTS');
      
      // Get connection token
      final token = await _getConnectionToken();
      
      // Create room
      _room = Room();
      
      // Set up event listeners
      _setupEventListeners();
      
      // Connect to room with audio receiving enabled
      await _room!.connect(
        token['url']!,
        token['token']!,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'flutter_tts_client',
          ),
          // Important: Enable audio playback
          defaultAudioCaptureOptions: AudioCaptureOptions(
            autoGainControl: true,
            echoCancellation: true,
            noiseSuppression: true,
          ),
        ),
      );
      
      _isConnected = true;
      TTSLogger.info('Connected to LiveKit room');
      
      // Wait for TTS agent to join
      await _waitForAgent();
      
    } catch (e) {
      TTSLogger.error('Failed to initialize LiveKit', e);
      rethrow;
    }
  }

  Future<Map<String, String>> _getConnectionToken() async {
    final url = ArabicTTSReader.tokenUrl;
    TTSLogger.debug('Fetching token from: $url');
    
    try {
      // Make single request without specifying room/identity
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'token': data['accessToken'],
          'url': data['url'],
          'room': data['room'],
          'identity': data['identity']
        };
      } else {
        throw Exception('Token server returned ${response.statusCode}');
      }
    } catch (e) {
      TTSLogger.error('Failed to get connection token', e);
      rethrow;
    }
  }

  void _setupEventListeners() {
    _listener = _room!.createListener();
    
    _listener!
      ..on<ParticipantConnectedEvent>((event) {
        TTSLogger.info('Participant connected: ${event.participant.identity}');
        
        // Check if this is an agent
        if (_isAgentParticipant(event.participant)) {
          _ttsAgent = event.participant as RemoteParticipant;
          TTSLogger.info('TTS agent identified: ${event.participant.identity}');
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        TTSLogger.info('Track subscribed: ${event.track.kind} from ${event.participant.identity}');
        
        // Handle audio tracks from the TTS agent
        if (event.participant == _ttsAgent && event.track.kind == TrackType.AUDIO) {
          TTSLogger.info('✅ Subscribed to TTS audio track');
          _handleAudioTrack(event.track as RemoteAudioTrack);
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.participant == _ttsAgent && event.track.kind == TrackType.AUDIO) {
          TTSLogger.info('Audio track unsubscribed');
        }
      })
      ..on<TrackPublishedEvent>((event) {
        TTSLogger.info('Track published: ${event.publication.kind} by ${event.participant.identity}');
        
        // Auto-subscribe to audio tracks from TTS agent
        if (event.participant == _ttsAgent && event.publication.kind == TrackType.AUDIO) {
          TTSLogger.info('TTS agent published audio track, subscribing...');
          event.publication.subscribe();
        }
      })
      ..on<DataReceivedEvent>((event) {
        try {
          final message = utf8.decode(event.data);
          final data = jsonDecode(message);
          
          TTSLogger.debug('Data received: $data');
          
          if (data['type'] == 'tts_complete') {
            if (_audioCompleter != null && !_audioCompleter!.isCompleted) {
              _audioCompleter!.complete();
            }
          }
        } catch (e) {
          TTSLogger.debug('Failed to parse data message: $e');
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (event.participant == _ttsAgent) {
          TTSLogger.warning('TTS agent disconnected');
          _ttsAgent = null;
        }
      });
  }

  void _handleAudioTrack(RemoteAudioTrack track) {
    // The audio track will automatically play through the device speakers
    // LiveKit handles audio routing automatically
    TTSLogger.info('Audio track is now playing');
    
    // You can control volume or other properties if needed
    // track.setVolume(1.0);
  }

  bool _isAgentParticipant(Participant participant) {
    final identity = participant.identity?.toLowerCase() ?? '';
    
    // More flexible agent detection
    return (identity.contains('tts') && identity.contains('agent')) ||
           identity.contains('agent') ||
           (identity != 'flutter-tts-client' && 
            participant is RemoteParticipant &&
            _room!.remoteParticipants.length == 1);
  }

  Future<void> _waitForAgent() async {
    if (_ttsAgent != null) return;
    
    // Check if agent is already in room
    for (final participant in _room!.remoteParticipants.values) {
      if (_isAgentParticipant(participant)) {
        _ttsAgent = participant as RemoteParticipant;
        TTSLogger.info('Found existing agent: ${participant.identity}');
        
        // Subscribe to any existing audio tracks
        for (final publication in participant.trackPublications.values) {
          if (publication.kind == TrackType.AUDIO && !publication.subscribed) {
            TTSLogger.info('Subscribing to existing audio track');
            await publication.subscribe();
          }
        }
        
        return;
      }
    }
    
    // Wait for agent to join with timeout
    TTSLogger.info('Waiting for TTS agent to join...');
    
    const maxWaitTime = Duration(seconds: 10);
    const checkInterval = Duration(milliseconds: 500);
    final endTime = DateTime.now().add(maxWaitTime);
    
    while (DateTime.now().isBefore(endTime)) {
      // Check again for agent
      for (final participant in _room!.remoteParticipants.values) {
        if (_isAgentParticipant(participant)) {
          _ttsAgent = participant as RemoteParticipant;
          TTSLogger.info('Agent joined: ${participant.identity}');
          return;
        }
      }
      
      await Future.delayed(checkInterval);
    }
    
    // If we get here, no agent joined
    TTSLogger.error('No TTS agent joined after ${maxWaitTime.inSeconds} seconds');
    TTSLogger.error('Remote participants: ${_room!.remoteParticipants.values.map((p) => p.identity).join(', ')}');
    
    throw Exception('TTS agent did not join room within timeout');
  }

  Future<void> requestTTS(String text) async {
    if (!_isConnected || _ttsAgent == null) {
      throw Exception('Not connected to TTS agent');
    }
    
    // Create new completer for this request
    _audioCompleter = Completer<void>();
    
    // Send TTS request to agent
    final message = jsonEncode({
      'type': 'tts_request',
      'text': text,
      'voice': 'alloy', // You can make this configurable
      'model': 'gpt-4o-mini-tts',
    });
    
    await _room!.localParticipant?.publishData(
      utf8.encode(message),
      reliable: true,
    );
    
    TTSLogger.info('Sent TTS request to agent');
  }

  Future<void> waitForCompletion() async {
    if (_audioCompleter != null && !_audioCompleter!.isCompleted) {
        await _audioCompleter!.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
                TTSLogger.warning('TTS request timed out');
            },
        );
        // Add delay after completion
        await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  Future<void> dispose() async {
    _dataSubscription?.cancel();
    _listener?.dispose();
    if (_room != null) {
      try {
        await _room!.disconnect();
        TTSLogger.info('Successfully disconnected from room');
      } catch (e) {
        TTSLogger.error('Error disconnecting from room', e);
      }
    }
    _room = null;
    _ttsAgent = null;
    _isConnected = false;
  }
}