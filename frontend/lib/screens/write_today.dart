import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/echo_client.dart';
import '../main.dart';
import '../theme/echo_theme.dart';
import '../widgets/help_sheet.dart';

const _emotions = ['累', '想哭', '火大', '好像懂了', '平', '煩', '爽', '開心', '莫名', '想睡'];

class WriteTodayScreen extends ConsumerStatefulWidget {
  const WriteTodayScreen({super.key});
  @override
  ConsumerState<WriteTodayScreen> createState() => _WriteTodayState();
}

class _WriteTodayState extends ConsumerState<WriteTodayScreen> {
  final _controller = TextEditingController();
  String? _emotion;
  bool _loading = false;
  String _status = '';
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty || _emotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請寫一段文字並選一個情緒')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _status = '送出書寫…';
      _result = null;
    });
    final client = ref.read(clientProvider);
    try {
      final id = await client.postWriting(content: _controller.text, emotionTag: _emotion!);
      setState(() => _status = '後台 Gemini Flash 分析中（約 20-30 秒）…');
      final analysis = await client.pollAnalysis(id);
      setState(() {
        _result = analysis;
        _status = '完成';
      });
    } on DuplicateWritingException catch (e) {
      setState(() => _status = '⚠ ${e.toString()}');
    } catch (e) {
      setState(() => _status = '❌ ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日書寫'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '書寫說明',
            onPressed: () => showHelpSheet(context, title: '今日書寫 · 使用方式', entries: const [
              HelpEntry('文字框', '寫你今天的感受，越具體（場景、人、身體感覺）AI 越能精準對映五行。',
                  icon: Icons.edit),
              HelpEntry('情緒標籤', '10 選 1，告訴 AI 你今天的情緒主軸。同情緒不同寫法會生不同共鳴體。',
                  icon: Icons.psychology),
              HelpEntry('應物', '送出後 Gemini Flash 後台分析（約 20-30 秒），不阻塞 UI。',
                  icon: Icons.send),
              HelpEntry('五行 / 九曜', '系統判斷你文字的能量屬性，影響共鳴體屬性與戰鬥相剋。',
                  icon: Icons.public),
              HelpEntry('真誠度',
                  '0-100%；AI 評估文字情感深度與一致性。越高代表你寫的越「真」，未來會影響收編加成。',
                  icon: Icons.favorite),
              HelpEntry('共鳴體 quote',
                  '為你今天的書寫生成的一段台詞，是這隻怪物的個性簽名。',
                  icon: Icons.format_quote),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '例：通勤路上看著車窗外的雨，覺得一切都很遙遠…',
              ),
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 16),
            const Text('選擇情緒', style: TextStyle(color: EchoColors.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emotions.map((e) {
                final sel = _emotion == e;
                return ChoiceChip(
                  label: Text(e),
                  selected: sel,
                  onSelected: (_) => setState(() => _emotion = e),
                  backgroundColor: EchoColors.bg,
                  selectedColor: EchoColors.accent,
                  labelStyle: TextStyle(color: sel ? const Color(0xFF1A1A1A) : EchoColors.fg),
                  side: const BorderSide(color: EchoColors.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? '分析中…' : '應物'),
            ),
            const SizedBox(height: 14),
            if (_status.isNotEmpty)
              Text(_status, style: const TextStyle(color: EchoColors.muted, fontSize: 13)),
            const SizedBox(height: 24),
            if (_result != null) _ResultCard(_result!),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.r);
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final w = r['wuxing_detected'] as String? ?? '';
    final v = (r['validity_score'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EchoColors.panel,
        border: Border.all(color: EchoColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('五行 ', style: TextStyle(color: EchoColors.muted)),
            if (w.isNotEmpty) WuxingBadge(w),
            const SizedBox(width: 16),
            Text('九曜 ${r["celestial_detected"] ?? "—"}',
                style: const TextStyle(color: EchoColors.fg)),
          ]),
          const SizedBox(height: 10),
          Text('共鳴體 · ${r["monster_name"] ?? "—"}',
              style: const TextStyle(color: EchoColors.accent, fontSize: 22)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('真誠度 ', style: TextStyle(color: EchoColors.muted)),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: v,
                backgroundColor: EchoColors.bg,
                color: EchoColors.accent,
                minHeight: 8,
              ),
            ),
            const SizedBox(width: 8),
            Text('${(v * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: EchoColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: EchoColors.bg,
              border: Border(left: BorderSide(color: EchoColors.accent, width: 3)),
            ),
            child: Text(
              r['card_quote'] as String? ?? '',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: EchoColors.fg,
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
