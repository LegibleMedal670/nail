import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient, sendFCMNotification } from '../_shared/fcm.ts';

serve(async (req) => {
  try {
    const supabase = createSupabaseClient();
    const { record } = await req.json();

    console.log('[TodoNotification] Processing assignment:', record.group_id, record.user_id);

    // 1. TODO 그룹 정보 조회
    const { data: todoGroup } = await supabase
      .from('todo_groups')
      .select('title, description')
      .eq('id', record.group_id)
      .single();

    if (!todoGroup) {
      console.log('[TodoNotification] TODO group not found');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 2. 배정된 사용자의 FCM 토큰 조회
    const { data: user } = await supabase
      .from('app_users')
      .select('fcm_token, nickname')
      .eq('id', record.user_id)
      .single();

    if (!user?.fcm_token) {
      console.log('[TodoNotification] User has no FCM token');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 3. FCM 전송
    await sendFCMNotification(
      [user.fcm_token],
      {
        title: '새 할 일 배정',
        body: `"${todoGroup.title}" 할 일이 배정되었습니다.`,
      },
      {
        type: 'todo_assigned',
        targetId: record.group_id,
        groupId: record.group_id,
        groupTitle: todoGroup.title,
        groupDescription: todoGroup.description || '',
      }
    );

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('[TodoNotification] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

