import 'package:flutter/material.dart';
import 'package:arabic_tts_reader/arabic_tts_reader.dart';
import 'package:livekit_client/livekit_client.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  // Configure the token URL
  ArabicTTSReader.initialize(tokenUrl: 'http://localhost:8080/token');
  
  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiveKit Debug',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DebugScreen(),
    );
  }
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final List<String> _logs = [];
  bool _isConnecting = false;
  Timer? _participantCheckTimer;

  void _log(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.add('[$timestamp] $message');
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });
    print(message);
  }

  Future<void> _checkToken() async {
    _log('Checking token server...');
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/debug'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Token server OK: ${data}');
      } else {
        _log('Token server error: ${response.statusCode}');
      }
    } catch (e) {
      _log('Failed to reach token server: $e');
    }
  }

  Future<void> _connectToRoom() async {
    if (_isConnecting) return;
    
    setState(() => _isConnecting = true);
    
    try {
      await _checkToken();
      
      _log('Getting connection token...');
      final tokenResponse = await http.get(
        Uri.parse('http://localhost:8080/token').replace(queryParameters: {
          'room': 'tts-reading-room',
          'identity': 'debug-flutter-client',
        }),
      );
      
      if (tokenResponse.statusCode != 200) {
        _log('Token request failed: ${tokenResponse.statusCode} - ${tokenResponse.body}');
        return;
      }
      
      final tokenData = jsonDecode(tokenResponse.body);
      final token = tokenData['accessToken'] ?? tokenData['token'];
      final url = tokenData['url'] ?? 'wss://cloud.livekit.io';
      
      _log('Got token, URL: $url');
      _log('Room: ${tokenData['room']}');
      
      // Create room
      _room = Room();
      
      // Set up listeners
      _listener = _room!.createListener();
      _listener!
        ..on<ParticipantConnectedEvent>((event) {
          _log('✅ Participant connected: ${event.participant.identity} (${event.participant.sid})');
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          _log('❌ Participant disconnected: ${event.participant.identity}');
        })
        ..on<RoomDisconnectedEvent>((event) {
          _log('Room disconnected: ${event.reason}');
        })
        ..on<TrackPublishedEvent>((event) {
          _log('Track published by ${event.participant.identity}: ${event.publication.kind}');
        });
      
      _log('Connecting to LiveKit...');
      await _room!.connect(
        url,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      _log('✅ Connected! Local participant: ${_room!.localParticipant?.identity}');
      _log('Room name: ${_room!.name}');
      _log('Remote participants: ${_room!.remoteParticipants.length}');
      
      // List all participants
      for (final participant in _room!.remoteParticipants.values) {
        _log('  - ${participant.identity} (${participant.sid})');
      }
      
      // Start periodic check
      _participantCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _log('Checking participants... Count: ${_room!.remoteParticipants.length}');
        for (final participant in _room!.remoteParticipants.values) {
          _log('  - ${participant.identity}');
        }
      });
      
    } catch (e, stack) {
      _log('❌ Error: $e');
      _log('Stack: $stack');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    _participantCheckTimer?.cancel();
    _listener?.dispose();
    await _room?.disconnect();
    _room = null;
    _log('Disconnected');
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiveKit Connection Debug'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _isConnecting ? null : _connectToRoom,
                  child: Text(_room != null ? 'Reconnect' : 'Connect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _room != null ? _disconnect : null,
                  child: const Text('Disconnect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _logs.clear()),
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
          ),
          if (_room != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.green.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Room: ${_room!.name}'),
                  Text('Local: ${_room!.localParticipant?.identity}'),
                  Text('Remote Participants: ${_room!.remoteParticipants.length}'),
                ],
              ),
            ),
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}