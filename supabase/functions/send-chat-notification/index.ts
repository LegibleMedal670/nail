import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createSupabaseClient, sendFCMNotification } from '../_shared/fcm.ts';

serve(async (req) => {
  try {
    const supabase = createSupabaseClient();
    const { record } = await req.json();

    console.log('[ChatNotification] Processing message:', record.id);

    // 1. 발신자 정보 조회
    const { data: sender } = await supabase
      .from('app_users')
      .select('nickname')
      .eq('id', record.sender_id)
      .single();

    // 2. 채팅방 정보 조회
    const { data: room } = await supabase
      .from('chat_rooms')
      .select('name')
      .eq('id', record.room_id)
      .single();

    // 3. 방 멤버 조회 (발신자 제외, FCM 토큰 있는 사용자만)
    const { data: members } = await supabase
      .from('chat_room_members')
      .select(`
        user_id,
        app_users!inner(fcm_token)
      `)
      .eq('room_id', record.room_id)
      .neq('user_id', record.sender_id);

    if (!members || members.length === 0) {
      console.log('[ChatNotification] No recipients');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 4. FCM 토큰 수집
    const tokens = members
      .map((m: any) => m.app_users?.fcm_token)
      .filter(Boolean);

    if (tokens.length === 0) {
      console.log('[ChatNotification] No FCM tokens');
      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 5. 메시지 미리보기
    let preview = '';
    if (record.type === 'text' && record.text) {
      preview = record.text.length > 50 
        ? record.text.substring(0, 50) + '...' 
        : record.text;
    } else if (record.type === 'image') {
      preview = '사진을 보냈습니다.';
    } else if (record.type === 'file') {
      preview = '파일을 보냈습니다.';
    }

    // 6. FCM 전송
    await sendFCMNotification(
      tokens,
      {
        title: room?.name || '채팅',
        body: `${sender?.nickname || '사용자'}: ${preview}`,
      },
      {
        type: 'chat',
        targetId: record.room_id,
        senderId: record.sender_id,
        senderName: sender?.nickname || '사용자',
        roomName: room?.name || '채팅',
        messageId: record.id.toString(),
      }
    );

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('[ChatNotification] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

