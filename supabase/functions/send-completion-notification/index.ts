import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient, sendFCMNotification } from '../_shared/fcm.ts';

serve(async (req) => {
  try {
    const supabase = createSupabaseClient();
    const { record } = await req.json();

    console.log('[CompletionNotification] Processing signature:', record.id);

    // completion_mentee 타입만 처리 (멘티 서명 → 멘토에게 알림)
    if (record.signature_type !== 'completion_mentee') {
      return new Response(JSON.stringify({ success: true, skipped: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 1. 멘티 정보 조회 (user_id가 멘티 ID)
    const { data: mentee } = await supabase
      .from('app_users')
      .select('nickname, mentor')
      .eq('id', record.user_id)
      .single();

    if (!mentee?.mentor) {
      console.log('[CompletionNotification] No mentor assigned');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 2. 멘토 FCM 토큰 조회
    const { data: mentor } = await supabase
      .from('app_users')
      .select('fcm_token')
      .eq('id', mentee.mentor)
      .single();

    if (!mentor?.fcm_token) {
      console.log('[CompletionNotification] Mentor has no FCM token');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 3. FCM 전송
    await sendFCMNotification(
      [mentor.fcm_token],
      {
        title: '수료 승인 요청',
        body: `${mentee.nickname}님의 수료 승인이 필요합니다.`,
      },
      {
        type: 'completion_pending',
        targetId: record.user_id,
        menteeId: record.user_id,
        menteeName: mentee.nickname,
      }
    );

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('[CompletionNotification] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

