import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/location_repository.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class DashboardUploadLocationRequested extends DashboardEvent {}

class DashboardState extends Equatable {
  const DashboardState({this.status});

  final String? status;

  DashboardState copyWith({String? status}) => DashboardState(status: status);

  @override
  List<Object?> get props => [status];
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required LocationRepository locationRepository})
      : _locationRepository = locationRepository,
        super(const DashboardState()) {
    on<DashboardUploadLocationRequested>(_onUploadLocationRequested);
  }

  final LocationRepository _locationRepository;

  Future<void> _onUploadLocationRequested(
    DashboardUploadLocationRequested event,
    Emitter<DashboardState> emit,
  ) async {
    await _locationRepository.startTracking();
    emit(state.copyWith(status: 'Location uploaded'));
  }
}
