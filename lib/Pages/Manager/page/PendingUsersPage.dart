import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 가입 승인 대기 사용자 목록 페이지
class PendingUsersPage extends StatefulWidget {
  const PendingUsersPage({super.key});

  @override
  State<PendingUsersPage> createState() => _PendingUsersPageState();
}

class _PendingUsersPageState extends State<PendingUsersPage> {
  final _sb = Supabase.instance.client;
  
  List<Map<String, dynamic>> _pendingUsers = [];
  List<Map<String, dynamic>> _mentors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _sb.rpc('rpc_list_pending_users'),
        _sb.rpc('rpc_list_mentors_for_assign'),
      ]);

      if (!mounted) return;

      setState(() {
        _pendingUsers = List<Map<String, dynamic>>.from(results[0] ?? []);
        _mentors = List<Map<String, dynamic>>.from(results[1] ?? []);
        _isLoading = false;
      });
    } catch (e) {

      print(e);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e'), backgroundColor: Colors.red[400]),
        );
      }
    }
  }

  Future<void> _assignRole(Map<String, dynamic> user, String role, {String? mentorId}) async {
    try {
      final res = await _sb.rpc('rpc_assign_user_role', params: {
        'p_user_id': user['id'],
        'p_role': role,
        'p_mentor_id': mentorId,
      });

      if (!mounted) return;

      if (res is Map && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user['nickname']}님을 ${_roleLabel(role)}(으)로 배정했습니다.'),
            backgroundColor: Colors.green[400],
          ),
        );
        _loadData(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('역할 배정 실패: $e'), backgroundColor: Colors.red[400]),
        );
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return '관리자';
      case 'mentor': return '선임';
      case 'mentee': return '후임';
      default: return role;
    }
  }

  void _showAssignDialog(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AssignRoleSheet(
        user: user,
        mentors: _mentors,
        onAssign: (role, mentorId) {
          Navigator.pop(context);
          _assignRole(user, role, mentorId: mentorId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: UiTokens.title),
        title: const Text(
          '가입 승인',
          style: TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingUsers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _pendingUsers[index];
                      return _PendingUserCard(
                        user: user,
                        onTap: () => _showAssignDialog(user),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '대기 중인 사용자가 없습니다',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 대기 중인 사용자 카드
class _PendingUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _PendingUserCard({
    required this.user,
    required this.onTap,
  });

  String _formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    // +821012345678 → 010-1234-5678
    if (phone.startsWith('+82')) {
      phone = '0${phone.substring(3)}';
    }
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}';
    }
    return phone;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 프로필 아바타
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: UiTokens.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (user['nickname'] as String? ?? '?')[0],
                    style: TextStyle(
                      color: UiTokens.primaryBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['nickname'] ?? '이름 없음',
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPhone(user['phone']),
                      style: TextStyle(
                        color: UiTokens.title.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // 가입일
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '가입 신청',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(user['joined_at']),
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: UiTokens.title.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 역할 배정 바텀시트
class _AssignRoleSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> mentors;
  final void Function(String role, String? mentorId) onAssign;

  const _AssignRoleSheet({
    required this.user,
    required this.mentors,
    required this.onAssign,
  });

  @override
  State<_AssignRoleSheet> createState() => _AssignRoleSheetState();
}

class _AssignRoleSheetState extends State<_AssignRoleSheet> {
  String? _selectedRole;
  String? _selectedMentorId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: UiTokens.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (widget.user['nickname'] as String? ?? '?')[0],
                      style: TextStyle(
                        color: UiTokens.primaryBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user['nickname'] ?? '이름 없음',
                      style: const TextStyle(
                        color: UiTokens.title,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '역할을 선택해주세요',
                      style: TextStyle(
                        color: UiTokens.title.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 역할 선택
            const Text(
              '역할',
              style: TextStyle(
                color: UiTokens.title,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _RoleChip(
                  label: '후임',
                  selected: _selectedRole == 'mentee',
                  onTap: () => setState(() => _selectedRole = 'mentee'),
                ),
                const SizedBox(width: 8),
                _RoleChip(
                  label: '선임',
                  selected: _selectedRole == 'mentor',
                  onTap: () => setState(() {
                    _selectedRole = 'mentor';
                    _selectedMentorId = null;
                  }),
                ),
                const SizedBox(width: 8),
                _RoleChip(
                  label: '관리자',
                  selected: _selectedRole == 'admin',
                  onTap: () => setState(() {
                    _selectedRole = 'admin';
                    _selectedMentorId = null;
                  }),
                ),
              ],
            ),

            // 선임 선택 (후임일 때만)
            if (_selectedRole == 'mentee') ...[
              const SizedBox(height: 20),
              const Text(
                '담당 선임',
                style: TextStyle(
                  color: UiTokens.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMentorId,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '선임를 선택하세요',
                        style: TextStyle(color: UiTokens.title.withOpacity(0.4)),
                      ),
                    ),
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    items: widget.mentors.map((mentor) {
                      return DropdownMenuItem<String>(
                        value: mentor['id'] as String,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            mentor['nickname'] ?? '이름 없음',
                            style: const TextStyle(
                              color: UiTokens.title,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedMentorId = value),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _canSubmit
                    ? () => widget.onAssign(_selectedRole!, _selectedMentorId)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTokens.primaryBlue,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '역할 배정',
                  style: TextStyle(
                    color: _canSubmit ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_selectedRole == null) return false;
    if (_selectedRole == 'mentee' && _selectedMentorId == null) return false;
    return true;
  }
}

/// 역할 선택 칩
class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? UiTokens.primaryBlue : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? UiTokens.primaryBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : UiTokens.title.withOpacity(0.7),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
