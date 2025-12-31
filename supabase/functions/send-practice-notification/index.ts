import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient, sendFCMNotification } from '../_shared/fcm.ts';

serve(async (req) => {
  try {
    const supabase = createSupabaseClient();
    const { record, old_record } = await req.json();

    console.log('[PracticeNotification] Processing:', record.id);

    // 제출 알림 (INSERT 또는 status가 pending으로 변경)
    const isSubmitted = !old_record || (old_record.status !== 'pending' && record.status === 'pending');
    
    // 검토 완료 알림 (status가 reviewed로 변경)
    const isReviewed = old_record && old_record.status !== 'reviewed' && record.status === 'reviewed';

    if (!isSubmitted && !isReviewed) {
      return new Response(JSON.stringify({ success: true, skipped: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 멘티 정보 조회
    const { data: mentee } = await supabase
      .from('app_users')
      .select('nickname, mentor, fcm_token')
      .eq('id', record.mentee_id)
      .single();

    // 실습 세트 정보 조회
    const { data: practiceSet } = await supabase
      .from('practice_sets')
      .select('title, code')
      .eq('id', record.set_id)
      .single();

    if (isSubmitted) {
      // 멘티 실습 제출 → 멘토 알림
      if (!mentee?.mentor) {
        console.log('[PracticeNotification] No mentor assigned');
        return new Response(JSON.stringify({ success: true }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // 멘토 정보 조회
      const { data: mentor } = await supabase
        .from('app_users')
        .select('fcm_token')
        .eq('id', mentee.mentor)
        .single();

      if (!mentor?.fcm_token) {
        console.log('[PracticeNotification] Mentor has no FCM token');
        return new Response(JSON.stringify({ success: true }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      await sendFCMNotification(
        [mentor.fcm_token],
        {
          title: '실습 제출 알림',
          body: `${mentee.nickname}님이 "${practiceSet?.title || '실습'}" 실습을 제출했습니다.`,
        },
        {
          type: 'practice_submitted',
          targetId: record.id,
          menteeId: record.mentee_id,
          menteeName: mentee.nickname,
          setTitle: practiceSet?.title || '실습',
          setCode: practiceSet?.code || '',
          attemptNo: record.attempt_no.toString(),
        }
      );
    } else if (isReviewed) {
      // 멘토 검토 완료 → 멘티 알림
      if (!mentee?.fcm_token) {
        console.log('[PracticeNotification] Mentee has no FCM token');
        return new Response(JSON.stringify({ success: true }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // 리뷰어 정보 조회
      const { data: reviewer } = await supabase
        .from('app_users')
        .select('nickname')
        .eq('id', record.reviewer_id)
        .single();

      const gradeText = record.grade === 'high' ? '상' : record.grade === 'mid' ? '중' : '하';

      await sendFCMNotification(
        [mentee.fcm_token],
        {
          title: '실습 검토 완료',
          body: `"${practiceSet?.title || '실습'}" 실습이 검토되었습니다. (등급: ${gradeText})`,
        },
        {
          type: 'practice_reviewed',
          targetId: record.id,
          setTitle: practiceSet?.title || '실습',
          setCode: practiceSet?.code || '',
          grade: gradeText,
          mentorName: reviewer?.nickname || '멘토',
          attemptNo: record.attempt_no.toString(),
        }
      );
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('[PracticeNotification] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

