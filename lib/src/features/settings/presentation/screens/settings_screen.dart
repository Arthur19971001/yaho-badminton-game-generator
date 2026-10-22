import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/alarm_sound_controller.dart';

/// 설정: currently just the game-over alarm sound -- pick any audio file
/// (e.g. a downloaded mp3) to replace the default siren, preview it, or go
/// back to the siren.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _previewing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewing = false);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soundAsync = ref.watch(alarmSoundControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('게임 종료 알림음', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '게임 타이머가 끝났을 때 반복 재생되는 소리입니다. '
            'mp3 등 원하는 음악 파일로 바꿀 수 있습니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          soundAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Text('오류: $error'),
            data: (sound) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          sound.isDefault ? Icons.campaign : Icons.music_note,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sound.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _togglePreview(sound),
                          icon: Icon(
                            _previewing ? Icons.stop : Icons.play_arrow,
                          ),
                          label: Text(_previewing ? '정지' : '미리듣기'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _pickSound,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('파일 선택'),
                        ),
                        if (!sound.isDefault)
                          TextButton.icon(
                            onPressed: _busy ? null : _resetToDefault,
                            icon: const Icon(Icons.restore),
                            label: const Text('기본 사이렌으로 되돌리기'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePreview(AlarmSound sound) async {
    if (_previewing) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    setState(() => _previewing = true);
    try {
      await _previewPlayer.play(sound.source, volume: 1.0);
    } catch (error) {
      if (!mounted) return;
      setState(() => _previewing = false);
      _showMessage('재생하지 못했습니다: $error');
    }
  }

  Future<void> _pickSound() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '알림음 파일 선택',
      type: FileType.custom,
      allowedExtensions: alarmSoundExtensions,
    );
    final path = file?.path;
    if (path == null) return;

    await _run(() async {
      await _stopPreview();
      await ref
          .read(alarmSoundControllerProvider.notifier)
          .setCustomSound(path);
      _showMessage('알림음이 "${file!.name}"(으)로 변경되었습니다.');
    });
  }

  Future<void> _resetToDefault() => _run(() async {
        await _stopPreview();
        await ref.read(alarmSoundControllerProvider.notifier).resetToDefault();
        _showMessage('기본 사이렌으로 되돌렸습니다.');
      });

  Future<void> _stopPreview() async {
    if (!_previewing) return;
    await _previewPlayer.stop();
    if (mounted) setState(() => _previewing = false);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _showMessage('저장하지 못했습니다: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
