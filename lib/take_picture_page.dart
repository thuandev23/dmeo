import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:demo_screenshot/library_picture_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:geocoding/geocoding.dart';
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
  String? address;
  double latitude = 0.0;
  double longitude = 0.0;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _updateCurrentTime();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationCubit>().fetchLocation();
    });
    Future.delayed(Duration(seconds: 2), _fetchLocation);
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isNotEmpty) {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.ultraHigh,
      );

      try {
        await _cameraController!.initialize();

        // Initialize zoom levels
        _minAvailableZoom = await _cameraController!.getMinZoomLevel();
        _maxAvailableZoom = await _cameraController!.getMaxZoomLevel();
        _currentZoomLevel = _minAvailableZoom;

        setState(() {
          _isInitialized = true;
        });
      } catch (e) {
        print('Lỗi khởi tạo camera: $e');
      }
    }
  }

  Future<void> _fetchLocation() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        address =
            '${place.street}, '
            '${place.subAdministrativeArea}, '
            '${place.administrativeArea}, '
            '${place.country}';
      }
    } catch (e) {
      address = 'Không thể lấy địa chỉ';
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
                      if (_isInitialized)
                        SizedBox(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.7,
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
                            latitude = state.position?.latitude ?? 0.0;
                            longitude = state.position?.longitude ?? 0.0;
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
                                  ],
                                  if (state.error != null)
                                    Text(
                                      'Lỗi: ${state.error}',
                                      style: TextStyle(
                                        color: Colors.red[300],
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (address == null) ...[
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Đang lấy địa chỉ...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    SizedBox(height: 4),
                                    Text(
                                      address!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 100),
          // Zoom controls
          if (_isInitialized) ...[
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _currentZoomLevel,
                    min: _minAvailableZoom,
                    max: _maxAvailableZoom,
                    activeColor: Colors.black,
                    inactiveColor: Colors.grey,
                    onChanged: (value) async {
                      setState(() {
                        _currentZoomLevel = value;
                      });
                      await _cameraController!.setZoomLevel(value);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Text(
                        '${_currentZoomLevel.toStringAsFixed(1)}x',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 20),
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
