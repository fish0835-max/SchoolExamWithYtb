import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/models/question.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/services/settings_service.dart';

class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  ConsumerState<PhotoUploadScreen> createState() =>
      _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  XFile? _selectedImage;
  bool _isGenerating = false;
  Question? _generatedQuestion;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
        _generatedQuestion = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _generateQuestion() async {
    if (_selectedImage == null) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // Compress image
      final bytes = await File(_selectedImage!.path).readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 800,
        minHeight: 600,
        quality: 80,
      );

      final base64Image = base64Encode(compressed);

      // Get current settings for grade
      final settings = await ref.read(settingsServiceProvider).getSettings();

      // Call Firebase Cloud Function
      final callable =
          FirebaseFunctions.instance.httpsCallable('generateFromPhoto');
      final result = await callable.call({
        'image_base64': base64Image,
        'grade': settings.mathGrade,
        'subject': 'math',
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final question = Question.fromJson({
        ...data,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'grade': settings.mathGrade,
        'subject': 'math',
        'semester': settings.mathSemester,
        'source': 'photo',
      });

      // Save to local DB
      await LocalDbService.instance.insertQuestion(question);

      setState(() => _generatedQuestion = question);
    } catch (e) {
      setState(() => _errorMessage = '生成題目失敗：$e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('照片出題'),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              elevation: 0,
              color: const Color(0xFFF3E5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF7B1FA2)),
                        SizedBox(width: 8),
                        Text(
                          '如何使用照片出題',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7B1FA2),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. 拍攝或選取孩子的康軒教材照片\n'
                      '2. AI 會分析照片內容自動出題\n'
                      '3. 確認題目後儲存，下次出題時會使用',
                      style: TextStyle(
                        color: Color(0xFF6A1B9A),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Image picker buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('拍照'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B1FA2),
                      side: const BorderSide(color: Color(0xFF7B1FA2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('從相簿選取'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B1FA2),
                      side: const BorderSide(color: Color(0xFF7B1FA2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Image preview
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_selectedImage!.path),
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),

              // Generate button
              FilledButton.icon(
                onPressed: _isGenerating ? null : _generateQuestion,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating ? 'AI 分析中...' : '用 AI 生成題目',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Generated question preview
            if (_generatedQuestion != null) ...[
              const SizedBox(height: 20),
              const Text(
                '生成的題目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _QuestionPreview(question: _generatedQuestion!),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('題目已儲存！下次答題時會使用這道題'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                  setState(() {
                    _selectedImage = null;
                    _generatedQuestion = null;
                  });
                },
                icon: const Icon(Icons.check),
                label: const Text('確認儲存'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionPreview extends StatelessWidget {
  final Question question;

  const _QuestionPreview({required this.question});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF9FBE7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCDDC39), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (question.options != null) ...[
              const SizedBox(height: 12),
              ...question.options!.asMap().entries.map((e) {
                final label = ['A', 'B', 'C', 'D'][e.key];
                final isCorrect = e.value == question.correctAnswer;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  isCorrect ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        e.value,
                        style: TextStyle(
                          color: isCorrect
                              ? const Color(0xFF2E7D32)
                              : Colors.black87,
                          fontWeight: isCorrect
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF4CAF50), size: 16),
                const SizedBox(width: 4),
                Text(
                  '正確答案：${question.correctAnswer}',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
