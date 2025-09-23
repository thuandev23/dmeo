import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

// State class
class LocationState {
  final bool loading;
  final Position? position;
  final String? error;

  LocationState({
    this.loading = false,
    this.position,
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
      // Lấy vị trí hiện tại
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      emit(state.copyWith(
        loading: false,
        position: position
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: 'Lỗi khi lấy vị trí: $e',
      ));
    }
  }

  void setError(String error) {
    emit(state.copyWith(loading: false, error: error));
  }

  void setLoading(bool loading) {
    emit(state.copyWith(loading: loading));
  }
}
