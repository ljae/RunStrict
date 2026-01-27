import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sponsor.dart';
import '../data/sponsors_data.dart';
import 'sponsor_logo_painter.dart';
import '../theme/app_theme.dart';

class SponsorSelector extends StatefulWidget {
  final Function(Sponsor) onSelected;
  final String? selectedSponsorId;

  const SponsorSelector({
    super.key,
    required this.onSelected,
    this.selectedSponsorId,
  });

  @override
  State<SponsorSelector> createState() => _SponsorSelectorState();
}

class _SponsorSelectorState extends State<SponsorSelector> {
  SponsorTier? _selectedTier; // null means ALL

  @override
  Widget build(BuildContext context) {
    final filteredSponsors = _selectedTier == null
        ? SponsorsData.allSponsors
        : SponsorsData.allSponsors
              .where((s) => s.tier == _selectedTier)
              .toList();

    return Column(
      children: [
        // Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterTab(null, 'ALL'),
              const SizedBox(width: 8),
              ...SponsorTier.values.map(
                (tier) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterTab(tier, tier.displayName),
                ),
              ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredSponsors.length,
            itemBuilder: (context, index) {
              final sponsor = filteredSponsors[index];
              final isSelected = widget.selectedSponsorId == sponsor.id;

              return GestureDetector(
                onTap: () => widget.onSelected(sponsor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? sponsor.primaryColor.withValues(alpha: 0.1)
                        : AppTheme.surfaceColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? sponsor.primaryColor
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: sponsor.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CustomPaint(
                          painter: SponsorLogoPainter(
                            sponsor: sponsor,
                            isSelected: isSelected,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Name
                      Text(
                        sponsor.name,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Tier Badge
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: sponsor.tier.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sponsor.tier.displayName,
                          style: GoogleFonts.sora(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: sponsor.tier.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(SponsorTier? tier, String label) {
    final isSelected = _selectedTier == tier;
    final color = tier?.color ?? Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _selectedTier = tier),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : Colors.white54,
          ),
        ),
      ),
    );
  }
}
