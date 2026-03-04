import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/legal/legal_content.dart';
import '../../../theme/app_theme.dart';

/// Full-screen Terms of Service and Privacy Policy viewer.
///
/// Opened from [LoginScreen] when the user taps "Terms of Service" or
/// "Privacy Policy". Supports tab-based switching between the two documents.
///
/// [onAccept] is called when the user taps ACCEPT & CONTINUE. When null,
/// the accept button is hidden (read-only mode from settings/profile).
class TermsScreen extends StatefulWidget {
  /// When non-null, show the ACCEPT button and call this on acceptance.
  final VoidCallback? onAccept;

  /// Which tab to open initially: 0 = Terms, 1 = Privacy.
  final int initialTab;

  const TermsScreen({super.key, this.onAccept, this.initialTab = 0});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(_onTabChanged);

    // If no accept button needed, we don't require scrolling to bottom.
    if (widget.onAccept == null) {
      _hasScrolledToBottom = true;
    } else {
      _scrollController.addListener(_onScroll);
    }
  }

  void _onTabChanged() {
    // Reset scroll tracking when switching tabs.
    if (widget.onAccept != null) {
      setState(() => _hasScrolledToBottom = false);
      _scrollController.jumpTo(0);
    }
  }

  void _onScroll() {
    if (_hasScrolledToBottom) return;
    final pos = _scrollController.position;
    // Consider "read" when within 120px of the bottom.
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildTabView()),
          if (widget.onAccept != null) _buildAcceptButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.backgroundStart,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'LEGAL',
        style: GoogleFonts.bebasNeue(
          fontSize: 20,
          color: AppTheme.textPrimary,
          letterSpacing: 3,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.electricBlue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.electricBlue.withValues(alpha: 0.4),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.sora(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: GoogleFonts.sora(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelColor: AppTheme.electricBlue,
        unselectedLabelColor: AppTheme.textSecondary,
        tabs: const [
          Tab(text: 'Terms of Service'),
          Tab(text: 'Privacy Policy'),
        ],
      ),
    );
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDocumentPage(kTermsOfService),
        _buildDocumentPage(kPrivacyPolicy),
      ],
    );
  }

  Widget _buildDocumentPage(String content) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Version $kLegalVersion · Effective $kLegalEffectiveDate',
              style: GoogleFonts.sora(fontSize: 10, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 16),

          // Document content
          _buildLegalText(content),

          const SizedBox(height: 16),

          // Contact block
          _buildContactBlock(),

          // Scroll prompt when accept button is visible
          if (widget.onAccept != null && !_hasScrolledToBottom) ...[
            const SizedBox(height: 24),
            _buildScrollPrompt(),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLegalText(String content) {
    final lines = content.trim().split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Section separator lines (────)
      if (line.contains('────')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.07),
              thickness: 1,
            ),
          ),
        );
        continue;
      }

      // Title (ALL CAPS, first non-empty line of block)
      if (line.startsWith('TERMS OF SERVICE') ||
          line.startsWith('PRIVACY POLICY')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: GoogleFonts.bebasNeue(
                fontSize: 26,
                color: AppTheme.textPrimary,
                letterSpacing: 2,
              ),
            ),
          ),
        );
        continue;
      }

      // Numbered section headers (e.g. "1. ACCEPTANCE OF TERMS")
      final sectionHeaderPattern = RegExp(r'^\d+\. [A-Z]');
      if (sectionHeaderPattern.hasMatch(line)) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
        widgets.add(
          Text(
            line,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.electricBlue,
              letterSpacing: 0.3,
            ),
          ),
        );
        continue;
      }

      // Sub-section headers (e.g. "4.1 Account Creation")
      final subSectionPattern = RegExp(r'^\d+\.\d+ ');
      if (subSectionPattern.hasMatch(line)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              line,
              style: GoogleFonts.sora(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        );
        continue;
      }

      // Effective date / metadata lines
      if (line.startsWith('Effective Date:') ||
          line.startsWith('Version:') ||
          line.startsWith('Last updated:')) {
        widgets.add(
          Text(
            line,
            style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted),
          ),
        );
        continue;
      }

      // Bullet point lines (starting with •)
      if (line.trimLeft().startsWith('•')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.trimLeft().substring(1).trim(),
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Indented bullet (4-space indent + •)
      if (line.startsWith('    •')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '·',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.trim().substring(1).trim(),
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // "PLEASE READ" warning block
      if (line.startsWith('PLEASE READ')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.electricBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.electricBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              line,
              style: GoogleFonts.sora(
                fontSize: 11,
                color: AppTheme.electricBlue.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        );
        continue;
      }

      // Closing tagline
      if (line == '"Run. Conquer. Reset."') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              line,
              style: GoogleFonts.bebasNeue(
                fontSize: 16,
                color: AppTheme.electricBlue.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
          ),
        );
        continue;
      }

      // Empty lines → small spacer
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      // Regular body text
      widgets.add(
        Text(
          line,
          style: GoogleFonts.sora(
            fontSize: 12,
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildContactBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline_rounded, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Text(
            kLegalContactEmail,
            style: GoogleFonts.sora(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollPrompt() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.keyboard_double_arrow_down_rounded,
            size: 14,
            color: AppTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            'Scroll to read the full document',
            style: GoogleFonts.sora(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundStart,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _hasScrolledToBottom ? widget.onAccept : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.electricBlue,
            disabledBackgroundColor: AppTheme.surfaceColor,
            foregroundColor: Colors.white,
            disabledForegroundColor: AppTheme.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(
            _hasScrolledToBottom ? 'ACCEPT & CONTINUE' : 'SCROLL TO READ',
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
