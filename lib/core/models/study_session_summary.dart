class StudySessionSummary {
  const StudySessionSummary({
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.pausedSeconds,
    required this.absentSeconds,
    required this.earnedCredits,
    required this.invalidated,
    required this.message,
  });

  final int plannedSeconds;
  final int focusedSeconds;
  final int pausedSeconds;
  final int absentSeconds;
  final double earnedCredits;
  final bool invalidated;
  final String message;

  Duration get focusedDuration => Duration(seconds: focusedSeconds);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'plannedSeconds': plannedSeconds,
      'focusedSeconds': focusedSeconds,
      'pausedSeconds': pausedSeconds,
      'absentSeconds': absentSeconds,
      'earnedCredits': earnedCredits,
      'invalidated': invalidated,
      'message': message,
    };
  }

  factory StudySessionSummary.fromMap(Map<String, dynamic> map) {
    return StudySessionSummary(
      plannedSeconds: (map['plannedSeconds'] as num?)?.toInt() ?? 0,
      focusedSeconds: (map['focusedSeconds'] as num?)?.toInt() ?? 0,
      pausedSeconds: (map['pausedSeconds'] as num?)?.toInt() ?? 0,
      absentSeconds: (map['absentSeconds'] as num?)?.toInt() ?? 0,
      earnedCredits: (map['earnedCredits'] as num?)?.toDouble() ?? 0.0,
      invalidated: map['invalidated'] == true,
      message: map['message']?.toString() ?? '',
    );
  }
}