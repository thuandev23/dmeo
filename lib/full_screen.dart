import 'dart:typed_data';

import 'package:flutter/material.dart';

class FullScreen extends StatefulWidget {
  final asset;
  const FullScreen({super.key, required this.asset});

  @override
  State<FullScreen> createState() => _FullScreenState();
}

class _FullScreenState extends State<FullScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Xem ảnh')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Uint8List?>(
              future: widget.asset.originBytes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi tải ảnh'));
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return Center(child: InteractiveViewer(
                    child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                  ));
                }
                return Center(child: Text('Không có ảnh'));
              },
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
