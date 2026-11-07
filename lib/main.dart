import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

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
      theme: ThemeData(primarySwatch: Colors.blue),
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

  // ============ LOCKED SCHOOL ID - SET AT BUILD TIME ============
  static const String schoolId = String.fromEnvironment('SCHOOL_ID', defaultValue: 'milumbe cdss');
  static const String schoolName = String.fromEnvironment('SCHOOL_NAME', defaultValue: 'Milumbe CDSS');
  // =============================================================

  // ============ DEVELOPER CONTACT LINKS ========================
  // TODO: Replace with your actual WhatsApp number (e.g., 265991234567) and Facebook page link
  static const String whatsappNumber = '265882192585'; 
  static const String facebookUrl = 'https://www.facebook.com/john.liwinya';
  // =============================================================

  String currentSubtitle = 'Mark Entry';
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  String get markEntryUrl =>
      'https://lugopvisionaryrms.github.io/lugop-portal/?school=${Uri.encodeComponent(schoolId)}';
  
  String get reportPortalUrl =>
      'https://livingundergodofpossibilities.github.io/report-view/report.html?school=${Uri.encodeComponent(schoolId)}';

  @override
  void initState() {
    super.initState();
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PdfDownloadChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          final currentUrl = await controller.currentUrl() ?? '';
          if (currentUrl.contains('livingundergodofpossibilities.github.io') ||
              currentUrl.contains('lugopvisionaryrms.github.io') ||
              currentUrl.contains('script.google.com') ||
              currentUrl.contains('github.io')) {
            await _saveAndOpenPdfFromJson(message.message);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // If web tries to logout, send back to dashboard
            if (url.contains('logout') || url == 'about:blank' || url == 'about:blank#blocked') {
              controller.loadRequest(Uri.parse(markEntryUrl));
              return NavigationDecision.prevent;
            }

            if (request.url.contains('livingundergodofpossibilities.github.io') ||
                request.url.contains('lugopvisionaryrms.github.io') ||
                request.url.contains('script.google.com') ||
                request.url.contains('googleusercontent.com') ||
                request.url.contains('google.com') ||
                request.url.contains('github.io')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                isLoading = true;
                hasError = false;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }

            // Fix white screen after logout
            if (url.toLowerCase() == 'about:blank' || url.toLowerCase().contains('logout')) {
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) {
                controller.loadRequest(Uri.parse(markEntryUrl));
              }
              return;
            }

            // Check if page content is empty white screen
            try {
              final result = await controller.runJavaScriptReturningResult(
                  "document.body.innerHTML.length");
              final len = int.tryParse(result.toString()) ?? 1000;
              if (len < 100) {
                if (mounted) {
                  controller.loadRequest(Uri.parse(markEntryUrl));
                }
              }
            } catch (_) {}
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                isLoading = false;
                hasError = true;
                errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(markEntryUrl));
  }

  // Helper method to launch external apps (WhatsApp & Facebook)
  Future<void> _launchExternalUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  // Show dialog box for Suggestions & Feedback
  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggestions & Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Have a suggestion or facing an issue? Send it directly to the developer!',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your feedback here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066CC)),
            onPressed: () async {
              final feedback = feedbackController.text.trim();
              if (feedback.isNotEmpty) {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'lugopvisionaryrms@gmail.com',
                  query: 'subject=LUGOP RMS Feedback from $schoolName&body=${Uri.encodeComponent(feedback)}',
                );
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                }
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you! Opening email to send feedback.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
      final String rawFileName = data['fileName'] ?? 'Report.pdf';

      String fileName = rawFileName.split('/').last.split('\\').last;
      fileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }
      if (fileName.length > 60) {
        fileName = fileName.substring(fileName.length - 60);
      }
      if (fileName.trim().isEmpty || fileName == '.pdf') {
        fileName = 'LUGOP_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }

      String cleanBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      cleanBase64 = cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim();

      if (cleanBase64.length > 15 * 1024 * 1024) {
        throw Exception('File too large');
      }

      final bytes = base64Decode(cleanBase64);
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('PDF too large');
      }

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
          if (context.mounted) Navigator.of(context).pop();
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LUGOP RMS - $schoolName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentSubtitle,
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.white),
              onSelected: (String value) {
                if (value == 'mark_entry') {
                  setState(() {
                    isLoading = true;
                    currentSubtitle = 'Mark Entry';
                  });
                  controller.loadRequest(Uri.parse(markEntryUrl));
                } else if (value == 'report_portal') {
                  setState(() {
                    isLoading = true;
                    currentSubtitle = 'Report Portal';
                  });
                  controller.loadRequest(Uri.parse(reportPortalUrl));
                } else if (value == 'whatsapp') {
                  _launchExternalUrl('https://wa.me/$whatsappNumber?text=Hello%20LUGOP%20RMS%20Support');
                } else if (value == 'facebook') {
                  _launchExternalUrl(facebookUrl);
                } else if (value == 'feedback') {
                  _showFeedbackDialog();
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
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'whatsapp',
                  child: Row(
                    children: [
                      Icon(Icons.chat, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('WhatsApp Support'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'facebook',
                  child: Row(
                    children: [
                      Icon(Icons.facebook, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Facebook Page'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'feedback',
                  child: Row(
                    children: [
                      Icon(Icons.feedback, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Suggestions & Feedback'),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0066CC),
                        ),
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
            if (hasError)
              Container(
                color: Colors.white,
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0066CC).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off,
                        size: 60,
                        color: Color(0xFF0066CC),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Internet Connection',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load $currentSubtitle\nfor $schoolName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please check:\n• Mobile data / WiFi is ON\n• Airplane mode is OFF',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'School: $schoolId',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066CC),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          hasError = false;
                          isLoading = true;
                        });
                        controller.reload();
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'RETRY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}