import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../models/crew_model.dart';
import '../data/sponsors_data.dart';
import 'sponsor_logo_painter.dart';

/// Displays the crew's representative image.
///
/// Priority:
/// 1. If [sponsorId] is provided, renders the sponsor logo via Canvas
/// 2. If [imageData] (base64) is provided, decodes and displays it
/// 3. Falls back to a default team-colored avatar
class CrewAvatar extends StatelessWidget {
  final String? sponsorId;
  final String? imageData;
  final Color teamColor;
  final double size;
  final bool showBorder;
  final bool isSelected;

  const CrewAvatar({
    super.key,
    this.sponsorId,
    this.imageData,
    required this.teamColor,
    this.size = 60,
    this.showBorder = true,
    this.isSelected = false,
  });

  /// Create from a CrewModel
  factory CrewAvatar.fromCrew(
    CrewModel crew, {
    double size = 60,
    bool showBorder = true,
    bool isSelected = false,
  }) {
    return CrewAvatar(
      sponsorId: crew.sponsorId,
      imageData: crew.representativeImage,
      teamColor: crew.team.color,
      size: size,
      showBorder: showBorder,
      isSelected: isSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Try sponsor logo first
    if (sponsorId != null) {
      final sponsor = _findSponsor(sponsorId!);
      if (sponsor != null) {
        return _buildSponsorLogo(sponsor);
      }
    }

    // Try base64 image
    if (imageData != null && imageData!.isNotEmpty) {
      final bytes = _decodeBase64Image(imageData!);
      if (bytes != null) {
        return _buildImageAvatar(bytes);
      }
    }

    // Fallback to default avatar
    return _buildDefaultAvatar();
  }

  Sponsor? _findSponsor(String id) {
    try {
      return SponsorsData.allSponsors.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _decodeBase64Image(String data) {
    try {
      // Handle data URL format
      String base64String = data;
      if (data.startsWith('data:')) {
        final commaIndex = data.indexOf(',');
        if (commaIndex != -1) {
          base64String = data.substring(commaIndex + 1);
        }
      }
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }

  Widget _buildSponsorLogo(Sponsor sponsor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: isSelected ? Colors.white : sponsor.primaryColor,
                width: isSelected ? 3 : 2,
              )
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: sponsor.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Container(
          color: const Color(0xFF0F172A),
          child: CustomPaint(
            size: Size(size, size),
            painter: SponsorLogoPainter(
              sponsor: sponsor,
              isSelected: isSelected,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageAvatar(Uint8List bytes) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: isSelected ? Colors.white : teamColor,
                width: isSelected ? 3 : 2,
              )
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: teamColor.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
        image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [teamColor, teamColor.withValues(alpha: 0.6)],
        ),
        border: showBorder
            ? Border.all(
                color: isSelected ? Colors.white : teamColor,
                width: isSelected ? 3 : 2,
              )
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: teamColor.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.5),
    );
  }
}

/// A larger crew badge showing sponsor logo with name and tier.
class CrewBadge extends StatelessWidget {
  final CrewModel crew;
  final double logoSize;
  final bool showName;
  final bool showTier;

  const CrewBadge({
    super.key,
    required this.crew,
    this.logoSize = 80,
    this.showName = true,
    this.showTier = true,
  });

  @override
  Widget build(BuildContext context) {
    final sponsor = _findSponsor(crew.sponsorId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CrewAvatar.fromCrew(crew, size: logoSize),
        if (showName) ...[
          const SizedBox(height: 8),
          Text(
            crew.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (showTier && sponsor != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: sponsor.tier.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sponsor.name,
                  style: TextStyle(
                    color: sponsor.tier.color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• ${sponsor.tier.displayName}',
                  style: TextStyle(
                    color: sponsor.tier.color.withValues(alpha: 0.7),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Sponsor? _findSponsor(String? id) {
    if (id == null) return null;
    try {
      return SponsorsData.allSponsors.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
