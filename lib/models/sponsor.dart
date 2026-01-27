import 'package:flutter/material.dart';

enum SponsorTier {
  legendary,
  epic,
  rare,
  common;

  Color get color {
    switch (this) {
      case SponsorTier.legendary:
        return const Color(0xFFFFD700); // Gold
      case SponsorTier.epic:
        return const Color(0xFF9D4EDD); // Purple
      case SponsorTier.rare:
        return const Color(0xFF00B4D8); // Blue
      case SponsorTier.common:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  String get displayName => name.toUpperCase();
}

class Sponsor {
  final String id;
  final String name;
  final String tagline;
  final String logoIcon; // Unicode character
  final Color primaryColor;
  final Color secondaryColor;
  final SponsorTier tier;

  const Sponsor({
    required this.id,
    required this.name,
    required this.tagline,
    required this.logoIcon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tier,
  });
}
