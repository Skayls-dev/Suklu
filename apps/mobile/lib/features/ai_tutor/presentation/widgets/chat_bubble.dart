import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/data_saver_provider.dart';
import '../../domain/chat_models.dart';
import 'typing_indicator.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({required this.message, super.key});

  final ChatMessage message;

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    if (!isUser && message.content.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const TypingIndicator(),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
              if (!isUser && message.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...message.images.map((img) => _ImageChunkWidget(imageRef: img)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageChunkWidget extends ConsumerStatefulWidget {
  const _ImageChunkWidget({required this.imageRef});

  final ChatImageRef imageRef;

  @override
  ConsumerState<_ImageChunkWidget> createState() => _ImageChunkWidgetState();
}

class _ImageChunkWidgetState extends ConsumerState<_ImageChunkWidget> {
  bool _loadImage = false;

  @override
  Widget build(BuildContext context) {
    final dataSaverEnabled = ref.watch(dataSaverProvider);

    if (dataSaverEnabled && !_loadImage) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: () => setState(() => _loadImage = true),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined),
                SizedBox(height: 6),
                Text('Schéma disponible — Appuyer pour charger'),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _FullScreenImageViewer(imageRef: widget.imageRef),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: widget.imageRef.url,
                fit: BoxFit.contain,
                width: double.infinity,
                placeholder: (_, __) => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade200,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported, color: Colors.grey.shade600),
                      const SizedBox(height: 6),
                      Text(
                        'Schéma non disponible',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.imageRef.caption.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.imageRef.caption,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.imageRef});

  final ChatImageRef imageRef;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(imageUrl: imageRef.url),
        ),
      ),
    );
  }
}
