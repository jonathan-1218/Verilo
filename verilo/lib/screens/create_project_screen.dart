import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

const _radiusMeters = {'250m': 250.0, '500m': 500.0, '1km': 1000.0, 'Custom': 500.0};

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  int _step = 0;
  String _selectedCategory = 'WASH';
  final List<String> _selectedSDGs = ['SDG4', 'SDG6'];
  String _selectedInterval = 'Quarterly';
  String _selectedRadius = '500m';
  DateTime? _startDate;
  DateTime? _endDate;
  double? _lat, _lng;
  bool _locating = false;
  bool _creating = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _siteNameCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _siteNameCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final pos = await locationService.currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) { _lat = pos.latitude; _lng = pos.longitude; }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _next() async {
    if (_step == 0 && _nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Project name is required');
      return;
    }
    if (_step == 2 && _startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'End date must be after the start date');
      return;
    }
    setState(() => _error = null);
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    setState(() => _creating = true);
    try {
      final budget = (double.tryParse(_budgetCtrl.text.replaceAll(',', '').replaceAll('₹', '')) ?? 0);
      final project = await appRepository.createProject(
        name: _nameCtrl.text.trim(),
        category: _selectedCategory,
        location: _siteNameCtrl.text.trim().isEmpty ? _nameCtrl.text.trim() : _siteNameCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        geofenceMeters: _radiusMeters[_selectedRadius] ?? 500,
        sdgTags: _selectedSDGs,
        description: _descCtrl.text.trim(),
        budgetCents: (budget * 100).round(),
        startDate: _startDate,
        endDate: _endDate,
        reviewInterval: _selectedInterval,
      );
      if (mounted) context.go('/project/${project.id}');
    } catch (e) {
      setState(() => _error = 'Could not create project: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            children: [
              _StepHeader(step: _step, onBack: _step > 0 ? () => setState(() => _step--) : null),
              _StepProgress(step: _step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    child: _stepContent(),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_error!, style: AppText.spaceGrotesk(size: 12, color: AppColors.red)),
                  ),
                ),
              _BottomCTAs(
                step: _step,
                busy: _creating,
                onBack: _step > 0 ? () => setState(() => _step--) : null,
                onNext: _next,
              ),
            ],
          ),
        ),
      );

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _Step1(
          nameCtrl: _nameCtrl, descCtrl: _descCtrl,
          selectedCategory: _selectedCategory, selectedSDGs: _selectedSDGs,
          onCategoryChanged: (v) => setState(() => _selectedCategory = v),
          onSDGToggled: (v) => setState(() => _selectedSDGs.contains(v) ? _selectedSDGs.remove(v) : _selectedSDGs.add(v)),
        );
      case 1:
        return _Step2(
          siteNameCtrl: _siteNameCtrl, districtCtrl: _districtCtrl, stateCtrl: _stateCtrl,
          selectedRadius: _selectedRadius, lat: _lat, lng: _lng, locating: _locating,
          onRadiusChanged: (v) => setState(() => _selectedRadius = v),
          onUseLocation: _useCurrentLocation,
        );
      case 2:
        return _Step3(
          budgetCtrl: _budgetCtrl,
          selectedInterval: _selectedInterval, startDate: _startDate, endDate: _endDate,
          onIntervalChanged: (v) => setState(() => _selectedInterval = v),
          onPickStart: () => _pickDate(isStart: true),
          onPickEnd: () => _pickDate(isStart: false),
        );
      case 3:
        return _Step4(
          name: _nameCtrl.text, category: _selectedCategory,
          district: _districtCtrl.text, state: _stateCtrl.text,
          startDate: _startDate, endDate: _endDate, budget: _budgetCtrl.text,
          interval: _selectedInterval,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onBack});
  final int step;
  final VoidCallback? onBack;

  static const _titles = ['Basic Info', 'Location', 'Timeline & Budget', 'Team + Summary'];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_titles[step], style: AppText.screenTitle)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.copperMid.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${step + 1} / 4',
                  style: AppText.spaceGrotesk(size: 12, weight: FontWeight.w600, color: AppColors.copperMid)),
            ),
          ],
        ),
      );
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Container(
        height: 3,
        color: AppColors.bgPlaceholder,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          widthFactor: (step + 1) / 4,
          child: Container(decoration: const BoxDecoration(gradient: AppColors.copperGradient)),
        ),
      );
}

class _BottomCTAs extends StatelessWidget {
  const _BottomCTAs({required this.step, required this.busy, required this.onBack, required this.onNext});
  final int step;
  final bool busy;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          color: AppColors.bgApp,
        ),
        child: Row(
          children: [
            if (step > 0) ...[
              Expanded(
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text('← Back', style: AppText.spaceGrotesk(size: 14, color: AppColors.textSecondary)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: CopperButton(
                label: busy ? 'Creating…' : (step < 3 ? 'Next →' : 'Create Project ✓'),
                onTap: busy ? () {} : onNext,
              ),
            ),
          ],
        ),
      );
}

// ── Step 1: Basic Info ──────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  const _Step1({
    required this.nameCtrl, required this.descCtrl,
    required this.selectedCategory, required this.selectedSDGs,
    required this.onCategoryChanged, required this.onSDGToggled,
  });
  final TextEditingController nameCtrl, descCtrl;
  final String selectedCategory;
  final List<String> selectedSDGs;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSDGToggled;

  static const _categories = ['WASH', 'Education', 'Skill Dev', 'Health', 'Environment'];
  static const _sdgs = ['SDG1', 'SDG2', 'SDG3', 'SDG4', 'SDG6', 'SDG8', 'SDG13', 'SDG17'];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROJECT DETAILS', style: AppText.label),
          const SizedBox(height: 14),
          AppTextField(label: 'Project name', hint: 'e.g. Nandgram School WASH', controller: nameCtrl),
          const SizedBox(height: 16),
          Text('CATEGORY', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) => _SelectChip(
            label: c, active: c == selectedCategory, onTap: () => onCategoryChanged(c),
          )).toList()),
          const SizedBox(height: 16),
          Text('SDG TAGS', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _sdgs.map((s) => _SelectChip(
            label: s, active: selectedSDGs.contains(s), onTap: () => onSDGToggled(s),
          )).toList()),
          const SizedBox(height: 16),
          AppTextField(label: 'Description (optional)', hint: 'Describe the project goals…', controller: descCtrl, maxLines: 3),
        ],
      );
}

// ── Step 2: Location ────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  const _Step2({
    required this.siteNameCtrl, required this.districtCtrl, required this.stateCtrl,
    required this.selectedRadius, required this.lat, required this.lng, required this.locating,
    required this.onRadiusChanged, required this.onUseLocation,
  });
  final TextEditingController siteNameCtrl, districtCtrl, stateCtrl;
  final String selectedRadius;
  final double? lat, lng;
  final bool locating;
  final ValueChanged<String> onRadiusChanged;
  final VoidCallback onUseLocation;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LOCATION', style: AppText.label),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onUseLocation,
            child: Container(
              height: 148,
              decoration: BoxDecoration(color: const Color(0xFF2A2218), borderRadius: BorderRadius.circular(12)),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MiniMapPainter())),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (locating)
                          const CircularProgressIndicator(color: AppColors.copperMid)
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              lat != null ? '${lat!.toStringAsFixed(4)}°N ${lng!.toStringAsFixed(4)}°E' : 'Tap to use current GPS',
                              style: AppText.jetBrainsMono(size: 10, color: AppColors.copperMid),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Site name (optional)', hint: 'e.g. Nandgram Village School', controller: siteNameCtrl),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: AppTextField(label: 'District', hint: 'Raigad', controller: districtCtrl)),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(label: 'State', hint: 'Maharashtra', controller: stateCtrl)),
          ]),
          const SizedBox(height: 16),
          Text('GEOFENCE RADIUS', style: AppText.label),
          const SizedBox(height: 8),
          Row(children: ['250m', '500m', '1km', 'Custom'].map((r) =>
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SelectChip(label: r, active: r == selectedRadius, onTap: () => onRadiusChanged(r)),
            )
          ).toList()),
        ],
      );
}

// ── Step 3: Timeline & Budget ────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  const _Step3({
    required this.budgetCtrl, required this.selectedInterval, required this.startDate, required this.endDate,
    required this.onIntervalChanged, required this.onPickStart, required this.onPickEnd,
  });
  final TextEditingController budgetCtrl;
  final String selectedInterval;
  final DateTime? startDate, endDate;
  final ValueChanged<String> onIntervalChanged;
  final VoidCallback onPickStart, onPickEnd;

  static const _intervals = ['Monthly', 'Quarterly', 'Biannual', 'Annual'];

  String _fmt(DateTime? d) => d == null ? 'DD/MM/YYYY' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final months = (startDate != null && endDate != null) ? (endDate!.difference(startDate!).inDays / 30).round() : 0;
    final reviews = {'Monthly': 12, 'Quarterly': 4, 'Biannual': 2, 'Annual': 1}[selectedInterval] ?? 4;
    final budget = double.tryParse(budgetCtrl.text.replaceAll(',', '')) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onPickStart,
              child: AbsorbPointer(child: AppTextField(label: 'Start date', hint: _fmt(startDate), icon: Icons.calendar_today)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onPickEnd,
              child: AbsorbPointer(child: AppTextField(label: 'End date', hint: _fmt(endDate), icon: Icons.calendar_today)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Text('REVIEW INTERVAL', style: AppText.label),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _intervals.map((i) => _SelectChip(
          label: i, active: i == selectedInterval, onTap: () => onIntervalChanged(i),
        )).toList()),
        const SizedBox(height: 16),
        AppTextField(label: 'Budget in ₹ (optional)', hint: '5,00,000', controller: budgetCtrl, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        CardSurface(
          elevated: true,
          child: Column(children: [
            _SummaryRow('Duration', months > 0 ? '$months months' : '—'),
            const SizedBox(height: 8),
            _SummaryRow('No. of reviews', '$reviews'),
            const SizedBox(height: 8),
            _SummaryRow('Budget per review', reviews > 0 ? '₹${(budget / reviews).round()}' : '—'),
          ]),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: AppText.spaceGrotesk(size: 12, color: AppColors.textMuted)),
          const Spacer(),
          Text(value, style: AppText.spaceGrotesk(size: 12, weight: FontWeight.w600)),
        ],
      );
}

// ── Step 4: Summary ──────────────────────────────────────────────────────────

class _Step4 extends StatelessWidget {
  const _Step4({
    required this.name, required this.category, required this.district, required this.state,
    required this.startDate, required this.endDate, required this.budget, required this.interval,
  });
  final String name, category, district, state, budget, interval;
  final DateTime? startDate, endDate;

  String _fmt(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TEAM', style: AppText.label),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.copperDark, AppColors.copperMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(currentOfficerName.isNotEmpty ? currentOfficerName[0].toUpperCase() : '?',
                    style: AppText.spaceGrotesk(size: 14, weight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(currentOfficerName, style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600))),
              StatusChip(label: 'LEAD', color: AppColors.copperMid),
            ],
          ),
          const SizedBox(height: 8),
          Text('Team invites for other officers aren\'t available yet.',
              style: AppText.spaceGrotesk(size: 11, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          Text('PROJECT SUMMARY', style: AppText.label),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCardElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.copperMid.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _SummaryRow('Project', name.isEmpty ? '—' : name),
              const SizedBox(height: 8),
              _SummaryRow('Category', category),
              const SizedBox(height: 8),
              _SummaryRow('Location', [district, state].where((s) => s.isNotEmpty).join(', ').isEmpty ? '—' : [district, state].where((s) => s.isNotEmpty).join(', ')),
              const SizedBox(height: 8),
              _SummaryRow('Duration', '${_fmt(startDate)} – ${_fmt(endDate)}'),
              const SizedBox(height: 8),
              _SummaryRow('Budget', '₹${budget.isEmpty ? '0' : budget}'),
              const SizedBox(height: 8),
              _SummaryRow('Reviews', interval),
            ]),
          ),
        ],
      );
}

// ── Shared form widgets ──────────────────────────────────────────────────────

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.copperMid : AppColors.bgCard,
            border: Border.all(color: active ? AppColors.copperMid : AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: AppText.spaceGrotesk(
            size: 12, weight: FontWeight.w500,
            color: active ? Colors.white : AppColors.textSecondary,
          )),
        ),
      );
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += 30) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
  }

  @override
  bool shouldRepaint(_) => false;
}
