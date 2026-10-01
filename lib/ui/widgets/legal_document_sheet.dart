import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

enum LegalTab { privacy, terms }

class LegalDocumentSheet extends StatefulWidget {
  final LegalTab initialTab;

  const LegalDocumentSheet({
    super.key,
    this.initialTab = LegalTab.privacy,
  });

  static void show(BuildContext context, {LegalTab initialTab = LegalTab.privacy}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LegalDocumentSheet(initialTab: initialTab),
    );
  }

  @override
  State<LegalDocumentSheet> createState() => _LegalDocumentSheetState();
}

class _LegalDocumentSheetState extends State<LegalDocumentSheet> {
  late LegalTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar with Done button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Legal',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.deepNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Clean iOS Segmented Style Tabs (Monochrome neutral)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: 'Privacy Policy',
                      tab: LegalTab.privacy,
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      title: 'Terms of Service',
                      tab: LegalTab.terms,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),

          // Scrollable Document Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
              child: _currentTab == LegalTab.privacy
                  ? _buildPrivacyPolicyContent()
                  : _buildTermsOfServiceContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String title, required LegalTab tab}) {
    final isSelected = _currentTab == tab;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() => _currentTab = tab);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  // --- PRIVACY POLICY CONTENT (Apple 5.1.1 + Google Play Location Policy + Australian Privacy Act 1988) ---
  Widget _buildPrivacyPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'KiloTax Privacy Policy',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Effective Date: September 2026',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.muted,
          ),
        ),
        SizedBox(height: 20),

        _LegalSection(
          title: '1. Overview & Compliance Framework',
          content:
              'KiloTax ("we", "us", or "our") respects your fundamental right to privacy. We handle your personal and telemetry information in strict compliance with the Australian Privacy Principles (APPs) set out in the Privacy Act 1988 (Cth), Apple App Store Review Guidelines (Section 5.1.1), and Google Play User Data & Location Policies.',
        ),

        _LegalSection(
          title: '2. Location & Background Tracking Disclosures (Google Play & Apple Compliant)',
          content:
              'To automatically detect business trips and generate Australian Taxation Office (ATO) compliant vehicle logbooks, KiloTax accesses your device\'s precise location (GPS) and physical activity/motion sensors.\n\n'
              '• Prominent Disclosure: KiloTax collects location data to calculate trip distances, start/end locations, and route logs even when the app is closed or not in use, strictly for automated trip detection.\n'
              '• Absolute Purpose Limitation: Location data is exclusively used for your mileage logbook deductions and is never shared, rented, or sold to third-party advertisers, data brokers, or insurance companies.\n'
              '• Full User Control: Automated background trip detection can be paused or disabled at any time in the app settings, allowing purely manual trip entry.',
        ),

        _LegalSection(
          title: '3. Financial Receipts & Expenses Data',
          content:
              'When you capture fuel receipts, vehicle maintenance invoices, or work-related expenses:\n\n'
              '• OCR receipt text parsing occurs through isolated, sandboxed cloud processors.\n'
              '• Receipts and tax invoices are encrypted in transit (TLS 1.3) and at rest (AES-256) within your dedicated account vault.',
        ),

        _LegalSection(
          title: '4. Data Retention & ATO 5-Year Requirement',
          content:
              'Under ATO taxation rules, business vehicle logbooks and deduction evidence must be retained for 5 years. KiloTax stores your finalized tax logs in your secure cloud vault to preserve your audit defense trail. You retain full ownership to export your records at any time.',
        ),

        _LegalSection(
          title: '5. Account Deletion & Complete Data Purge (Apple 5.1.1(v) Compliant)',
          content:
              'In accordance with Apple App Store Guideline 5.1.1(v) and Google Play account deletion mandates, you have the unconditional right to delete your account and all associated data directly within the app.\n\n'
              'To delete your account: Navigate to Account Settings → tap "Delete Account & All Data".\n\n'
              'Upon confirmation, all personal information, GPS routes, trip logs, scanned receipts, and cloud backups are permanently and irrevocably deleted from our live servers and databases within 30 days.',
        ),

        _LegalSection(
          title: '6. Privacy Inquiries & Contact',
          content:
              'If you have questions regarding this Privacy Policy or wish to exercise your privacy rights, contact our Data Protection Officer at methaspak@gmail.com.',
        ),
      ],
    );
  }

  // --- TERMS OF SERVICE CONTENT (Apple 3.1.2 Auto-Renewing Subscriptions + Australian Consumer Law + TPB Disclaimer) ---
  Widget _buildTermsOfServiceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'KiloTax Terms of Service',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Effective Date: September 2026',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.muted,
          ),
        ),
        SizedBox(height: 20),

        _LegalSection(
          title: '1. Tax & Legal Advice Disclaimer',
          content:
              'KiloTax is a mileage tracking and record-keeping software tool designed to assist Australian sole traders, tradies, and businesses in maintaining records in line with ATO guidelines. KiloTax is NOT a Registered Tax Agent with the Tax Practitioners Board (TPB) or a financial advisory firm. The software and its generated summaries do not constitute tax, financial, or legal advice. Users must verify all deductions and consult a licensed tax agent or accountant before lodging returns.\n\n'
              'KiloTax is an independent software application and is NOT affiliated with, endorsed by, or connected to the Australian Taxation Office (ATO). Statutory mileage rates (e.g. 91c/km for 2026-27) are sourced from publicly available ATO published rates at ato.gov.au.',
        ),

        _LegalSection(
          title: '2. User Responsibility for ATO Compliance',
          content:
              'The taxpayer is legally accountable to the ATO for the truthfulness, classification (Business vs Personal), and stated purpose of every logged trip. You agree to inspect and confirm the accuracy of your logbook entries and receipts before utilizing them for tax deduction claims.',
        ),

        _LegalSection(
          title: '3. In-App Subscriptions & Billing (Apple App Store & Google Play Terms)',
          content:
              'Access to automated trip tracking, OCR receipt scanning, and ATO audit export reports requires an active subscription.\n\n'
              '• Payment: Payment is charged to your Apple ID or Google Play Account at confirmation of purchase.\n'
              '• Auto-Renewal: Subscriptions automatically renew unless auto-renew is cancelled at least 24 hours before the end of the current billing cycle.\n'
              '• Renewal Charges: Your account is charged for renewal within 24 hours prior to the end of the current period at the rate of the selected plan.\n'
              '• Subscription Management: You can manage or cancel your subscription at any time via your device Account Settings (App Store or Google Play Subscriptions). Any unused portion of a free trial period is forfeited when purchasing a subscription.',
        ),

        _LegalSection(
          title: '4. Intellectual Property & License',
          content:
              'We grant you a revocable, non-exclusive, non-transferable license to download, install, and use KiloTax for personal or sole trader record-keeping in accordance with these Terms.',
        ),

        _LegalSection(
          title: '5. Limitation of Liability & Consumer Guarantees',
          content:
              'Our services come with non-excludable guarantees under Australian Consumer Law (Competition and Consumer Act 2010). Subject to those non-excludable rights, KiloTax shall not be liable for any indirect, incidental, or tax-related penalties, fines, or loss of deductions arising from device inaccuracies, signal loss, user misclassification, or system interruption.',
        ),

        _LegalSection(
          title: '6. Governing Law & Jurisdiction',
          content:
              'These Terms are governed by and construed in accordance with the laws of New South Wales and the Commonwealth of Australia. Any disputes arising hereunder shall be subject to the exclusive jurisdiction of the courts of New South Wales, Australia.',
        ),

        _LegalSection(
          title: '7. Customer Support & Inquiries',
          content:
              'For any legal, technical, or customer support questions, contact us directly at methaspak@gmail.com.',
        ),
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String content;

  const _LegalSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.52,
            ),
          ),
        ],
      ),
    );
  }
}
