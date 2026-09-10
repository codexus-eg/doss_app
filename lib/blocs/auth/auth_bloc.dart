import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:doss_core/doss_core.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String phone;
  final String password;
  const AuthLoginRequested({required this.phone, required this.password});
  @override
  List<Object?> get props => [phone, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String phone;
  final String password;
  const AuthRegisterRequested({
    required this.name,
    required this.phone,
    required this.password,
  });
  @override
  List<Object?> get props => [name, phone, password];
}

class AuthLogoutRequested extends AuthEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheck(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
        _connectSocket(user.token);
        return;
      }
      final restored = await AuthService.instance.restoreSession()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (restored != null) {
        emit(AuthAuthenticated(restored));
        _connectSocket(restored.token);
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await AuthService.instance.login(
        phone: event.phone,
        password: event.password,
        entity: 'rider',
      ).timeout(const Duration(seconds: 20));
      emit(AuthAuthenticated(user));
      _connectSocket(user.token);
    } catch (e) {
      emit(AuthFailure(_parseError(e)));
    }
  }

  Future<void> _onRegister(
      AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await AuthService.instance.registerRider(
        name: event.name,
        phone: event.phone,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
      _connectSocket(user.token);
    } catch (e) {
      emit(AuthFailure(_parseError(e)));
    }
  }

  Future<void> _onLogout(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    SocketService.instance.disconnect();
    await AuthService.instance.logout();
    emit(AuthUnauthenticated());
  }

  void _connectSocket(String token) {
    try {
      SocketService.instance.connect(
        serverUrl: ApiClient.instance.baseUrl,
        namespace: AppConstants.riderNamespace,
        token: token,
      );
    } catch (_) {}
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized') ||
        msg.contains('Invalid')) {
      return 'Invalid phone number or password.';
    }
    if (msg.contains('409') || msg.contains('already exists')) {
      return 'An account with this phone number already exists.';
    }
    if (msg.contains('SocketException') || msg.contains('connection') ||
        msg.contains('TimeoutException')) {
      return 'Cannot connect to server. Check your internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
