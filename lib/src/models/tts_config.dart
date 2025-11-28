enum TTSVoice {
  alloy('alloy'),
  ash('ash'),
  ballad('ballad'),
  coral('coral'),
  echo('echo'),
  fable('fable'),
  nova('nova'),
  onyx('onyx'),
  sage('sage'),
  shimmer('shimmer');

  final String value;
  const TTSVoice(this.value);
}

class TTSConfig {
  final String model;
  final TTSVoice voice;
  final String? instructions;
  final String responseFormat;

  const TTSConfig({
    this.model = 'gpt-4o-mini-tts',
    this.voice = TTSVoice.alloy,
    this.instructions,
    this.responseFormat = 'pcm',
  });

  Map<String, dynamic> toJson() => {
    'model': model,
    'voice': voice.value,
    if (instructions != null) 'instructions': instructions,
    'response_format': responseFormat,
  };
}