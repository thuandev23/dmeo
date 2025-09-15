import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'location_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lấy danh sách cameras có sẵn
  final cameras = await availableCameras();
  
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo Screenshot + Camera',
      home: BlocProvider(
        create: (_) => LocationCubit(),
        child: HomePage(cameras: cameras),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final List<CameraDescription> cameras;

  HomePage({Key? key, required this.cameras}) : super(key: key);

  // Hàm chụp screenshot sử dụng RepaintBoundary và ui.Image
  Future<Uint8List?> _captureScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Lỗi khi chụp screenshot: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationCubit = context.read<LocationCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('Screenshot + Camera + Tọa độ')),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          return Center(
            child: RepaintBoundary(
              key: _repaintBoundaryKey,
              child: Card(
                margin: EdgeInsets.all(20),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.loading) CircularProgressIndicator(),
                      if (!state.loading && state.position != null) ...[
                        Text(
                          "Lat: ${state.position!.latitude.toStringAsFixed(6)}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Lng: ${state.position!.longitude.toStringAsFixed(6)}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Địa chỉ: ${state.address}",
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (state.error != null) 
                        Text(
                          "Lỗi: ${state.error}", 
                          style: TextStyle(color: Colors.red),
                        ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => locationCubit.fetchLocation(),
                        child: Text("Lấy vị trí"),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final imageBytes = await _captureScreenshot();
                              if (imageBytes != null) {
                                try {
                                  // Lưu vào thư viện ảnh với package gal
                                  await Gal.putImageBytes(imageBytes);
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã lưu screenshot vào thư viện ảnh!')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi khi lưu ảnh: $e')),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.screenshot),
                            label: Text("Screenshot"),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CameraPage(cameras: cameras),
                                ),
                              );
                            },
                            icon: Icon(Icons.camera_alt),
                            label: Text("Camera"),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlocProvider.value(
                                value: locationCubit,
                                child: CombinedPage(cameras: cameras),
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.camera_enhance),
                        label: Text("Camera + Tọa độ"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Trang Camera
class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraPage({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isNotEmpty) {
      _cameraController = CameraController(
        widget.cameras[0], // Sử dụng camera đầu tiên
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

  Future<void> _takePicture() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final XFile picture = await _cameraController!.takePicture();
        
        try {
          // Lưu vào thư viện ảnh với package gal
          await Gal.putImage(picture.path);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã lưu ảnh vào thư viện!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lưu ảnh: $e')),
          );
        }
      } catch (e) {
        print('Lỗi khi chụp ảnh: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chụp ảnh: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),
                // Nút chụp ảnh
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _takePicture,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Đang khởi tạo camera...'),
                ],
              ),
            ),
    );
  }
}

// Trang gộp Camera + Tọa độ + Screenshot
class CombinedPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CombinedPage({Key? key, required this.cameras}) : super(key: key);

  @override
  _CombinedPageState createState() => _CombinedPageState();
}

class _CombinedPageState extends State<CombinedPage> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Tự động lấy vị trí khi vào trang
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

  // Hàm chụp screenshot toàn bộ màn hình
  Future<void> _captureScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final imageBytes = byteData.buffer.asUint8List();
        
        try {
          // Lưu vào thư viện ảnh với package gal
          await Gal.putImageBytes(imageBytes);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã lưu ảnh Camera + Tọa độ vào thư viện!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lưu ảnh: $e')),
          );
        }
      }
    } catch (e) {
      print('Lỗi khi chụp screenshot: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chụp screenshot: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera + Tọa độ'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: Stack(
          children: [
            // Camera preview full screen
            if (_isInitialized)
              Positioned.fill(
                child: CameraPreview(_cameraController!),
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

            // Overlay thông tin tọa độ ở trên
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: BlocBuilder<LocationCubit, LocationState>(
                builder: (context, state) {
                  return Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'THÔNG TIN VỊ TRÍ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Spacer(),
                            if (state.loading)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (!state.loading && state.position != null) ...[
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
                                color: Colors.white70,
                                fontSize: 11,
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
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Nút chụp ảnh ở dưới
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Nút refresh location
                  FloatingActionButton(
                    heroTag: "refresh",
                    onPressed: () {
                      context.read<LocationCubit>().fetchLocation();
                    },
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
                  ),
                  // Nút chụp screenshot
                  FloatingActionButton(
                    heroTag: "capture",
                    onPressed: _captureScreenshot,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.camera,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),

            // Timestamp ở góc dưới phải
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DateTime.now().toString().substring(0, 19),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
