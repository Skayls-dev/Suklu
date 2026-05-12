import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _aiGatewayUrl = String.fromEnvironment(
  'AI_GATEWAY_URL',
  defaultValue: 'http://localhost:8000',
);

class ImagePreviewDialog extends StatefulWidget {
  const ImagePreviewDialog({required this.docId, super.key});

  final String docId;

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadImages();
  }

  Future<List<Map<String, dynamic>>> _loadImages() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final response = await http.get(
      Uri.parse('$_aiGatewayUrl/ingest/images?doc_id=${Uri.encodeComponent(widget.docId)}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erreur API: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['images'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _deleteImage(String imageId) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final response = await http.delete(
      Uri.parse('$_aiGatewayUrl/ingest/images/${Uri.encodeComponent(widget.docId)}/${Uri.encodeComponent(imageId)}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (!mounted) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression image: ${response.statusCode}')),
      );
      return;
    }

    setState(() {
      _future = _loadImages();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image supprimée.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 900,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 200,
                  child: Center(child: Text('Erreur: ${snapshot.error}')),
                );
              }

              final images = snapshot.data ?? const [];
              if (images.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Text('Aucune image indexée pour ce document.')),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Images indexées', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: images.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (context, index) {
                        final image = images[index];
                        final url = (image['image_url'] ?? '').toString();
                        final caption = (image['caption'] ?? '').toString();
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.grey.shade100,
                                    child: url.isEmpty
                                        ? const Center(child: Icon(Icons.image_not_supported))
                                        : Image.network(url, fit: BoxFit.contain),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  caption,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _deleteImage((image['id'] ?? '').toString()),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Supprimer'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
