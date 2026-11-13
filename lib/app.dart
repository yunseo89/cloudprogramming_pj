import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'data/models/diary_entry.dart';
import 'data/models/tmdb_movie_dto.dart';
import 'data/services/tmdb_movie_service.dart';
import 'diary_controller.dart';
import 'widgets/tmdb_poster_image.dart';

String dateText(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key, required this.controller});
  final DiaryController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MovieLog · 나의 영화 기록',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'NotoSansKR',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: DiaryPage(controller: controller),
  );
}

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key, required this.controller});
  final DiaryController controller;

  Future<void> _edit(
    BuildContext context, {
    DiaryEntry? entry,
    TmdbMovieDto? movie,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          EntryEditor(controller: controller, entry: entry, movie: movie),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('기록을 저장했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.movie_filter_outlined),
            SizedBox(width: 10),
            Text('MovieLog'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '앱 안내',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'MovieLog',
              applicationVersion: '1.0.0',
              children: const [
                Text(
                  '나의 영화 평점과 감상을 이 기기에 기록합니다.\n같은 브라우저·주소에서 다시 확인할 수 있습니다. 브라우저 데이터 삭제 시 기록도 삭제됩니다.\n\n영화 정보: TMDB\nThis product uses the TMDB API but is not endorsed or certified by TMDB.\nhttps://www.themoviedb.org',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : controller.loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          controller.loadError!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      FilledButton(
                        onPressed: controller.load,
                        child: const Text('다시 불러오기'),
                      ),
                    ],
                  ),
                )
              : _content(context),
        ),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    final entries = controller.visibleEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '다시 꺼내 보는, 나의 영화',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.entries.length}편의 기록  ·  평균 ${controller.average.toStringAsFixed(1)}점',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: controller.saving ? null : () => _edit(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('직접 기록하기'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.saving
                        ? null
                        : () async {
                            final movie = await showDialog<TmdbMovieDto>(
                              context: context,
                              builder: (_) => const MovieSearchDialog(),
                            );
                            if (movie == null || !context.mounted) return;
                            final matches = controller.entries.where(
                              (e) => e.tmdbId == movie.id,
                            );
                            await _edit(
                              context,
                              entry: matches.isEmpty ? null : matches.first,
                              movie: movie,
                            );
                          },
                    icon: const Icon(Icons.search),
                    label: const Text('영화 찾아 기록하기'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: controller.filter,
                decoration: const InputDecoration(
                  labelText: '내 기록 검색',
                  hintText: '영화 제목',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('정렬  '),
                  DropdownButton<DiarySort>(
                    value: controller.sort,
                    onChanged: (value) {
                      if (value != null) controller.orderBy(value);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: DiarySort.newest,
                        child: Text('등록 최신순'),
                      ),
                      DropdownMenuItem(
                        value: DiarySort.highest,
                        child: Text('평점 높은순'),
                      ),
                      DropdownMenuItem(
                        value: DiarySort.title,
                        child: Text('제목순'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      controller.entries.isEmpty
                          ? '아직 기록한 영화가 없어요.\n첫 감상을 직접 남겨 보세요.'
                          : '검색 결과가 없습니다.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TmdbPosterImage(
                                posterPath: entry.posterPath,
                                width: 64,
                                height: 96,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${'★' * entry.score}${'☆' * (5 - entry.score)}  ·  ${dateText(entry.watchedOn)} 관람',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(entry.comment),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    children: [
                                      TextButton.icon(
                                        onPressed: controller.saving
                                            ? null
                                            : () =>
                                                  _edit(context, entry: entry),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('수정'),
                                      ),
                                      TextButton.icon(
                                        onPressed: controller.saving
                                            ? null
                                            : () => showDialog<void>(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (_) => DeleteDialog(
                                                  controller: controller,
                                                  entry: entry,
                                                ),
                                              ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        label: const Text('삭제'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            '기록은 이 기기에만 저장됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.controller,
    this.entry,
    this.movie,
  });
  final DiaryController controller;
  final DiaryEntry? entry;
  final TmdbMovieDto? movie;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.entry?.title ?? widget.movie?.title ?? '',
  );
  late final _comment = TextEditingController(
    text: widget.entry?.comment ?? '',
  );
  late int _score = widget.entry?.score ?? 0;
  late DateTime _date =
      widget.entry?.watchedOn ?? DateUtils.dateOnly(DateTime.now());
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_score == 0) {
      setState(() => _error = '별점을 선택해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      await widget.controller.upsert(
        DiaryEntry(
          id: widget.entry?.id ?? now.microsecondsSinceEpoch.toString(),
          title: _title.text,
          score: _score,
          watchedOn: _date,
          comment: _comment.text,
          createdAt: widget.entry?.createdAt ?? now,
          tmdbId: widget.entry?.tmdbId ?? widget.movie?.id,
          posterPath: widget.entry?.posterPath ?? widget.movie?.posterPath,
        ),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '저장하지 못했습니다. 입력은 유지됩니다. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.entry == null ? '영화 기록 남기기' : '영화 기록 수정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  enabled:
                      !_busy &&
                      widget.movie == null &&
                      widget.entry?.tmdbId == null,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '영화 제목'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '제목을 입력해 주세요.' : null,
                ),
                const SizedBox(height: 12),
                const Text('별점 (필수)'),
                Row(
                  children: List.generate(
                    5,
                    (i) => Expanded(
                      child: IconButton(
                        tooltip: '${i + 1}점',
                        onPressed: _busy
                            ? null
                            : () => setState(() => _score = i + 1),
                        icon: Icon(
                          i < _score ? Icons.star : Icons.star_border,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(_score == 0 ? '별점을 선택해 주세요.' : '$_score / 5점'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(1900),
                            lastDate: DateUtils.dateOnly(DateTime.now()),
                          );
                          if (date != null && mounted) {
                            setState(() => _date = date);
                          }
                        },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('관람일 ${dateText(_date)}'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _comment,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: '감상 (필수)',
                    hintText: '기억에 남는 장면이나 느낀 점을 적어 주세요.',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? '감상을 한 줄 이상 입력해 주세요.'
                      : null,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? '저장 중…' : '저장'),
        ),
      ],
    ),
  );
}

class DeleteDialog extends StatefulWidget {
  const DeleteDialog({
    super.key,
    required this.controller,
    required this.entry,
  });
  final DiaryController controller;
  final DiaryEntry entry;
  @override
  State<DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<DeleteDialog> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('기록을 삭제할까요?'),
      content: Text(
        _error ?? '「${widget.entry.title}」 기록을 삭제합니다. 삭제한 기록은 복구할 수 없습니다.',
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    await widget.controller.delete(widget.entry.id);
                    if (!context.mounted) return;
                    setState(() => _busy = false);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) Navigator.pop(context);
                    });
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        _busy = false;
                        _error = '삭제하지 못했습니다. 기존 기록은 유지됩니다. 다시 시도해 주세요.';
                      });
                    }
                  }
                },
          child: Text(_busy ? '삭제 중…' : '삭제 확인'),
        ),
      ],
    ),
  );
}

class MovieSearchDialog extends StatefulWidget {
  const MovieSearchDialog({super.key, this.service});
  final TmdbMovieService? service;
  @override
  State<MovieSearchDialog> createState() => _MovieSearchDialogState();
}

class _MovieSearchDialogState extends State<MovieSearchDialog> {
  final _query = TextEditingController();
  late final _service = widget.service ?? TmdbMovieService.configuredService();
  List<TmdbMovieDto> _movies = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  int _request = 0;
  bool get _configured => widget.service != null || TmdbMovieService.configured;
  @override
  void dispose() {
    _request++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      _movies = [];
    });
    try {
      final movies = await _service.search(_query.text);
      if (mounted && request == _request) setState(() => _movies = movies);
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = '영화를 불러오지 못했습니다. 연결·토큰을 확인하고 다시 검색하거나 직접 기록해 주세요.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('영화 찾아 기록하기'),
    content: SizedBox(
      width: 480,
      height: 400,
      child: !_configured
          ? const Center(
              child: Text(
                'TMDB 토큰이 설정되지 않았습니다.\n닫은 뒤 ‘직접 기록하기’로 모든 기록 기능을 사용할 수 있습니다.\n토큰 설정 방법은 README를 확인해 주세요.',
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                TextField(
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  onChanged: (_) {
                    setState(() {
                      _request++;
                      _loading = false;
                      _movies = [];
                      _searched = false;
                      _error = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: '영화 제목 검색',
                    suffixIcon: IconButton(
                      tooltip: '검색',
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Text(_error!, textAlign: TextAlign.center),
                        )
                      : _movies.isEmpty
                      ? Center(
                          child: Text(
                            _searched
                                ? '검색 결과가 없습니다. 직접 기록하기를 이용해 주세요.'
                                : '제목으로 검색하세요. (검색 결과 첫 20편)',
                          ),
                        )
                      : ListView.builder(
                          itemCount: _movies.length,
                          itemBuilder: (context, index) {
                            final movie = _movies[index];
                            return ListTile(
                              leading: TmdbPosterImage(
                                posterPath: movie.posterPath,
                                width: 36,
                                height: 54,
                              ),
                              title: Text(movie.title),
                              subtitle: Text(movie.releaseDate ?? '개봉일 정보 없음'),
                              onTap: () => Navigator.pop(context, movie),
                            );
                          },
                        ),
                ),
                const Text('영화 정보 제공: TMDB', style: TextStyle(fontSize: 12)),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}
