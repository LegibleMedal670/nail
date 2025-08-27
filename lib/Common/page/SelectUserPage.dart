import 'package:flutter/material.dart';

/// 공용 사용자 엔트리(멘토/멘티 모두 사용)
class UserEntry {
  final String id;
  final String name;

  /// 멘티 모드에선 mentor 이름을 담거나,
  /// 멘토 모드에선 부서/직책 등 다른 의미로도 재활용 가능
  final String meta;
  final String? photoUrl;

  const UserEntry({
    required this.id,
    required this.name,
    required this.meta,
    this.photoUrl,
  });
}

/// 데모용 더미 데이터(멘티 예시)
const List<UserEntry> kDemoMentees = [
  UserEntry(id: 'u001', name: '김민수', meta: '김선생'),
  UserEntry(id: 'u002', name: '박지영', meta: '박선생'),
  UserEntry(id: 'u003', name: '이정우', meta: '최선생'),
  UserEntry(id: 'u004', name: '최윤아', meta: '장선생'),
  UserEntry(id: 'u005', name: '정우혁', meta: '김선생'),
  UserEntry(id: 'u006', name: '오세훈', meta: '박선생'),
  UserEntry(id: 'u007', name: '한지민', meta: '이선생'),
  UserEntry(id: 'u008', name: '장도연', meta: '최선생'),
  UserEntry(id: 'u009', name: '윤성호', meta: '김선생'),
  UserEntry(id: 'u010', name: '문가영', meta: '김선생'),
];

/// 사용자 선택 페이지(멘토/멘티 공용)
///
/// - [users] 목록과 [subtitleBuilder]만 바꾸면 멘토/멘티 모두 사용 가능
/// - [onStart] 제공 시 선택 콜백 호출, 없으면 pop(UserEntry) 반환
class SelectUserPage extends StatefulWidget {
  final List<UserEntry> users;
  final ValueChanged<UserEntry>? onStart;
  final String? initialSelectedUserId;

  final String mode;

  /// 상단 제목(예: '사용자 선택', '멘토 선택')
  final String title;

  /// 검색 힌트(예: '이름 또는 멘토 검색', '멘토 이름 검색')
  final String hintText;

  /// 시작 버튼 텍스트(예: '시작하기', '이 멘토로 시작')
  final String startButtonText;

  /// 각 타일의 subtitle 문자열을 생성
  /// 기본: 멘티 모드 가정 → "멘토: ${u.meta}"
  final String Function(UserEntry)? subtitleBuilder;

  const SelectUserPage({
    super.key,
    List<UserEntry>? users,
    required this.mode,
    this.onStart,
    this.initialSelectedUserId,
    this.title = '사용자 선택',
    this.hintText = '이름 또는 멘토 검색',
    this.startButtonText = '시작하기',
    this.subtitleBuilder,
  }) : users = users ?? kDemoMentees;

  @override
  State<SelectUserPage> createState() => _SelectUserPageState();
}

class _SelectUserPageState extends State<SelectUserPage> {
  static const double _kBottomBarHeight = 50.0;

  late String? _selectedId = widget.initialSelectedUserId;
  String _query = '';
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<UserEntry> get _filtered {
    if (_query.trim().isEmpty) return widget.users;
    final q = _query.trim().toLowerCase();
    return widget.users.where((u) {
      return u.name.toLowerCase().contains(q) || u.meta.toLowerCase().contains(q);
    }).toList();
  }

  void _handleStart() {
    final selected = widget.users.firstWhere(
          (u) => u.id == _selectedId,
      orElse: () => widget.users.first,
    );
    // if (widget.onStart != null) {
    //   widget.onStart!(selected);
    // } else {
    //   Navigator.of(context).pop<UserEntry>(selected);
    // }

    if (widget.mode == 'Mentor') {
      print('Mentor');
    } else {
      print('Mentee');
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: const BackButton(color: Color.fromRGBO(34, 38, 49, 1)),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Color.fromRGBO(34, 38, 49, 1),
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),

        body: Column(
          children: [
            // 검색창
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                focusNode: _searchFocusNode,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
              ),
            ),

            // 리스트
            Expanded(
              child: Scrollbar(
                child: _filtered.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다'))
                    : ListView.separated(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    16, 8, 16, 16 + _kBottomBarHeight,
                  ),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = _filtered[i];
                    final selected = _selectedId == u.id;
                    final subtitleText = widget.subtitleBuilder?.call(u) ?? '멘토: ${u.meta}';
                    return _UserTile(
                      user: u,
                      subtitleText: subtitleText,
                      selected: selected,
                      onTap: () {
                        _dismissKeyboard();
                        setState(() => _selectedId == u.id ? _selectedId = null : _selectedId = u.id);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // 하단 고정 버튼(+ 키보드 회피)
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              height: _kBottomBarHeight,
              child: FilledButton(
                onPressed: _selectedId == null ? null : _handleStart,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(47, 130, 246, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.startButtonText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserEntry user;
  final String subtitleText;
  final bool selected;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.subtitleText,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final borderColor = selected ? cs.primary : theme.dividerColor.withOpacity(0.4);
    final bgColor = selected ? cs.primary.withOpacity(0.06) : cs.surface;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              // 아바타
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[400],
                backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Icon(Icons.person, color: cs.onSecondaryContainer)
                    : null,
              ),
              const SizedBox(width: 12),
              // 텍스트
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
