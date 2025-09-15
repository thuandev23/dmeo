import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:demo_screenshot/library_picture_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'location_bloc.dart';

class TakePicturepage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const TakePicturepage({Key? key, required this.cameras}) : super(key: key);

  @override
  _TakePicturepageState createState() => _TakePicturepageState();
}

class _TakePicturepageState extends State<TakePicturepage> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  String _currentTime = '';
  Timer? _timer;
  bool _showFlashEffect = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _updateCurrentTime();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationCubit>().fetchLocation();
    });
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isNotEmpty) {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
      );

      try {
        await _cameraController!.initialize();
        setState(() {
          _isInitialized = true;
        });
      } catch (e) {
        print('Lỗi khởi tạo camera: $e');
      }
    }
  }

  void _updateCurrentTime() {
    setState(() {
      _currentTime = DateTime.now().toString().substring(0, 19);
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCurrentTime();
      }
    });
  }

  Future<void> _captureScreenshot() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera chưa được khởi tạo.');
      return;
    }

    setState(() {
      _showFlashEffect = true;
    });

    await Future.delayed(Duration(milliseconds: 50));

    try {
      RenderRepaintBoundary boundary =
          _repaintBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final imageBytes = byteData.buffer.asUint8List();

        try {
          await Gal.putImageBytes(imageBytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã lưu ảnh Camera + Tọa độ vào thư viện!'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu ảnh: $e')));
          }
        }
      }
    } catch (e) {
      print('Lỗi khi chụp screenshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi chụp screenshot: $e')));
      }
    } finally {
      setState(() {
        _showFlashEffect = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Chụp ảnh', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: Stack(
                    children: [
                      // Camera preview hoặc loading
                      if (_isInitialized)
                        SizedBox(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width:
                                  _cameraController!.value.previewSize!.height,
                              height:
                                  _cameraController!.value.previewSize!.width,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: Colors.black,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 20),
                                Text(
                                  'Đang khởi tạo camera...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: BlocBuilder<LocationCubit, LocationState>(
                          builder: (context, state) {
                            return Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'THÔNG TIN VỊ TRÍ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    _currentTime,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  if (state.loading)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  if (!state.loading &&
                                      state.position != null) ...[
                                    Text(
                                      'Lat: ${state.position!.latitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      'Lng: ${state.position!.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    if (state.address != null) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        state.address!,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                  if (state.error != null)
                                    Text(
                                      'Lỗi: ${state.error}',
                                      style: TextStyle(
                                        color: Colors.red[300],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showFlashEffect)
                  Positioned.fill(child: Container(color: Colors.white)),
              ],
            ),
          ),
          SizedBox(height: 100),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: "library",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LibraryPicturePage(),
                    ),
                  );
                },
                backgroundColor: Colors.blue,
                child: Icon(
                  Icons.library_add_check_outlined,
                  color: Colors.white,
                ),
              ),
              FloatingActionButton(
                heroTag: "capture",
                onPressed: _captureScreenshot,
                backgroundColor: Colors.white,
                child: Icon(Icons.camera, color: Colors.black, size: 30),
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
