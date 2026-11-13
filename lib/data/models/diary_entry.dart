class DiaryEntry {
  DiaryEntry({
    required this.id,
    required String title,
    required this.score,
    required this.watchedOn,
    required String comment,
    required this.createdAt,
    this.tmdbId,
    this.posterPath,
  }) : title = title.trim(),
       comment = comment.trim() {
    if (id.isEmpty || this.title.isEmpty || this.title.length > 100) {
      throw const FormatException('제목은 1~100자여야 합니다.');
    }
    if (score < 1 ||
        score > 5 ||
        this.comment.isEmpty ||
        this.comment.length > 500) {
      throw const FormatException('별점은 1~5점, 감상은 1~500자여야 합니다.');
    }
    final now = DateTime.now();
    if (watchedOn.isAfter(DateTime(now.year, now.month, now.day)) ||
        watchedOn.isBefore(DateTime(1900))) {
      throw const FormatException('관람일은 1900년부터 오늘까지 선택해 주세요.');
    }
    if (tmdbId != null && tmdbId! <= 0) {
      throw const FormatException('영화 ID가 올바르지 않습니다.');
    }
  }

  final String id;
  final String title;
  final int score;
  final DateTime watchedOn;
  final String comment;
  final DateTime createdAt;
  final int? tmdbId;
  final String? posterPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'score': score,
    'watchedOn': watchedOn.toIso8601String(),
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'tmdbId': tmdbId,
    'posterPath': posterPath,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    score: json['score'] as int,
    watchedOn: DateTime.parse(json['watchedOn'] as String),
    comment: json['comment'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    tmdbId: json['tmdbId'] as int?,
    posterPath: json['posterPath'] as String?,
  );
}
