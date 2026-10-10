import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LugopApp());
}

class LugopApp extends StatelessWidget {
  const LugopApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUGOP RMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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

  // Your actual portal links
  final String markEntryUrl = 'https://lugopvisionaryrms.github.io/lugop-portal/?school=thunga%20cdss';
  final String reportPortalUrl = 'https://script.google.com/macros/s/AKfycbwwSN3nPb9BTtblvnsPaG_r2WIAezI0L045IGvucUJ9h6WLiZkcfEiTqUCd6BSeFcm_/exec?school=thunga%20cdss';

  String currentSubtitle = 'Mark Entry';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // FIXED: Channel name is now "PdfDownloadChannel" to match Google Apps Script
      ..addJavaScriptChannel(
        'PdfDownloadChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          await _saveAndOpenPdfFromJson(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(markEntryUrl));
  }

  // FIXED: Correctly reads the JSON package from Google Apps Script and saves the PDF
  Future<void> _saveAndOpenPdfFromJson(String jsonPayload) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading LUGOP Report Card...'),
          backgroundColor: Color(0xFF0066CC),
          duration: Duration(seconds: 2),
        ),
      );

      final data = jsonDecode(jsonPayload);
      final String base64String = data['base64'];
      final String fileName = data['fileName'] ?? 'Report.pdf';

      String cleanBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      cleanBase64 = cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim();

      final bytes = base64Decode(cleanBase64);
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await controller.canGoBack()) {
          await controller.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0066CC),
          elevation: 0,
          title: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/logo.png',
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.school, color: Color(0xFF0066CC)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LUGOP RMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    currentSubtitle,
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.white),
              onSelected: (String value) {
                setState(() {
                  isLoading = true;
                });
                if (value == 'mark_entry') {
                  setState(() => currentSubtitle = 'Mark Entry');
                  controller.loadRequest(Uri.parse(markEntryUrl));
                } else if (value == 'report_portal') {
                  setState(() => currentSubtitle = 'Report Portal');
                  controller.loadRequest(Uri.parse(reportPortalUrl));
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'mark_entry',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Mark Entry'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'report_portal',
                  child: Row(
                    children: [
                      Icon(Icons.assessment, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Report Portal'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading)
              Container(
                color: Colors.white,
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
      ),
    );
  }
}