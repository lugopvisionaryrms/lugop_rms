import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

void main() {
  runApp(const LugopApp());
}

class LugopApp extends StatelessWidget {
  const LugopApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUGOP RMS',
      debugShowCheckedModeBanner: false,
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;

  // IMPORTANT: Paste your actual LUGOP Web Portal links here!
  final String markEntryUrl = 'https://lugopvisionaryrms.github.io/lugop-portal/?school=thunga%20cdss';
  final String reportPortalUrl = 'https://script.google.com/macros/s/AKfycbwwSN3nPb9BTtblvnsPaG_r2WIAezI0L045IGvucUJ9h6WLiZkcfEiTqUCd6BSeFcm_/exec?school=thunga%20cdss';

  String currentSubtitle = 'Mark Entry';
  bool isLoading = true; // Controls the spinning loading sign

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // This channel catches the Base64 PDF from your Google Apps Script
      ..addJavaScriptChannel(
        'PdfDownloader',
        onMessageReceived: (JavaScriptMessage message) async {
          await _saveAndOpenBase64Pdf(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() { isLoading = true; }); // Show spinner when loading starts
          },
          onPageFinished: (String url) async {
            setState(() { isLoading = false; }); // Hide spinner when loading finishes
            
            // This JavaScript automatically intercepts the Base64 PDF download button
            // and redirects the data directly to our Flutter App instead of blocking it.
            await controller.runJavaScript('''
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a');
                if (a && a.href && a.href.startsWith('data:application/pdf;base64')) {
                  e.preventDefault();
                  window.PdfDownloader.postMessage(a.href);
                }
              }, true);
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(markEntryUrl));
  }

  // Magic function that turns your Apps Script Base64 string into a real PDF file
  Future<void> _saveAndOpenBase64Pdf(String base64String) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading LUGOP Report Card...'),
          backgroundColor: Color(0xFF0066CC),
        ),
      );

      // Clean the string (remove the "data:application/pdf;base64," part if it exists)
      final cleanBase64 = base64String.contains(',') 
          ? base64String.split(',').last 
          : base64String;

      // Decode and save to phone storage
      final bytes = base64Decode(cleanBase64);
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/LUGOP_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Open the PDF automatically
      await OpenFile.open(file.path);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0066CC),
        elevation: 0,
        title: Row(
          children: [
            Container(
              height: 40, width: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/logo.png'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LUGOP RMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(currentSubtitle, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: (String value) {
              setState(() { isLoading = true; }); // Show spinner instantly on click
              if (value == 'mark_entry') {
                setState(() => currentSubtitle = 'Mark Entry');
                controller.loadRequest(Uri.parse(markEntryUrl));
              } else if (value == 'report_portal') {
                setState(() => currentSubtitle = 'Report Portal');
                controller.loadRequest(Uri.parse(reportPortalUrl));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'mark_entry', child: Row(children: [Icon(Icons.edit_note, color: Colors.blue), SizedBox(width: 8), Text('Mark Entry')])),
              const PopupMenuItem<String>(value: 'report_portal', child: Row(children: [Icon(Icons.assessment, color: Colors.green), SizedBox(width: 8), Text('Report Portal')])),
            ],
          ),
        ],
      ),
      // The Stack puts the spinning loader right on top of the web portal while it loads
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          
          if (isLoading)
            Container(
              color: Colors.white, // Covers the screen with white while loading
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0066CC)),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading LUGOP RMS Portal...',
                      style: TextStyle(
                        color: Color(0xFF0066CC),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}