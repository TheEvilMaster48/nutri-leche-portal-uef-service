import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfFullscreenScreen extends StatefulWidget {
  final File pdfFile;
  final String title;

  const PdfFullscreenScreen({
    super.key,
    required this.pdfFile,
    this.title = "Documento",
  });

  @override
  State<PdfFullscreenScreen> createState() => _PdfFullscreenScreenState();
}

class _PdfFullscreenScreenState extends State<PdfFullscreenScreen> {
  int? _pages;
  int _currentPage = 0;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.pdfFile.path,
            enableSwipe: true,
            swipeHorizontal: false, // ✅ scroll vertical tipo “leer”
            autoSpacing: true,
            pageFling: true,
            onRender: (pages) => setState(() {
              _pages = pages;
              _ready = true;
            }),
            onViewCreated: (_) {},
            onPageChanged: (page, total) => setState(() {
              _currentPage = page ?? 0;
              _pages = total;
            }),
            onError: (error) => debugPrint("PDF error: $error"),
            onPageError: (page, error) =>
                debugPrint("PDF page error: $page $error"),
          ),
          if (!_ready)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: (_pages == null)
          ? null
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          "Página ${_currentPage + 1} / $_pages",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
