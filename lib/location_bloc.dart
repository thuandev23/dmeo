import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// State class
class LocationState {
  final bool loading;
  final Position? position;
  final String? address;
  final String? error;

  LocationState({
    this.loading = false,
    this.position,
    this.address,
    this.error,
  });

  LocationState copyWith({
    bool? loading,
    Position? position,
    String? address,
    String? error,
  }) {
    return LocationState(
      loading: loading ?? this.loading,
      position: position ?? this.position,
      address: address ?? this.address,
      error: error ?? this.error,
    );
  }
}

// Cubit class
class LocationCubit extends Cubit<LocationState> {
  LocationCubit() : super(LocationState());

  Future<void> fetchLocation() async {
    emit(state.copyWith(loading: true, error: null));

    try {
      // Kiểm tra permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(state.copyWith(
            loading: false,
            error: 'Quyền truy cập vị trí bị từ chối',
          ));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        emit(state.copyWith(
          loading: false,
          error: 'Quyền truy cập vị trí bị từ chối vĩnh viễn',
        ));
        return;
      }

      // Lấy vị trí hiện tại
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Lấy địa chỉ từ tọa độ
      String? address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = '${place.street}, ${place.locality}, ${place.country}';
        }
      } catch (e) {
        address = 'Không thể lấy địa chỉ';
      }

      emit(state.copyWith(
        loading: false,
        position: position,
        address: address,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: 'Lỗi khi lấy vị trí: $e',
      ));
    }
  }
}
