// lib/screens/report_problem_screen.dart
//
// "Report a problem" — a user-initiated diagnostics report. The user describes
// what went wrong and sends the report through the OS share sheet / their email
// app. Nothing is ever uploaded silently — the user chooses the target and hits
// send. This never touches the arm → track → alarm spine.

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/telemetry/telemetry_report_builder.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key, this.crashedLastSession = false});

  /// When true the report is framed as a crash report and pre-notes it.
  final bool crashedLastSession;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = await TelemetryReportBuilder.build(
      userNote: _note.text,
      crashedLastSession: widget.crashedLastSession,
    );
    await Share.share(text, subject: 'GeoWake diagnostics');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us what went wrong. No location or personal data is included, '
                'and nothing is sent until you choose where to send the report.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "e.g. the alarm didn't go off near my stop…",
                ),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.send),
                label: const Text('Send report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
