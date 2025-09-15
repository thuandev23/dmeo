import 'package:flutter/material.dart';
import 'package:demo_screenshot/combined_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'location_bloc.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final locationCubit = context.read<LocationCubit>();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        locationCubit.emit(locationCubit.state.copyWith(
          loading: false,
          error: 'Quyền truy cập vị trí bị từ chối',
        ));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      locationCubit.emit(locationCubit.state.copyWith(
        loading: false,
        error: 'Quyền truy cập vị trí bị từ chối vĩnh viễn',
      ));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationCubit = context.read<LocationCubit>();
    return Scaffold(
      appBar: AppBar(title: Text('Demo S')),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          return Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider.value(
                      value: locationCubit,
                      child: CombinedPage(cameras: widget.cameras),
                    ),
                  ),
                );
              },
              icon: Icon(Icons.camera_enhance),
              label: Text("Chụp ảnh"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}
