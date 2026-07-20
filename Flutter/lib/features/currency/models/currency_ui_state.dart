import 'currency_session_state.dart';

class CurrencyUiState {
  final bool canStartCamera;
  final String status;
  final String label;
  final String guide;
  final double confidence;
  final CurrencySessionState sessionState;

  const CurrencyUiState({
    required this.canStartCamera,
    required this.status,
    required this.label,
    required this.guide,
    required this.confidence,
    required this.sessionState,
  });

  factory CurrencyUiState.initial() {
    return const CurrencyUiState(
      canStartCamera: false,
      status: 'جاري تجهيز الكاميرا والموديل',
      label: '—',
      guide: 'انتظر تجهيز الشاشة',
      confidence: 0.0,
      sessionState: CurrencySessionState.idle,
    );
  }

  CurrencyUiState copyWith({
    bool? canStartCamera,
    String? status,
    String? label,
    String? guide,
    double? confidence,
    CurrencySessionState? sessionState,
  }) {
    return CurrencyUiState(
      canStartCamera: canStartCamera ?? this.canStartCamera,
      status: status ?? this.status,
      label: label ?? this.label,
      guide: guide ?? this.guide,
      confidence: confidence ?? this.confidence,
      sessionState: sessionState ?? this.sessionState,
    );
  }
}
