class ChatImageRef {
  const ChatImageRef({required this.url, required this.caption});

  final String url;
  final String caption;
}

class ChatMessage {
  const ChatMessage({required this.role, required this.content, this.images = const []});

  final String role; // 'user' | 'assistant'
  final String content;
  final List<ChatImageRef> images;

  Map<String, String> toMap() => {'role': role, 'content': content};

  ChatMessage copyWith({String? role, String? content, List<ChatImageRef>? images}) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      images: images ?? this.images,
    );
  }
}

(String, List<ChatImageRef>) parseImageReferences(String rawText) {
  final imagePattern = RegExp(r'\[IMAGE:(https?://[^\]]+)\]');
  final images = <ChatImageRef>[];
  var cleanText = rawText;

  for (final match in imagePattern.allMatches(rawText)) {
    final url = match.group(1)!;
    final afterMatch = rawText.substring(match.end).trimLeft();
    final captionEnd = afterMatch.indexOf('\n');
    final caption = captionEnd == -1 ? afterMatch : afterMatch.substring(0, captionEnd);
    images.add(ChatImageRef(url: url, caption: caption.trim()));
    cleanText = cleanText.replaceFirst(match.group(0)!, '');
  }

  return (cleanText.trim(), images);
}
