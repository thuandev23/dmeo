import 'package:flutter/material.dart';
import 'package:demo_screenshot/take_picture_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'location_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CameraDescription>? cameraList;
  bool isLoadingPermissions = true;
  String? permissionError;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    setState(() {
      isLoadingPermissions = true;
      permissionError = null;
    });

    try {
      await _checkLocationPermission();
      await _checkCameraPermission();
      await _checkAudioPermissiion();
      await _checkLibraryPermission();
    } catch (e) {
      setState(() {
        permissionError = 'Lỗi khởi tạo permission: $e';
      });
    } finally {
      setState(() {
        isLoadingPermissions = false;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      final locationCubit = context.read<LocationCubit>();

      // Check location service status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationCubit.setError('Dịch vụ vị trí chưa được bật');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          locationCubit.setError('Quyền truy cập vị trí bị từ chối');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        locationCubit.setError(
          'Quyền truy cập vị trí bị từ chối vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền.',
        );
        return;
      }

      // Permission granted, get current location
      await locationCubit.fetchLocation();
    } catch (e) {
      final locationCubit = context.read<LocationCubit>();
      locationCubit.setError('Lỗi kiểm tra quyền vị trí: $e');
    }
  }

  Future<void> _checkCameraPermission() async {
    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.status;

      if (cameraStatus.isDenied) {
        final result = await Permission.camera.request();
        if (result.isDenied) {
          throw Exception('Quyền camera bị từ chối');
        }
      }

      if (cameraStatus.isPermanentlyDenied) {
        throw Exception(
          'Quyền camera bị từ chối vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền.',
        );
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Không tìm thấy camera nào');
      }

      setState(() {
        cameraList = cameras;
      });
    } catch (e) {
      setState(() {
        permissionError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi camera: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              onPressed: () => _checkCameraPermission(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkAudioPermissiion() async {
    try {
      // Check microphone permission
      final micStatus = await Permission.microphone.status;

      if (micStatus.isDenied) {
        final result = await Permission.microphone.request();
        if (result.isDenied) {
          throw Exception('Quyền microphone bị từ chối');
        }
      }

      if (micStatus.isPermanentlyDenied) {
        throw Exception(
          'Quyền microphone bị từ chối vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền.',
        );
      }
    } catch (e) {
      setState(() {
        permissionError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi microphone: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              onPressed: () => _checkAudioPermissiion(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkLibraryPermission() async {
    try {
      // Check photos/gallery permission
      final photosStatus = await Permission.photos.status;

      if (photosStatus.isDenied) {
        final result = await Permission.photos.request();
        if (result.isDenied) {
          throw Exception('Quyền truy cập thư viện ảnh bị từ chối');
        }
      }

      if (photosStatus.isPermanentlyDenied) {
        throw Exception(
          'Quyền truy cập thư viện ảnh bị từ chối vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền.',
        );
      }
    } catch (e) {
      setState(() {
        permissionError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi thư viện ảnh: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              onPressed: () => _checkLibraryPermission(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationCubit = context.read<LocationCubit>();
    return Scaffold(
      appBar: AppBar(title: Text('Demo S')),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          if (isLoadingPermissions) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang kiểm tra quyền...'),
                ],
              ),
            );
          }

          if (permissionError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    permissionError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _initializePermissions(),
                    child: Text('Thử lại'),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: Text('Mở Cài đặt'),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.loading)
                  Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Đang lấy vị trí...'),
                      SizedBox(height: 32),
                    ],
                  ),

                if (state.error != null)
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.location_off, color: Colors.red),
                        SizedBox(height: 8),
                        Text(
                          state.error!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _checkLocationPermission(),
                          child: Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),

                if (state.position != null)
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.location_on, color: Colors.green),
                        SizedBox(height: 8),
                        Text('Vị trí hiện tại:'),
                        Text(
                          '${state.position!.latitude.toStringAsFixed(6)}, ${state.position!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (state.address != null) ...[
                          SizedBox(height: 4),
                          Text(state.address!),
                        ],
                      ],
                    ),
                  ),

                SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed:
                      cameraList != null && cameraList!.isNotEmpty
                          ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => BlocProvider.value(
                                      value: locationCubit,
                                      child: TakePicturepage(cameras: cameraList!),
                                    ),
                              ),
                            );
                          }
                          : null,
                  icon: Icon(Icons.camera_enhance),
                  label: Text("Chụp ảnh"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),

                if (cameraList == null || cameraList!.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Camera không khả dụng',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
