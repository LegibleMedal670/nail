import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient, sendFCMNotification } from '../_shared/fcm.ts';

serve(async (req) => {
  try {
    const supabase = createSupabaseClient();
    const { record, old_record } = await req.json();

    console.log('[AdminNotification] Processing user:', record.id);

    // 신규 가입 알림 (INSERT, role='pending')
    const isNewUser = !old_record && record.role === 'pending';
    
    // 승인 완료 알림 (role이 'pending'에서 'mentee' 또는 'mentor'로 변경)
    const isApproved = old_record && 
      old_record.role === 'pending' && 
      (record.role === 'mentee' || record.role === 'mentor');

    if (!isNewUser && !isApproved) {
      return new Response(JSON.stringify({ success: true, skipped: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (isNewUser) {
      // 신규 가입 → 모든 관리자에게 알림
      const { data: admins } = await supabase
        .from('app_users')
        .select('fcm_token')
        .eq('is_admin', true)
        .not('fcm_token', 'is', null);

      if (!admins || admins.length === 0) {
        console.log('[AdminNotification] No admins with FCM token');
        return new Response(JSON.stringify({ success: true }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const tokens = admins.map(a => a.fcm_token).filter(Boolean);

      await sendFCMNotification(
        tokens,
        {
          title: '신규 가입 알림',
          body: `${record.nickname || '신규 회원'}님이 가입했습니다. 역할을 승인해주세요.`,
        },
        {
          type: 'new_user',
          targetId: record.id,
          userId: record.id,
          userName: record.nickname || '신규 회원',
          phone: record.phone || '',
        }
      );
    } else if (isApproved) {
      // 승인 완료 → 해당 사용자에게 알림
      if (!record.fcm_token) {
        console.log('[AdminNotification] User has no FCM token');
        return new Response(JSON.stringify({ success: true }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const roleText = record.role === 'mentee' ? '멘티' : '멘토';

      await sendFCMNotification(
        [record.fcm_token],
        {
          title: '승인 완료',
          body: `${roleText} 권한이 부여되었습니다. 이제 서비스를 이용할 수 있습니다.`,
        },
        {
          type: 'role_approved',
          targetId: record.id,
          role: record.role,
          roleText,
        }
      );
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('[AdminNotification] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

