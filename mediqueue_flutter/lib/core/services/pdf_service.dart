import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'db_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfService {
  static Future<void> generateAndSharePrescription(VisitItem visit, String patientName) async {
    final pdf = pw.Document();
    
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(visit.visitedAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Clinic Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "MediQue Clinic",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                        pw.Text(
                          "Smart Queue Care & Consultations",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Dr. ${visit.doctor}",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          "Date: $formattedDate",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.indigo900),
                pw.SizedBox(height: 16),

                // Patient Information Row
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            "Patient: ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(patientName),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text(
                            "Diagnosis/Issue: ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(visit.notes.isNotEmpty ? visit.notes : "Routine Checkup"),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Diagnosis Notes
                pw.Text(
                  "DIAGNOSIS & NOTES",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  visit.notes.isNotEmpty ? visit.notes : "No clinical notes provided.",
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),

                // Medications Section
                pw.Text(
                  "MEDICATIONS",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 6),
                if (visit.medications.isEmpty)
                  pw.Text("No medications prescribed.", style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
                else
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: visit.medications.map((med) {
                      final name = med['name'] ?? 'Medication';
                      final dosage = med['dosage'] ?? '';
                      final duration = med['duration'] ?? '';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("• ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    name,
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                                  ),
                                  if (dosage.toString().isNotEmpty || duration.toString().isNotEmpty)
                                    pw.Text(
                                      "$dosage ${duration.toString().isNotEmpty ? '($duration)' : ''}",
                                      style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                pw.SizedBox(height: 20),

                // Patient Instructions
                pw.Text(
                  "INSTRUCTIONS",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  visit.patientInstructions.isNotEmpty
                      ? visit.patientInstructions
                      : "Follow general clinic guidance.",
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 30),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Fee Paid: INR ${visit.fee.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                    pw.Text(
                      "Generated via MediQue App",
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Prescription_${patientName.replaceAll(' ', '_')}_${visit.id}',
    );
  }

  static Future<void> generateAndPrintInvoice({
    required String patientName,
    required String doctorName,
    required double amount,
    required String paymentMethod,
    required String token,
    required String reason,
  }) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "MediQue Clinic",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                        pw.Text(
                          "Official Billing Invoice",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Token: $token",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal700,
                          ),
                        ),
                        pw.Text(
                          "Date: $formattedDate",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.teal900),
                pw.SizedBox(height: 20),

                pw.Text(
                  "BILL TO:",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  patientName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Text(
                  "CONSULTANT:",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  "Dr. $doctorName",
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Description", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Amount (INR)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Medical Consultation Consultation - ${reason.isNotEmpty ? reason : 'General Checkup'}"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(amount.toStringAsFixed(2), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Payment Method: ${paymentMethod.toUpperCase()}",
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          "Status: PAID",
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Total: INR ${amount.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Center(
                  child: pw.Text(
                    "Thank you for choosing MediQue Clinic. Get well soon!",
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${patientName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<void> generatePremiumReceipt({
    required String clinicName,
    required String patientName,
    required String doctorName,
    required String invoiceId,
    required double amountPaid,
    required String paymentMethod,
    required String txnRef,
    required String approvalRefNo,
    required String responseCode,
    required String transactionId,
    required DateTime paidAt,
    required String selectedUpiApp,
    required bool isShare,
  }) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(paidAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.indigo900, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top header border design
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          clinicName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "SMART HEALTHCARE CHECKOUT",
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.amber700,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.indigo900,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            "PAYMENT RECEIPT",
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Invoice: $invoiceId",
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 16),

                // 2-Column Details Grid
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "PATIENT DETAILS",
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            patientName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo900,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            "CONSULTANT",
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            "Dr. $doctorName",
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Text(
                            "DATE & TIME",
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            formattedDate,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "UPI TRANSACTION AUDIT",
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _buildPdfAuditRow("Payment App", selectedUpiApp),
                          _buildPdfAuditRow("Txn Ref ID", txnRef),
                          _buildPdfAuditRow("Approval Ref", approvalRefNo),
                          _buildPdfAuditRow("Response Code", responseCode),
                          _buildPdfAuditRow("Transaction ID", transactionId),
                          _buildPdfAuditRow("Method", paymentMethod),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),

                // Table of charges
                pw.Text(
                  "CHARGES BREAKDOWN",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo50,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Service Description", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Quantity", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Amount (INR)", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Professional Consultation & Clinical Checkout Fee", style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("1", style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(amountPaid.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Total Summary Row aligned to right
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 200,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.indigo900,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Total Amount Paid", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.Text("INR ${amountPaid.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Fraud Disclaimer / Internal Validation Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 6,
                            height: 6,
                            decoration: const pw.BoxDecoration(color: PdfColors.green700, shape: pw.BoxShape.circle),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            "SECURITY AUDIT DISCLOSURE",
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "This receipt has been generated following client-side UPI intent callback validation. The transaction reference (${txnRef.isNotEmpty ? txnRef : 'N/A'}) and approval reference (${approvalRefNo.isNotEmpty ? approvalRefNo : 'N/A'}) are registered locally for merchant verification. This is a hackathon/demo verification trail.",
                        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    "MediQue Queue Management Suite — Thank you for choosing smart care.",
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    if (isShare) {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'MediQue_Receipt_${invoiceId.replaceAll(' ', '_')}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'MediQue_Receipt_${invoiceId.replaceAll(' ', '_')}',
      );
    }
  }

  static pw.Widget _buildPdfAuditRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("$label: ", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(value.isNotEmpty ? value : "N/A", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static Future<void> generateAndPrintFinancialReport({
    required String periodName,
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required double profitMargin,
    required int visits,
    required String aiInsight,
    required List<Map<String, dynamic>> revenueList,
    required List<Map<String, dynamic>> expensesList,
  }) async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "MediQue Clinic",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal900,
                      ),
                    ),
                    pw.Text(
                      "Financial Statement & Analysis Report",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Period: $periodName",
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal700,
                      ),
                    ),
                    pw.Text(
                      "Generated: $formattedDate",
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.teal900),
            pw.SizedBox(height: 16),

            // Financial Summary Block
            pw.Text(
              "FINANCIAL SUMMARY",
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryCol("Total Revenue", "INR ${totalRevenue.toStringAsFixed(2)}", PdfColors.green800),
                  _buildSummaryCol("Total Expenses", "INR ${totalExpenses.toStringAsFixed(2)}", PdfColors.red800),
                  _buildSummaryCol("Net Profit", "INR ${netProfit.toStringAsFixed(2)}", netProfit >= 0 ? PdfColors.green800 : PdfColors.red800),
                  _buildSummaryCol("Profit Margin", "${profitMargin.toStringAsFixed(1)}%", PdfColors.teal800),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // AI Insights
            if (aiInsight.isNotEmpty) ...[
              pw.Text(
                "BUSINESS INSIGHTS",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.indigo100),
                ),
                child: pw.Text(
                  aiInsight,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.indigo900, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Expenses Breakdown
            pw.Text(
              "EXPENSES REGISTER (${expensesList.length} items)",
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
            ),
            pw.SizedBox(height: 8),
            if (expensesList.isEmpty)
              pw.Text("No expenses logged in this period.", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))
            else
              pw.Table(
                border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300)),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader("Category"),
                      _buildTableHeader("Description"),
                      _buildTableHeader("Amount"),
                      _buildTableHeader("Date"),
                    ],
                  ),
                  ...expensesList.map((exp) {
                    final dateVal = exp['date'] is Timestamp
                        ? (exp['date'] as Timestamp).toDate()
                        : (exp['date'] as DateTime? ?? DateTime.now());
                    final dateStr = DateFormat('dd MMM yyyy').format(dateVal);
                    return pw.TableRow(
                      children: [
                        _buildTableCell(exp['category']?.toString() ?? ""),
                        _buildTableCell(exp['description']?.toString() ?? ""),
                        _buildTableCell("INR ${(exp['amount'] as num? ?? 0).toStringAsFixed(2)}"),
                        _buildTableCell(dateStr),
                      ],
                    );
                  }).toList(),
                ],
              ),
            pw.SizedBox(height: 20),

            // Revenue Stream
            pw.Text(
              "REVENUE STREAM LISTING (${revenueList.length} visits)",
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
            ),
            pw.SizedBox(height: 8),
            if (revenueList.isEmpty)
              pw.Text("No consultation revenues in this period.", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))
            else
              pw.Table(
                border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300)),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader("Token"),
                      _buildTableHeader("Patient"),
                      _buildTableHeader("Fee"),
                      _buildTableHeader("Method"),
                      _buildTableHeader("Date"),
                    ],
                  ),
                  ...revenueList.map((rev) {
                    final dateVal = rev['completedAt'] is Timestamp
                        ? (rev['completedAt'] as Timestamp).toDate()
                        : (rev['completedAt'] as DateTime? ?? DateTime.now());
                    final dateStr = DateFormat('dd MMM yyyy').format(dateVal);
                    return pw.TableRow(
                      children: [
                        _buildTableCell(rev['token']?.toString() ?? ""),
                        _buildTableCell(rev['name']?.toString() ?? "Patient"),
                        _buildTableCell("INR ${(double.tryParse(rev['fee']?.toString() ?? "") ?? 0).toStringAsFixed(2)}"),
                        _buildTableCell((rev['paymentMethod']?.toString() ?? "upi").toUpperCase()),
                        _buildTableCell(dateStr),
                      ],
                    );
                  }).toList(),
                ],
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await pdf.save(),
      name: 'MediQue_Financial_Report_${periodName.replaceAll(' ', '_')}',
    );
  }

  static pw.Widget _buildSummaryCol(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildTableCell(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        value,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }
}

