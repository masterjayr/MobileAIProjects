class Detection {
  final String label;
  final double confidence;

  /// Normalized box coordinates: 0.0 to 1.0

  final double left;
  final double top;
  final double right;
  final double bottom;

  Detection({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory Detection.fromMap(Map<String, dynamic> map) {
    return Detection(
      label: map['label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      left: (map['left'] as num).toDouble(),
      top: (map['top'] as num).toDouble(),
      right: (map['right'] as num).toDouble(),
      bottom: (map['bottom'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'confidence': confidence,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    };
  }
}
