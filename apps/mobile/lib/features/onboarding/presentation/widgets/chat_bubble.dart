import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class ChatBubble extends StatefulWidget {
  const ChatBubble({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    super.key,
  });

  final String text;
  final bool isUser;
  final bool isLoading;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  Timer? _timer;
  int _dotCount = 1;

  List<Widget> _buildLoadingDots() {
    return List<Widget>.generate(3, (index) {
      final isActive = index < _dotCount;
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isActive ? 1 : 0.25,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.grey600,
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
        if (!mounted) return;
        setState(() => _dotCount = _dotCount % 3 + 1);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading == oldWidget.isLoading) return;

    _timer?.cancel();
    _timer = null;

    if (widget.isLoading) {
      _dotCount = 1;
      _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
        if (!mounted) return;
        setState(() => _dotCount = _dotCount % 3 + 1);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.75;

    final userRadius = BorderRadius.circular(16).copyWith(
      topRight: const Radius.circular(4),
    );
    final assistantRadius = BorderRadius.circular(16).copyWith(
      topLeft: const Radius.circular(4),
    );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isUser ? AppColors.primary : Colors.grey.shade100,
        borderRadius: widget.isUser ? userRadius : assistantRadius,
      ),
      child: widget.isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._buildLoadingDots().expand((dot) => [dot, const SizedBox(width: 6)]),
              ]..removeLast(),
            )
          : Text(
              widget.text,
              softWrap: true,
              style: TextStyle(
                color: widget.isUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.grey100,
              child: Icon(
                Icons.psychology_outlined,
                color: AppColors.primary,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Align(
              alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width),
                child: bubble,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
