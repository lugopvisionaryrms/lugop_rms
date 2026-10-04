import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // IMPORTANT: Paste your actual LUGOP Web Portal links here
  final String markEntryUrl = 'https://lugopvisionaryrms.github.io/lugop-portal/?school=thunga%20cdss';
  final String reportPortalUrl = 'https://script.google.com/macros/s/AKfycbwwSN3nPb9BTtblvnsPaG_r2WIAezI0L045IGvucUJ9h6WLiZkcfEiTqUCd6BSeFcm_/exec?school=thunga%20cdss';

  String currentSubtitle = 'Mark Entry';

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // THIS IS THE FIX: Injecting JavaScript to force popups into the current window
          onPageFinished: (String url) async {
            await controller.runJavaScript('''
              // 1. Force window.open to use the current window
              window.open = function(url) {
                window.location.href = url;
                return null;
              };
              // 2. Change all target="_blank" links to "_self"
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a');
                if (a && a.getAttribute('target') === '_blank') {
                  a.setAttribute('target', '_self');
                }
              }, true);
            ''');
          },
          onNavigationRequest: (NavigationRequest request) async {
            return await _handleDownload(request.url) 
                ? NavigationDecision.prevent 
                : NavigationDecision.navigate;
          },
        ),
      )
      ..setOnUrlChange((UrlChange change) {
        if (change.url != null) {
          _handleDownload(change.url!);
        }
      })
      ..loadRequest(Uri.parse(markEntryUrl));
  }

  // Helper method to catch the generated Google Drive / PDF link and launch Chrome
  Future<bool> _handleDownload(String url) async {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('drive.google.com') ||
        lowerUrl.contains('export=download') ||
        lowerUrl.contains('.pdf') ||
        lowerUrl.contains('googleusercontent') ||
        lowerUrl.contains('download')) {
      
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return true;
    }
    return false;
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
              height: 40,
              width: 40,
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
                    Text('Mark Entry Portal'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report_portal',
                child: Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Report Verification Portal'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}