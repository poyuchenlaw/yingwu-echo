// write_today.dart — 今日書寫畫面（靈魂墨水輸入）
//
// Responsibilities:
//   - Rich text input with live char count
//   - Wuxing detection hint (placeholder for AI analysis)
//   - Emotion tag selection (5 options)
//   - Submit writing -> POST /api/writings
//
// TODO: implement AI wuxing detection endpoint integration
import 'package:flutter/material.dart';

class WriteTodayScreen extends StatefulWidget {
  const WriteTodayScreen({super.key});

  @override
  State<WriteTodayScreen> createState() => _WriteTodayScreenState();
}

class _WriteTodayScreenState extends State<WriteTodayScreen> {
  final TextEditingController _controller = TextEditingController();
  int _charCount = 0;
  String? _selectedEmotion;

  // TODO: localise these labels
  static const _emotionOptions = ['喜', '怒', '哀', '懼', '驚'];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _charCount = _controller.text.length);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _charCount >= 50;
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('今日書寫', style: TextStyle(color: Color(0xFFD4A050))),
        iconTheme: const IconThemeData(color: Color(0xFFD4A050)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmotionPicker(),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Color(0xFFE8C880), fontSize: 16, height: 1.8),
                decoration: InputDecoration(
                  hintText: '以言應物，此刻你感受到什麼？',
                  hintStyle: const TextStyle(color: Color(0xFF5A3A20)),
                  filled: true,
                  fillColor: const Color(0xFF2A1500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_charCount 字  ${canSubmit ? "" : "(最少 50 字)"}',
                  style: TextStyle(
                    color: canSubmit ? const Color(0xFF8ACA60) : const Color(0xFF9A7050),
                  ),
                ),
                // TODO: disable button and show loading state during API call
                ElevatedButton(
                  onPressed: canSubmit ? _submitWriting : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A050),
                    foregroundColor: const Color(0xFF1A0A00),
                  ),
                  child: const Text('映刻靈魂'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionPicker() {
    return Row(
      children: _emotionOptions.map((e) {
        final selected = _selectedEmotion == e;
        return GestureDetector(
          onTap: () => setState(() => _selectedEmotion = selected ? null : e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected ? const Color(0xFFD4A050) : const Color(0xFF2A1500),
              border: Border.all(
                color: selected ? const Color(0xFFD4A050) : const Color(0xFF5A3A20),
              ),
            ),
            child: Text(
              e,
              style: TextStyle(
                color: selected ? const Color(0xFF1A0A00) : const Color(0xFF9A7050),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _submitWriting() {
    // TODO: call ApiService.submitWriting(content, emotion, wuxingHint)
    //       then trigger forge eligibility check
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('書寫已映刻 — API 尚未接通')),
    );
  }
}
