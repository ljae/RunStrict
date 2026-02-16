# Profile Screen Redesign

## Changes
- Moved ID/Username to the top of the screen (`_HeaderSection`).
- Redesigned `_DetailsSection` to be more professional.
- Replaced "Other" sex option with binary "Male"/"Female" chips.
- Implemented inline `CupertinoDatePicker` for birthday selection (replacing modal popup).
- Updated typography to use `GoogleFonts.sora` for headers and `GoogleFonts.inter` for body text.
- Used `AppTheme` colors and `withValues(alpha: ...)` for transparency.

## Rationale
- **ID/Username Position**: The user's identity is the most important element on the profile screen.
- **Inline Date Picker**: Provides a smoother user experience than a modal popup.
- **Binary Sex Selection**: Simplifies the UI and aligns with the "Professional" requirement.
- **Typography**: `Sora` and `Inter` provide a modern, clean look.
