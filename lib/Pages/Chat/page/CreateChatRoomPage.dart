// lib/Pages/Chat/page/CreateChatRoomPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/TodoService.dart';
import 'package:nail/Pages/Chat/page/ChatRoomPage.dart';

class CreateChatRoomPage extends StatefulWidget {
  const CreateChatRoomPage({super.key});

  @override
  State<CreateChatRoomPage> createState() => _CreateChatRoomPageState();
}

class _CreateChatRoomPageState extends State<CreateChatRoomPage> {
  // ---- 입력 컨트롤 ----
  final _roomNameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  // ---- 로드/제출 상태 ----
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  // ---- 현재 로그인 사용자(본인) ----
  String? _myId;
  String _myName = '관리자';
  String? _myPhoto;
  bool _isAdmin = false;

  // ---- 선택 상태 (본인은 절대 포함/표시하지 않음) ----
  final Set<String> _selectedAdminIds = {};  // 다른 관리자 (본인 제외)
  final Set<String> _selectedMentorIds = {};
  final Set<String> _selectedMenteeIds = {};

  // ---- 데이터 목록 ----
  List<_UserVm> _admins = const [];   // 이번 스펙상 비워둠(필요시 API 연결)
  List<_UserVm> _mentors = const [];
  List<_UserVm> _mentees = const [];

  String get _q => _searchCtrl.text.trim();

  int get _selectedCount =>
      _selectedAdminIds.length + _selectedMentorIds.length + _selectedMenteeIds.length;

  bool get _canSubmit =>
      _roomNameCtrl.text.trim().isNotEmpty && _selectedCount > 0 && _isAdmin && !_submitting;

  @override
  void initState() {
    super.initState();

    final me = context.read<UserProvider>().current;
    _myId   = me?.userId;
    _myName = (me?.nickname.isNotEmpty == true) ? me!.nickname : '관리자';
    _myPhoto = me?.photoUrl;
    _isAdmin = context.read<UserProvider>().isAdmin;

    _searchCtrl.addListener(() => setState(() {}));
    _loadLists();
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final adminLoginKey = context.read<UserProvider>().adminKey?.trim() ?? '';

      // 멘티 목록 (공용 RPC)
      final menteeMaps = await TodoService.instance.listMenteesForSelect();
      final mentees = menteeMaps
          .map((m) => _UserVm(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        role: 'mentee',
        subtitle: (m['mentor_name'] ?? '').toString().isNotEmpty
            ? '담당 멘토: ${(m['mentor_name'] ?? '').toString()}'
            : null,
        photoUrl: (m['photo_url'] ?? '').toString(),
      ))
      // 🔽 현재 로그인 사용자(본인) 제외
          .where((u) => u.id != _myId)
          .toList(growable: false);

      // 멘토 목록 (관리자 권한 필요)
      List<_UserVm> mentors = const [];
      if (adminLoginKey.isNotEmpty && _isAdmin) {
        try {
          final mentorMaps =
          await TodoService.instance.listMentorsForSelect(adminLoginKey: adminLoginKey);
          mentors = mentorMaps
              .map((m) => _UserVm(
            id: (m['id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            role: 'mentor',
            subtitle: null,
            photoUrl: (m['photo_url'] ?? '').toString(),
          ))
          // 🔽 현재 로그인 사용자(본인) 제외
              .where((u) => u.id != _myId)
              .toList(growable: false);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('멘토 목록을 불러오지 못했습니다 (권한 확인).')),
            );
          }
        }
      }

      // (선택) 관리자 목록 API가 있다면 여기서 불러와 본인 제외 필터를 적용
      final admins = <_UserVm>[];

      setState(() {
        _admins = admins;
        _mentors = mentors;
        _mentees = mentees;
      });
    } catch (e) {
      setState(() => _loadError = '목록 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_UserVm> _filter(List<_UserVm> src) {
    if (_q.isEmpty) return src;
    final lq = _q.toLowerCase();
    return src.where((e) => e.name.toLowerCase().contains(lq)).toList();
  }

  Future<void> _onSubmit() async {
    if (!_canSubmit) return;

    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자만 채팅방을 생성할 수 있습니다.')),
      );
      return;
    }

    final adminKey = context.read<UserProvider>().adminKey?.trim() ?? '';
    if (adminKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 인증 정보가 없습니다. 다시 로그인해주세요.')),
      );
      return;
    }

    final roomName = _roomNameCtrl.text.trim();

    // 초대된 사용자 닉네임 목록(본인 제외)
    final invited = <String>[
      ..._admins.where((u) => _selectedAdminIds.contains(u.id)).map((e) => e.name),
      ..._mentors.where((u) => _selectedMentorIds.contains(u.id)).map((e) => e.name),
      ..._mentees.where((u) => _selectedMenteeIds.contains(u.id)).map((e) => e.name),
    ];

    // 멤버 id: 선택 대상들만 전달(본인은 서버에서 자동 admin 등록됨)
    final memberIds = <String>{
      ..._selectedAdminIds,
      ..._selectedMentorIds,
      ..._selectedMenteeIds,
    }.toList();

    setState(() => _submitting = true);
    try {
      // ✅ 서버에 방 생성
      final roomId = await ChatService.instance.createRoom(
        adminLoginKey: adminKey,
        name: roomName,
        memberIds: memberIds,
      );

      if (!mounted) return;

      // 생성 직후 해당 방으로 이동
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            roomId: roomId,
            roomName: roomName,
            invitedNamesOnCreate: invited, // ChatRoomPage에서 who=UserProvider.nickname으로 표기
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('방 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: UiTokens.title),
            tooltip: '뒤로가기',
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            '채팅방 생성',
            style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
          ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 5.0),
              child: TextButton(
                onPressed: _canSubmit ? _onSubmit : null,
                child: Row(
                  children: [
                    if (_submitting) ...[
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '${_selectedCount.toString()}  확인',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_loadError != null)
            ? _ErrorView(message: _loadError!, onRetry: _loadLists)
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 방 이름
            TextField(
              controller: _roomNameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '방 이름',
                hintText: '예) 디자인방 / 재고방',
              ),
            ),
            const SizedBox(height: 12),

            // 검색
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '이름 검색',
                border: const OutlineInputBorder(),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchCtrl.clear(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== 관리자 섹션 (본인 제외 후 0명이면 헤더/리스트 숨김) =====
            if (_admins.isNotEmpty) ...[
              _sectionHeader(
                '관리자',
                selected: _selectedAdminIds.length,
                total: _admins.length,
                trailing: TextButton.icon(
                  onPressed: () {
                    final f = _filter(_admins);
                    final all = _selectedAdminIds.length == f.length;
                    setState(() {
                      _selectedAdminIds
                        ..clear()
                        ..addAll(all ? const <String>{} : f.map((e) => e.id));
                    });
                  },
                  icon: Icon(
                    (_filter(_admins).isNotEmpty &&
                        _selectedAdminIds.length == _filter(_admins).length)
                        ? Icons.remove_done
                        : Icons.done_all,
                    size: 18,
                  ),
                  label: Text(
                    (_filter(_admins).isNotEmpty &&
                        _selectedAdminIds.length == _filter(_admins).length)
                        ? '전체 해제'
                        : '전체 선택',
                  ),
                ),
              ),
              ..._filter(_admins).map(
                    (u) => _UserRow(
                  vm: u,
                  checked: _selectedAdminIds.contains(u.id),
                  onChanged: (v) => setState(() {
                    v ? _selectedAdminIds.add(u.id) : _selectedAdminIds.remove(u.id);
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ===== 멘토 섹션 =====
            _sectionHeader(
              '멘토',
              selected: _selectedMentorIds.length,
              total: _mentors.length,
              trailing: TextButton.icon(
                onPressed: _mentors.isEmpty
                    ? null
                    : () => setState(() {
                  final f = _filter(_mentors);
                  final all = _selectedMentorIds.length == f.length;
                  _selectedMentorIds
                    ..clear()
                    ..addAll(all ? const <String>{} : f.map((e) => e.id));
                }),
                icon: Icon(
                  (_filter(_mentors).isNotEmpty &&
                      _selectedMentorIds.length == _filter(_mentors).length)
                      ? Icons.remove_done
                      : Icons.done_all,
                  size: 18,
                ),
                label: Text(
                  (_filter(_mentors).isNotEmpty &&
                      _selectedMentorIds.length == _filter(_mentors).length)
                      ? '전체 해제'
                      : '전체 선택',
                ),
              ),
            ),
            if (_mentors.isEmpty)
              _emptyHint('멘토 목록이 없어요')
            else
              ..._filter(_mentors).map(
                    (u) => _UserRow(
                  vm: u,
                  checked: _selectedMentorIds.contains(u.id),
                  onChanged: (v) => setState(() {
                    v ? _selectedMentorIds.add(u.id) : _selectedMentorIds.remove(u.id);
                  }),
                ),
              ),
            const SizedBox(height: 16),

            // ===== 멘티 섹션 =====
            _sectionHeader(
              '멘티',
              selected: _selectedMenteeIds.length,
              total: _mentees.length,
              trailing: TextButton.icon(
                onPressed: _mentees.isEmpty
                    ? null
                    : () => setState(() {
                  final f = _filter(_mentees);
                  final all = _selectedMenteeIds.length == f.length;
                  _selectedMenteeIds
                    ..clear()
                    ..addAll(all ? const <String>{} : f.map((e) => e.id));
                }),
                icon: Icon(
                  (_filter(_mentees).isNotEmpty &&
                      _selectedMenteeIds.length == _filter(_mentees).length)
                      ? Icons.remove_done
                      : Icons.done_all,
                  size: 18,
                ),
                label: Text(
                  (_filter(_mentees).isNotEmpty &&
                      _selectedMenteeIds.length == _filter(_mentees).length)
                      ? '전체 해제'
                      : '전체 선택',
                ),
              ),
            ),
            if (_mentees.isEmpty)
              _emptyHint('멘티 목록이 없어요')
            else
              ..._filter(_mentees).map(
                    (u) => _UserRow(
                  vm: u,
                  checked: _selectedMenteeIds.contains(u.id),
                  onChanged: (v) => setState(() {
                    v ? _selectedMenteeIds.add(u.id) : _selectedMenteeIds.remove(u.id);
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
      String title, {
        required int selected,
        required int total,
        Widget? trailing,
      }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: UiTokens.title)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$selected/$total',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: UiTokens.title)),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _UserRow extends StatelessWidget {
  final _UserVm vm;
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _UserRow({required this.vm, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(vm.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: (vm.subtitle?.isNotEmpty ?? false) ? Text(vm.subtitle!) : null,
      secondary: CircleAvatar(
        backgroundColor: const Color(0xFFE8EDF3),
        foregroundImage: (vm.photoUrl != null && vm.photoUrl!.isNotEmpty)
            ? NetworkImage(vm.photoUrl!)
            : null,
        child: vm.photoUrl == null || vm.photoUrl!.isEmpty
            ? Icon(
          vm.role == 'admin'
              ? Icons.verified_user_outlined
              : vm.role == 'mentor'
              ? Icons.support_agent_outlined
              : Icons.person_outline,
          color: UiTokens.actionIcon,
        )
            : null,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class _UserVm {
  final String id;
  final String name;
  final String role; // 'admin' | 'mentor' | 'mentee'
  final String? subtitle;
  final String? photoUrl;
  const _UserVm({
    required this.id,
    required this.name,
    required this.role,
    this.subtitle,
    this.photoUrl,
  });
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
