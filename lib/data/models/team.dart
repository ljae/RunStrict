import 'package:flutter/material.dart';

/// Team enum for RunStrict game
/// - Red/Blue: Starting teams (compete for territory)
/// - Purple: Chaos mechanic (available anytime)
enum Team {
  red, // Display: "FLAME" - Passion & Energy
  blue, // Display: "WAVE" - Trust & Harmony
  purple; // Display: "CHAOS" - The Betrayer's Path (available anytime)

  String get displayName {
    switch (this) {
      case Team.red:
        return 'FLAME';
      case Team.blue:
        return 'WAVE';
      case Team.purple:
        return 'CHAOS';
    }
  }

  String get emoji {
    switch (this) {
      case Team.red:
        return '🔥';
      case Team.blue:
        return '🌊';
      case Team.purple:
        return '💜';
    }
  }

  String get description {
    switch (this) {
      case Team.red:
        return 'Passion & Energy';
      case Team.blue:
        return 'Trust & Harmony';
      case Team.purple:
        return "The Betrayer's Path";
    }
  }

  Color get color {
    switch (this) {
      case Team.red:
        return const Color(0xFFFF003C);
      case Team.blue:
        return const Color(0xFF008DFF);
      case Team.purple:
        return const Color(0xFF8B5CF6);
    }
  }

  Color get lightColor {
    switch (this) {
      case Team.red:
        return const Color(0xFFFF335F);
      case Team.blue:
        return const Color(0xFF33A4FF);
      case Team.purple:
        return const Color(0xFFA78BFA);
    }
  }
}
