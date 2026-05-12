import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ReviewBottomSheet extends StatefulWidget {
  const ReviewBottomSheet({
    required this.sessionId,
    required this.targetName,
    required this.targetRole,
    super.key,
  });

  final String sessionId;
  final String targetName;
  final String targetRole;

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une note de 1 à 5 étoiles.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('submitReview');
      await callable.call({
        'sessionId': widget.sessionId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Évaluation envoyée avec succès.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erreur: $e')),
      );
      Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.targetRole == 'tutor'
        ? 'Aidez d\'autres élèves à choisir ce tuteur.'
        : 'Votre retour aidera l\'élève à progresser.';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évaluez ${widget.targetName}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 14),
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                onPressed: _submitting ? null : () => setState(() => _rating = starIndex),
                icon: Icon(
                  _rating >= starIndex ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
              );
            }),
          ),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 5,
            enabled: !_submitting,
            decoration: const InputDecoration(
              hintText: 'Partagez votre expérience...',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Envoyer l\'évaluation'),
            ),
          ),
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
            child: const Text('Passer'),
          ),
        ],
      ),
    );
  }
}
