import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/db_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme.dart';
import '../../core/services/pdf_service.dart';
import '../auth/splash_screen.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({Key? key}) : super(key: key);

  @override
  _AdminFinanceScreenState createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> with SingleTickerProviderStateMixin {
  String _selectedPeriod = "month"; // today, week, month, year, custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  late TabController _tabController;

  final _expenseFormKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _expenseCategory = "Utilities";
  DateTime _expenseDate = DateTime.now();
  bool _isSavingExpense = false;

  final List<String> _categories = [
    "Rent",
    "Salaries",
    "Utilities",
    "Medical Supplies",
    "Marketing",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Get start/end timestamps based on period
  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedPeriod) {
      case 'today':
        return {'start': todayStart, 'end': todayEnd};
      case 'week':
        final start = now.subtract(const Duration(days: 7));
        return {'start': DateTime(start.year, start.month, start.day, 0, 0, 0), 'end': todayEnd};
      case 'month':
        final start = now.subtract(const Duration(days: 30));
        return {'start': DateTime(start.year, start.month, start.day, 0, 0, 0), 'end': todayEnd};
      case 'year':
        final start = now.subtract(const Duration(days: 365));
        return {'start': DateTime(start.year, start.month, start.day, 0, 0, 0), 'end': todayEnd};
      case 'custom':
        return {
          'start': _customStartDate ?? now.subtract(const Duration(days: 30)),
          'end': _customEndDate ?? todayEnd
        };
      default:
        final start = now.subtract(const Duration(days: 30));
        return {'start': DateTime(start.year, start.month, start.day, 0, 0, 0), 'end': todayEnd};
    }
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = "custom";
        _customStartDate = picked.start;
        _customEndDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _showAddExpenseSheet(DbService db, AuthService auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _expenseFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Log New Expense",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      DropdownButtonFormField<String>(
                        value: _expenseCategory,
                        decoration: InputDecoration(
                          labelText: "Expense Category",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          setModalState(() => _expenseCategory = val!);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: "Amount (INR)",
                          prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Amount is required";
                          if (double.tryParse(val) == null || double.parse(val) <= 0) return "Enter a valid positive number";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: "Description / Notes",
                          prefixIcon: const Icon(Icons.description_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? "Description is required" : null,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        leading: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor),
                        title: Text(
                          "Date: ${DateFormat('dd MMM yyyy').format(_expenseDate)}",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.edit_calendar_rounded, size: 20),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expenseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() => _expenseDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSavingExpense
                            ? null
                            : () async {
                                if (!_expenseFormKey.currentState!.validate()) return;
                                setModalState(() => _isSavingExpense = true);

                                try {
                                  await db.addExpense(
                                    _expenseCategory,
                                    double.parse(_amountController.text.trim()),
                                    _descController.text.trim(),
                                    _expenseDate,
                                    auth.currentUser?.name ?? "Admin Staff",
                                  );

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Expense logged successfully!")),
                                    );
                                    _amountController.clear();
                                    _descController.clear();
                                    setModalState(() {
                                      _expenseDate = DateTime.now();
                                      _expenseCategory = "Utilities";
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
                                    );
                                  }
                                } finally {
                                  setModalState(() => _isSavingExpense = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSavingExpense
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                            : const Text("Save Expense Log", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'rent':
        return Icons.business_rounded;
      case 'salaries':
        return Icons.badge_rounded;
      case 'utilities':
        return Icons.lightbulb_rounded;
      case 'medical supplies':
        return Icons.vaccines_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final auth = Provider.of<AuthService>(context);
    final range = _getDateRange();
    final start = range['start']!;
    final end = range['end']!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Finance Console"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Revenues"),
            Tab(text: "Expenses"),
          ],
        ),
      ),
      body: StreamBuilder<List<QueueItem>>(
        // Load completed/seen queue records for revenue
        stream: FirebaseFirestore.instance
            .collection("artifacts/${db.appId}/public/data/queue")
            .where("completedAt", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where("completedAt", isLessThanOrEqualTo: Timestamp.fromDate(end))
            .snapshots()
            .map((snap) => snap.docs.map((d) => QueueItem.fromFirestore(d)).toList()),
        builder: (context, revSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            // Load expenses
            stream: db.streamExpenses(),
            builder: (context, expSnap) {
              if (revSnap.connectionState == ConnectionState.waiting || expSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final revItems = revSnap.data?.where((item) => item.status == 'seen' || item.status == 'completed').toList() ?? [];
              final allExpItems = expSnap.data ?? [];

              // Filter expenses by selected date range
              final expItems = allExpItems.where((exp) {
                final dateVal = exp['date'] is Timestamp
                    ? (exp['date'] as Timestamp).toDate()
                    : (exp['date'] as DateTime? ?? DateTime.now());
                return dateVal.isAfter(start.subtract(const Duration(seconds: 1))) && dateVal.isBefore(end.add(const Duration(seconds: 1)));
              }).toList();

              // Calculations
              double totalRevenue = 0;
              for (var r in revItems) {
                totalRevenue += double.tryParse(r.fee?.toString() ?? "") ?? 0;
              }

              double totalExpenses = 0;
              final Map<String, double> categoryCosts = {};
              for (var e in expItems) {
                final amt = double.tryParse(e['amount']?.toString() ?? "") ?? 0;
                totalExpenses += amt;
                final cat = e['category']?.toString() ?? 'Other';
                categoryCosts[cat] = (categoryCosts[cat] ?? 0) + amt;
              }

              final netProfit = totalRevenue - totalExpenses;
              final margin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;
              final periodLabel = _selectedPeriod == 'custom'
                  ? "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}"
                  : _selectedPeriod.toUpperCase();

              // Generate simple rule-based AI insight
              String aiInsight = "";
              if (revItems.isEmpty) {
                aiInsight = "No patient consultations completed in this period. Focus on increasing walk-ins or running marketing campaigns.";
              } else {
                final avgRev = totalRevenue / revItems.length;
                aiInsight = "Total of ${revItems.length} patient visits. Average ticket size is INR ${avgRev.toStringAsFixed(0)}. ";
                if (totalExpenses > totalRevenue) {
                  aiInsight += "Expenses exceed revenue! Review category-wise operational overheads to restore profitability.";
                } else {
                  aiInsight += "Clinic is profitable with a margin of ${margin.toStringAsFixed(1)}%. ";
                  if (categoryCosts.isNotEmpty) {
                    final sortedCats = categoryCosts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                    aiInsight += "Your largest operational cost center is ${sortedCats.first.key} (${(sortedCats.first.value / totalExpenses * 100).toStringAsFixed(0)}% of total expenses).";
                  }
                }
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  // OVERVIEW TAB
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPeriodSelector(),
                        const SizedBox(height: 16),
                        _buildProfitLossDashboard(totalRevenue, totalExpenses, netProfit, margin),
                        const SizedBox(height: 16),
                        _buildAiInsightCard(aiInsight),
                        const SizedBox(height: 16),
                        _buildAnalyticsCharts(revItems, categoryCosts, totalExpenses),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final List<Map<String, dynamic>> flatRevenueList = revItems.map((r) => {
                              'token': r.token,
                              'name': r.name,
                              'fee': r.fee,
                              'paymentMethod': r.paymentMethod ?? 'upi',
                              'completedAt': r.completedAt ?? DateTime.now(),
                            }).toList();
                            
                            await PdfService.generateAndPrintFinancialReport(
                              periodName: periodLabel,
                              totalRevenue: totalRevenue,
                              totalExpenses: totalExpenses,
                              netProfit: netProfit,
                              profitMargin: margin,
                              visits: revItems.length,
                              aiInsight: aiInsight,
                              revenueList: flatRevenueList,
                              expensesList: expItems,
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text("Export Statement PDF", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // REVENUES TAB
                  revItems.isEmpty
                      ? const Center(
                          child: Text(
                            "No patient consultation revenues in this period.",
                            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: revItems.length,
                          itemBuilder: (ctx, index) {
                            final rev = revItems[index];
                            final feeVal = double.tryParse(rev.fee?.toString() ?? "") ?? 0;
                            final dateVal = rev.completedAt ?? DateTime.now();

                            return Card(
                              color: Colors.white,
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.black.withOpacity(0.03)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade50,
                                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.green),
                                ),
                                title: Text(rev.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  "Token: ${rev.token} • ${DateFormat('dd MMM, hh:mm a').format(dateVal)}\nMethod: ${(rev.paymentMethod ?? 'upi').toUpperCase()}",
                                  style: const TextStyle(fontSize: 12, height: 1.4),
                                ),
                                trailing: Text(
                                  "+₹${feeVal.toStringAsFixed(0)}",
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            );
                          },
                        ),

                  // EXPENSES TAB
                  Scaffold(
                    backgroundColor: Colors.transparent,
                    floatingActionButton: FloatingActionButton(
                      onPressed: () => _showAddExpenseSheet(db, auth),
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.add),
                    ),
                    body: expItems.isEmpty
                        ? const Center(
                            child: Text(
                              "No expenses logged in this period.",
                              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                            itemCount: expItems.length,
                            itemBuilder: (ctx, index) {
                              final exp = expItems[index];
                              final id = exp['id']?.toString() ?? "";
                              final category = exp['category']?.toString() ?? "Other";
                              final amountVal = double.tryParse(exp['amount']?.toString() ?? "") ?? 0;
                              final desc = exp['description']?.toString() ?? "";
                              final dateVal = exp['date'] is Timestamp
                                  ? (exp['date'] as Timestamp).toDate()
                                  : (exp['date'] as DateTime? ?? DateTime.now());

                              return Card(
                                color: Colors.white,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.black.withOpacity(0.03)),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.shade50,
                                    child: Icon(_getCategoryIcon(category), color: Colors.red.shade700),
                                  ),
                                  title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    "$desc\n${DateFormat('dd MMM yyyy').format(dateVal)}",
                                    style: const TextStyle(fontSize: 12, height: 1.4),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "-₹${amountVal.toStringAsFixed(0)}",
                                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("Delete Expense"),
                                              content: const Text("Are you sure you want to delete this expense log?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text("Cancel"),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                  child: const Text("Delete"),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await db.deleteExpense(id);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Expense deleted successfully!")),
                                            );
                                          }
                                        },
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Select Period:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox(),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
            items: const [
              DropdownMenuItem(value: "today", child: Text("Today")),
              DropdownMenuItem(value: "week", child: Text("Last 7 Days")),
              DropdownMenuItem(value: "month", child: Text("Last 30 Days")),
              DropdownMenuItem(value: "year", child: Text("Last 365 Days")),
              DropdownMenuItem(value: "custom", child: Text("Custom Range...")),
            ],
            onChanged: (val) {
              if (val == "custom") {
                _selectCustomDateRange(context);
              } else if (val != null) {
                setState(() => _selectedPeriod = val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLossDashboard(double totalRevenue, double totalExpenses, double netProfit, double margin) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard("Gross Revenue", "₹${totalRevenue.toStringAsFixed(0)}", Colors.green, Icons.arrow_upward_rounded),
        _buildMetricCard("Total Expenses", "₹${totalExpenses.toStringAsFixed(0)}", Colors.red, Icons.arrow_downward_rounded),
        _buildMetricCard("Net Profit", "₹${netProfit.toStringAsFixed(0)}", netProfit >= 0 ? Colors.green : Colors.red, Icons.currency_rupee_rounded),
        _buildMetricCard("Profit Margin", "${margin.toStringAsFixed(1)}%", AppTheme.primaryColor, Icons.percent_rounded),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ).animate().scale(duration: 200.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildAiInsightCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // soft blue tint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                "Clinic AI Insights",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCharts(List<QueueItem> revItems, Map<String, double> categoryCosts, double totalExpenses) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Visual Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          // Horizontal progress bars for Category expenses
          const Text("Expense Centers Breakdown", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
          const SizedBox(height: 10),
          categoryCosts.isEmpty
              ? const Text("No expenses to display breakdown.", style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
              : Column(
                  children: categoryCosts.entries.map((entry) {
                    final double pct = totalExpenses > 0 ? entry.value / totalExpenses : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              Text("₹${entry.value.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}
