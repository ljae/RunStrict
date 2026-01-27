import 'package:flutter/material.dart';
import '../models/sponsor.dart';

class SponsorsData {
  static const List<Sponsor> allSponsors = [
    // --- LEGENDARY (3) ---
    Sponsor(
      id: 's_legend_01',
      name: 'AETHER',
      tagline: 'Beyond the Physical',
      logoIcon: '∞',
      primaryColor: Color(0xFF000000),
      secondaryColor: Color(0xFFFFD700),
      tier: SponsorTier.legendary,
    ),
    Sponsor(
      id: 's_legend_02',
      name: 'OLYMPUS',
      tagline: 'Defy Mortality',
      logoIcon: 'Ω',
      primaryColor: Color(0xFFFFFFFF),
      secondaryColor: Color(0xFFC0C0C0),
      tier: SponsorTier.legendary,
    ),
    Sponsor(
      id: 's_legend_03',
      name: 'VANGUARD',
      tagline: 'Lead the Charge',
      logoIcon: '⚔',
      primaryColor: Color(0xFFDC143C),
      secondaryColor: Color(0xFF2F4F4F),
      tier: SponsorTier.legendary,
    ),

    // --- EPIC (7) ---
    Sponsor(
      id: 's_epic_01',
      name: 'KINETIC',
      tagline: 'Perpetual Motion',
      logoIcon: '⚡',
      primaryColor: Color(0xFF39FF14), // Neon Green
      secondaryColor: Color(0xFF111111),
      tier: SponsorTier.epic,
    ),
    Sponsor(
      id: 's_epic_02',
      name: 'OBSIDIAN',
      tagline: 'Unbreakable Will',
      logoIcon: '⬢',
      primaryColor: Color(0xFF2E2E2E),
      secondaryColor: Color(0xFF9D4EDD),
      tier: SponsorTier.epic,
    ),
    Sponsor(
      id: 's_epic_03',
      name: 'VELOCITY',
      tagline: 'Speed Defined',
      logoIcon: '⏩',
      primaryColor: Color(0xFF00FFFF), // Cyan
      secondaryColor: Color(0xFF00008B),
      tier: SponsorTier.epic,
    ),
    Sponsor(
      id: 's_epic_04',
      name: 'APEX',
      tagline: 'Reach the Summit',
      logoIcon: '▲',
      primaryColor: Color(0xFFFF4500), // Orange Red
      secondaryColor: Color(0xFF000000),
      tier: SponsorTier.epic,
    ),
    Sponsor(
      id: 's_epic_05',
      name: 'QUANTUM',
      tagline: 'Infinite Possibilities',
      logoIcon: '⚛',
      primaryColor: Color(0xFF9400D3), // Violet
      secondaryColor: Color(0xFF00CED1),
      tier: SponsorTier.epic,
    ),
    Sponsor(
      id: 's_epic_06',
      name: 'TITAN',
      tagline: 'Forge Your Legacy',
      logoIcon: '🛡',
      primaryColor: Color(0xFF4682B4), // Steel Blue
      secondaryColor: Color(0xFF708090),
      tier: SponsorTier.epic,
    ),
    Sponsor(
      id: 's_epic_07',
      name: 'PHOENIX',
      tagline: 'Rise Again',
      logoIcon: '🔥',
      primaryColor: Color(0xFFFF8C00), // Dark Orange
      secondaryColor: Color(0xFF8B0000),
      tier: SponsorTier.epic,
    ),

    // --- RARE (10) ---
    Sponsor(
      id: 's_rare_01',
      name: 'STRIDE',
      tagline: 'Find Your Rhythm',
      logoIcon: '〰',
      primaryColor: Color(0xFF1E90FF),
      secondaryColor: Color(0xFFFFFFFF),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_02',
      name: 'PULSE',
      tagline: 'Alive & Running',
      logoIcon: '❤',
      primaryColor: Color(0xFFFF1493), // Deep Pink
      secondaryColor: Color(0xFFFFFFFF),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_03',
      name: 'ZENITH',
      tagline: 'Above All',
      logoIcon: '☀',
      primaryColor: Color(0xFFFFD700),
      secondaryColor: Color(0xFF87CEEB),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_04',
      name: 'FLUX',
      tagline: 'Adapt & Overcome',
      logoIcon: '≈',
      primaryColor: Color(0xFF00FA9A), // Medium Spring Green
      secondaryColor: Color(0xFF483D8B),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_05',
      name: 'ECHO',
      tagline: 'Resonate',
      logoIcon: '((.))',
      primaryColor: Color(0xFFD8BFD8), // Thistle
      secondaryColor: Color(0xFF4B0082),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_06',
      name: 'NOVA',
      tagline: 'Explosive Energy',
      logoIcon: '★',
      primaryColor: Color(0xFFFFFF00), // Yellow
      secondaryColor: Color(0xFFFF0000),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_07',
      name: 'DRIFT',
      tagline: 'Flow State',
      logoIcon: '≋',
      primaryColor: Color(0xFF40E0D0), // Turquoise
      secondaryColor: Color(0xFF008080),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_08',
      name: 'SURGE',
      tagline: 'Power Up',
      logoIcon: '⚡',
      primaryColor: Color(0xFFFF00FF), // Magenta
      secondaryColor: Color(0xFF191970),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_09',
      name: 'CORE',
      tagline: 'Inner Strength',
      logoIcon: '◉',
      primaryColor: Color(0xFFA52A2A), // Brown
      secondaryColor: Color(0xFFDEB887),
      tier: SponsorTier.rare,
    ),
    Sponsor(
      id: 's_rare_10',
      name: 'AURA',
      tagline: 'Radiate Power',
      logoIcon: '✨',
      primaryColor: Color(0xFFE6E6FA), // Lavender
      secondaryColor: Color(0xFF9370DB),
      tier: SponsorTier.rare,
    ),

    // --- COMMON (10) ---
    Sponsor(
      id: 's_common_01',
      name: 'DASH',
      tagline: 'Just Run',
      logoIcon: '->',
      primaryColor: Color(0xFF808080),
      secondaryColor: Color(0xFFD3D3D3),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_02',
      name: 'PACE',
      tagline: 'Steady On',
      logoIcon: '⏱',
      primaryColor: Color(0xFF708090),
      secondaryColor: Color(0xFFB0C4DE),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_03',
      name: 'BOLT',
      tagline: 'Quick Start',
      logoIcon: '🔩',
      primaryColor: Color(0xFFDAA520),
      secondaryColor: Color(0xFFF0E68C),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_04',
      name: 'GEAR',
      tagline: 'Keep Moving',
      logoIcon: '⚙',
      primaryColor: Color(0xFFCD853F),
      secondaryColor: Color(0xFFD2691E),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_05',
      name: 'TRACK',
      tagline: 'Stay the Course',
      logoIcon: '||',
      primaryColor: Color(0xFF8B4513),
      secondaryColor: Color(0xFFA0522D),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_06',
      name: 'SOLE',
      tagline: 'Ground Level',
      logoIcon: '👣',
      primaryColor: Color(0xFFBC8F8F),
      secondaryColor: Color(0xFFFFE4E1),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_07',
      name: 'LOOP',
      tagline: 'Never Stop',
      logoIcon: '↺',
      primaryColor: Color(0xFF4682B4),
      secondaryColor: Color(0xFF87CEEB),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_08',
      name: 'RUSH',
      tagline: 'Adrenaline',
      logoIcon: '!!',
      primaryColor: Color(0xFFB22222),
      secondaryColor: Color(0xFFCD5C5C),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_09',
      name: 'STEP',
      tagline: 'One by One',
      logoIcon: '1',
      primaryColor: Color(0xFF556B2F),
      secondaryColor: Color(0xFF8FBC8F),
      tier: SponsorTier.common,
    ),
    Sponsor(
      id: 's_common_10',
      name: 'GRIT',
      tagline: 'Tough It Out',
      logoIcon: '✊',
      primaryColor: Color(0xFF2F4F4F),
      secondaryColor: Color(0xFF696969),
      tier: SponsorTier.common,
    ),
  ];
}
