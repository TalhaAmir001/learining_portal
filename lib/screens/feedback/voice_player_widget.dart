import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app audio player for voice recording URL (or optional local path).
class VoicePlayerWidget extends StatefulWidget {
  final String? audioUrl;
  final String? localPath;

  const VoicePlayerWidget({
    super.key,
    this.audioUrl,
    this.localPath,
  }) : assert(audioUrl != null || localPath != null);

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _setSource();
    _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _player.positionStream.listen((_) {
      if (mounted) setState(() {});
    });
    _player.durationStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(VoicePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.localPath != widget.localPath) {
      _setSource();
    }
  }

  Future<void> _setSource() async {
    try {
      if (widget.localPath != null) {
        await _player.setFilePath(widget.localPath!);
      } else if (widget.audioUrl != null) {
        await _player.setUrl(widget.audioUrl!);
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaying = _player.playing;
    final processing = _player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.buffering;
    final duration = _player.duration ?? Duration.zero;
    final position = _player.position;
    final durationSec = duration.inSeconds;
    final positionSec = position.inSeconds;
    final progress = durationSec > 0 ? positionSec / durationSec : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: processing
                      ? null
                      : () async {
                          if (isPlaying) {
                            await _player.pause();
                          } else {
                            await _player.play();
                          }
                        },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentTeal.withOpacity(0.5),
                      ),
                    ),
                    child: processing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.accentTeal,
                              ),
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppColors.accentTeal,
                            size: 28,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voice recording',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.accentTeal,
                        inactiveTrackColor: AppColors.accentTeal.withOpacity(0.2),
                        thumbColor: AppColors.accentTeal,
                        overlayColor: AppColors.accentTeal.withOpacity(0.1),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: durationSec > 0
                            ? (v) {
                                final pos = Duration(
                                  seconds: (v * durationSec).round(),
                                );
                                _player.seek(pos);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (widget.audioUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () async {
                  final uri = Uri.parse(widget.audioUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  'Open in browser',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.accentTeal,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
