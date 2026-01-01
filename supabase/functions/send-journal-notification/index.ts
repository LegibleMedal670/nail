import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient, sendFCMNotification } from '../_shared/fcm.ts';

serve(async (req) => {
  try {
    const supabase = createSupabaseClient();
    const { record } = await req.json();

    console.log('[JournalNotification] Processing message:', record.id);

    // 1. 일지 정보 조회
    const { data: journal } = await supabase
      .from('daily_journals')
      .select('mentee_id, mentor_id, date')
      .eq('id', record.journal_id)
      .single();

    if (!journal) {
      console.log('[JournalNotification] Journal not found');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 2. 발신자 정보 조회
    const { data: sender } = await supabase
      .from('app_users')
      .select('nickname, is_mentor')
      .eq('id', record.sender_id)
      .single();

    const isMentorReply = sender?.is_mentor || record.sender_id === journal.mentor_id;

    // 3. 수신자 결정 및 메시지 구성
    let recipientId: string;
    let notificationType: string;
    let title: string;
    let body: string;

    if (isMentorReply) {
      // 멘토 답변 → 멘티에게 알림
      recipientId = journal.mentee_id;
      notificationType = 'journal_replied';
      title = '일지 답변 도착';
      body = `${sender?.nickname || '멘토'}님이 일지에 답변했습니다.`;
    } else {
      // 멘티 제출(메시지/사진 추가 포함) → 멘토에게 알림 (매번 전송)
      if (!journal.mentor_id) {
        console.log('[JournalNotification] No mentor assigned');
        return new Response(JSON.stringify({ success: true }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      recipientId = journal.mentor_id;
      notificationType = 'journal_submitted';
      title = '일일 일지 제출';
      body = `${sender?.nickname || '멘티'}님이 오늘 일지를 작성했습니다.`;
    }

    // 4. 수신자 FCM 토큰 조회
    const { data: recipient } = await supabase
      .from('app_users')
      .select('fcm_token')
      .eq('id', recipientId)
      .single();

    if (!recipient?.fcm_token) {
      console.log('[JournalNotification] Recipient has no FCM token');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 5. FCM 전송
    await sendFCMNotification(
      [recipient.fcm_token],
      { title, body },
      {
        type: notificationType,
        targetId: record.journal_id,
        journalId: record.journal_id,
        date: journal.date,
        ...(isMentorReply
          ? { mentorName: sender?.nickname || '멘토' }
          : { menteeId: journal.mentee_id, menteeName: sender?.nickname || '멘티' }),
      }
    );

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('[JournalNotification] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
