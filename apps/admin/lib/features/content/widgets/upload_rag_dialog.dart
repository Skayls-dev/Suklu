import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const aiGatewayUrl = String.fromEnvironment(
  'AI_GATEWAY_URL',
  defaultValue: 'http://localhost:8000',
);

Future<void> showUploadRagDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const UploadRagDialog(),
  );
}

class UploadRagDialog extends StatefulWidget {
  const UploadRagDialog({super.key});

  @override
  State<UploadRagDialog> createState() => _UploadRagDialogState();
}

class _UploadRagDialogState extends State<UploadRagDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _subject;
  String? _gradeLevel;
  String? _country;
  final _captionCtrl = TextEditingController();

  String? _fileName;
  Uint8List? _fileBytes;
  bool _uploading = false;

  static const _gradeLevels = ['CP', 'CE1', 'CE2', 'CM1', 'CM2', '6e', '5e', '4e', '3e', '2nde', '1ere', 'Terminale'];
  static const _countries = ['SN', 'CI', 'CM', 'GN'];

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _fileName = file.name;
      _fileBytes = file.bytes;
    });
  }

  Future<void> _ingest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null || _fileName == null) return;

    setState(() {
      _uploading = true;
    });

    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final request = http.MultipartRequest('POST', Uri.parse('$aiGatewayUrl/ingest'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['subject'] = _subject!
        ..fields['grade_level'] = _gradeLevel!
        ..fields['country'] = _country!
        ..fields['caption'] = _captionCtrl.text.trim();

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _fileBytes!,
          filename: _fileName!,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        var successMessage = 'Ingestion lancée avec succès.';
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final chunks = body['chunksIngested'];
          if (chunks != null) {
            successMessage = 'Ingestion réussie ($chunks chunks).';
          }
        } catch (_) {
          // Keep default success message when body is not JSON.
        }

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erreur AI Gateway: ${response.statusCode} ${response.body}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Erreur upload: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ingérer un nouveau document'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Matière'),
                value: _subject,
                items: const [
                  DropdownMenuItem(value: 'mathematics', child: Text('Mathematics')),
                  DropdownMenuItem(value: 'french', child: Text('French')),
                  DropdownMenuItem(value: 'english', child: Text('English')),
                  DropdownMenuItem(value: 'physics', child: Text('Physics')),
                ],
                validator: (v) => v == null ? 'Requis' : null,
                onChanged: (v) => setState(() => _subject = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Niveau'),
                value: _gradeLevel,
                items: _gradeLevels.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                validator: (v) => v == null ? 'Requis' : null,
                onChanged: (v) => setState(() => _gradeLevel = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Pays'),
                value: _country,
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                validator: (v) => v == null ? 'Requis' : null,
                onChanged: (v) => setState(() => _country = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _selectFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileName == null ? 'Sélectionner un fichier PDF/DOCX/IMAGE' : _fileName!),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _captionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description de l\'image (optionnel)',
                  hintText: 'Utilisée si vous importez une image sans PDF',
                ),
                minLines: 2,
                maxLines: 3,
              ),
              if (_uploading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _uploading ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _uploading ? null : _ingest, child: const Text('Ingérer')),
      ],
    );
  }
}
