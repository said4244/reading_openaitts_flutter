import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../tts_service.dart';
import '../utils/logger.dart';

class ReadingText extends StatefulWidget {
  final Text child;
  
  const ReadingText({
    super.key,
    required this.child,
  });

  @override
  State<ReadingText> createState() => _ReadingTextState();
}

class _ReadingTextState extends State<ReadingText> {
  late final TTSService _ttsService;
  String? _selectedText;
  bool _isPlaying = false;

  // Add hover tracking
  String? _hoveredText;
  
  @override
  void initState() {
    super.initState();
    _ttsService = TTSService();
    _ttsService.initialize();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  void _handleTextSelection(String text) async {
    if (_isPlaying) return;
    
    setState(() {
      _selectedText = text;
      _isPlaying = true;
    });

    TTSLogger.info('User selected text: $text');
    
    try {
      await _ttsService.speak(text);
    } catch (e) {
      TTSLogger.error('Failed to speak text', e);
    } finally {
      setState(() {
        _isPlaying = false;
        _selectedText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: _buildInteractiveText(widget.child.data ?? ''),
      textAlign: widget.child.textAlign ?? TextAlign.start,
      textDirection: widget.child.textDirection,
    );
  }

  List<_TextSegment> _splitIntoPhrases(String text) {
    final segments = <_TextSegment>[];
    final sentenceDelimiters = [',', '،', '.', '؟', '!', '\n'];
    
    var buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      
      if (sentenceDelimiters.contains(char)) {
        if (buffer.isNotEmpty) {
          segments.add(_TextSegment(buffer.toString().trim(), false));
          buffer.clear();
        }
        segments.add(_TextSegment(char, true));
      } else {
        buffer.write(char);
      }
    }
    
    if (buffer.isNotEmpty) {
      segments.add(_TextSegment(buffer.toString().trim(), false));
    }
    
    return segments;
  }

  TextSpan _buildInteractiveText(String text) {
    final segments = _splitIntoPhrases(text);
    final spans = <TextSpan>[];
    
    for (var segment in segments) {
      if (segment.isPunctuation) {
        spans.add(TextSpan(
          text: segment.text,
          style: widget.child.style,
        ));
      } else {
        spans.add(TextSpan(
          text: segment.text,
          style: TextStyle(
            fontSize: widget.child.style?.fontSize,
            height: widget.child.style?.height,
            fontFamily: widget.child.style?.fontFamily,
            color: _selectedText == segment.text 
                ? Colors.blue 
                : _hoveredText == segment.text
                    ? Colors.blue.withOpacity(0.7)
                    : null,
            backgroundColor: _selectedText == segment.text 
                ? Colors.blue.withOpacity(0.1)
                : _hoveredText == segment.text
                    ? Colors.blue.withOpacity(0.05)
                    : null,
          ),
          mouseCursor: MaterialStateMouseCursor.clickable,
          onEnter: (_) => setState(() => _hoveredText = segment.text),
          onExit: (_) => setState(() => _hoveredText = null),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleTextSelection(segment.text),
        ));
      }
    }
    
    return TextSpan(children: spans);
  }
}

class _TextSegment {
  final String text;
  final bool isPunctuation;
  
  const _TextSegment(this.text, this.isPunctuation);
}