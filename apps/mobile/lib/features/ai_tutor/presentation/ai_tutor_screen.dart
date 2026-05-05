import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'ai_tutor_providers.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _scrollCtrl  = ScrollController();
  final _inputCtrl   = TextEditingController();

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages  = ref.watch(aiChatProvider);
    final isLoading = ref.watch(aiChatProvider.notifier).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.smart_toy_outlined, size: 20),
          SizedBox(width: 8),
          Text('Tuteur IA Suklu'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Nouvelle conversation',
            onPressed: () => ref.read(aiChatProvider.notifier).clearHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const _WelcomeState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: AppSpacing.pagePadding,
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == messages.length) return const _TypingIndicator();
                      return _MessageBubble(message: messages[i]);
                    },
                  ),
          ),
          _InputBar(
            controller: _inputCtrl,
            onSend: _sendMessage,
            enabled: !isLoading,
          ),
        ],
      ),
    );
  }
}

class _WelcomeState extends StatelessWidget {
  const _WelcomeState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AppSpacing.pagePadding,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.studentAccent.withAlpha(20), shape: BoxShape.circle),
          child: const Icon(Icons.smart_toy_outlined, size: 40, color: AppColors.studentAccent),
        ),
        AppSpacing.gapMd,
        Text('Bonjour ! Je suis votre tuteur IA.', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        AppSpacing.gapSm,
        Text('Posez-moi n\'importe quelle question sur vos cours !', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.grey100,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(AppSpacing.radiusMd),
            topRight:    const Radius.circular(AppSpacing.radiusMd),
            bottomLeft:  Radius.circular(isUser ? AppSpacing.radiusMd : 0),
            bottomRight: Radius.circular(isUser ? 0 : AppSpacing.radiusMd),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? Colors.white : AppColors.grey900),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Suklu réfléchit...', style: TextStyle(color: AppColors.grey600, fontSize: 13)),
      ]),
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend, required this.enabled});
  final TextEditingController controller;
  final VoidCallback           onSend;
  final bool                   enabled;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12, offset: Offset(0, -2))],
    ),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLines: null,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onSend(),
          decoration: InputDecoration(
            hintText: 'Posez une question...',
            filled: true,
            fillColor: AppColors.grey100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusFull), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      const SizedBox(width: 8),
      CircleAvatar(
        backgroundColor: enabled ? AppColors.primary : AppColors.grey400,
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white, size: 18),
          onPressed: enabled ? onSend : null,
        ),
      ),
    ]),
  );
}
