import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../models/video_details.dart';

/// View count, upload date and a description that expands on tap.
class VideoDescription extends StatefulWidget {
  const VideoDescription({super.key, required this.details, this.collapsedLines = 3});

  final VideoDetails details;
  final int collapsedLines;

  @override
  State<VideoDescription> createState() => _VideoDescriptionState();
}

class _VideoDescriptionState extends State<VideoDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final stats = details.statsLine;
    final description = details.description.isEmpty ? 'No description.' : details.description;
    final style = TextStyle(color: context.textPrimary, fontSize: 13, height: 1.4);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only offer "more" when the collapsed text really is cut off.
        final painter = TextPainter(
          text: TextSpan(text: description, style: style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: (constraints.maxWidth - 24).clamp(0, double.infinity));
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Material(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: overflows || _expanded ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.isNotEmpty) ...[
                    Text(
                      stats,
                      style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                  ],
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? Text(description, style: style)
                        : Text(
                            description,
                            maxLines: widget.collapsedLines,
                            overflow: TextOverflow.ellipsis,
                            style: style,
                          ),
                  ),
                  if (overflows || _expanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      _expanded ? 'Show less' : 'Show more',
                      style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
