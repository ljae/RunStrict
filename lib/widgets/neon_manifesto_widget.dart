import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NeonManifestoWidget extends StatelessWidget {
  final String text;
  final Color teamColor;
  final double fontSize;

  const NeonManifestoWidget({
    super.key,
    required this.text,
    required this.teamColor,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = _getDisplayText();
    final isMuted = displayText == '---';

    return Text(
      displayText,
      style: GoogleFonts.sora(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: isMuted ? Colors.white.withValues(alpha: 0.3) : Colors.white,
        shadows: isMuted ? null : _buildNeonShadows(),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getDisplayText() {
    if (text.isEmpty) return '---';
    if (text.length > 12) return text.substring(0, 12);
    return text;
  }

  List<Shadow> _buildNeonShadows() => [
    Shadow(color: teamColor.withValues(alpha: 0.8), blurRadius: 4),
    Shadow(color: teamColor.withValues(alpha: 0.6), blurRadius: 8),
    Shadow(color: teamColor.withValues(alpha: 0.4), blurRadius: 16),
  ];
}
