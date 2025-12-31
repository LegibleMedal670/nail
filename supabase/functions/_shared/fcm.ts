// Firebase Cloud Messaging 유틸리티
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

interface FCMPayload {
  type: string;
  targetId: string;
  [key: string]: any;
}

interface NotificationContent {
  title: string;
  body: string;
}

/**
 * FCM 푸시 알림 전송 (iOS/APNs 전용)
 */
export async function sendFCMNotification(
  tokens: string[],
  notification: NotificationContent,
  data: FCMPayload
): Promise<void> {
  if (tokens.length === 0) {
    console.log('[FCM] No tokens to send');
    return;
  }

  try {
    // Firebase Service Account 로드 (JSON 또는 Base64(JSON) 모두 허용)
    const serviceAccount = loadFirebaseServiceAccountFromEnv();

    if (!serviceAccount.private_key || !serviceAccount.client_email || !serviceAccount.project_id) {
      throw new Error(
        'Firebase Service Account not configured (missing private_key/client_email/project_id)'
      );
    }

    // Access Token 생성
    const accessToken = await getAccessToken(serviceAccount);

    // FCM API v1 사용
    const projectId = serviceAccount.project_id;

    // 각 토큰별로 전송 (배치는 Firebase Admin SDK 필요)
    const results = await Promise.allSettled(
      tokens.map(async (token, index) => {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token,
                notification: {
                  title: notification.title,
                  body: notification.body,
                },
                data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),

                // iOS(APNs) 전용 설정
                apns: {
                  headers: {
                    // 즉시 알림(일반 알림): 10
                    // (조용한 푸시/백그라운드 업데이트는 보통 5를 씀)
                    'apns-priority': '10',
                    // iOS 13+에서 권장되는 push type
                    'apns-push-type': 'alert',
                  },
                  payload: {
                    aps: {
                      sound: 'default',
                      badge: 1,
                    },
                  },
                },
              },
            }),
          }
        );

        const responseText = await response.text();

        // 응답 로깅 (디버깅용)
        if (!response.ok) {
          console.error(`[FCM] Token ${index + 1} failed (${response.status}):`, responseText);
          throw new Error(`FCM API error: ${response.status} - ${responseText}`);
        }

        // 성공 응답도 에러를 포함할 수 있음
        const responseData = responseText ? JSON.parse(responseText) : {};
        if (responseData.error) {
          console.error(`[FCM] Token ${index + 1} error in response:`, responseData.error);
          throw new Error(`FCM error: ${responseData.error.message || 'Unknown error'}`);
        }

        console.log(`[FCM] Token ${index + 1} sent successfully:`, {
          token: token.substring(0, 20) + '...',
          name: responseData.name,
        });

        return responseData;
      })
    );

    const succeeded = results.filter((r) => r.status === 'fulfilled').length;
    const failed = results.filter((r) => r.status === 'rejected').length;

    console.log(`[FCM] Sent ${succeeded}/${tokens.length} notifications (${failed} failures)`);

    // 실패한 항목 상세 로깅
    if (failed > 0) {
      results.forEach((result, index) => {
        if (result.status === 'rejected') {
          console.error(`[FCM] Token ${index + 1} rejection reason:`, result.reason);
        }
      });
    }
  } catch (error) {
    console.error('[FCM] Send failed:', error);
    throw error;
  }
}

/**
 * 환경변수에서 Firebase Service Account 읽기
 * - FIREBASE_SERVICE_ACCOUNT: JSON 문자열
 * - 또는 Base64(JSON) 문자열도 허용 (운영환경에서 따옴표/개행 문제 피하려는 경우)
 */
function loadFirebaseServiceAccountFromEnv(): any {
  const raw = (Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '').trim();
  if (!raw) return {};

  // JSON이면 바로 파싱
  if (raw.startsWith('{')) {
    return JSON.parse(raw);
  }

  // 아니면 Base64(JSON)로 가정하고 디코드 후 파싱 시도
  try {
    const jsonText = atob(raw);
    const trimmed = jsonText.trim();
    if (!trimmed.startsWith('{')) {
      throw new Error('Decoded service account is not JSON');
    }
    return JSON.parse(trimmed);
  } catch (_e) {
    // 마지막으로 혹시 따옴표로 감싸진 JSON 문자열인 경우
    try {
      const unquoted = raw.replace(/^"(.*)"$/, '$1');
      if (unquoted.startsWith('{')) return JSON.parse(unquoted);
    } catch {
      // ignore
    }
    throw new Error('FIREBASE_SERVICE_ACCOUNT must be a JSON string or base64-encoded JSON string');
  }
}

/**
 * JWT를 사용하여 Firebase Access Token 생성
 */
async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600;

  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: expiry,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  };

  // JWT는 base64url 인코딩이 정석
  const headerB64u = base64UrlEncode(JSON.stringify(header));
  const payloadB64u = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${headerB64u}.${payloadB64u}`;

  // RS256 서명 (결과도 base64url)
  const signatureB64u = await signRS256Base64Url(unsignedToken, serviceAccount.private_key);
  const jwt = `${unsignedToken}.${signatureB64u}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }).toString(),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to get access token: ${error}`);
  }

  const data = await response.json();
  return data.access_token;
}

/**
 * RS256 서명 생성 (base64url 반환)
 */
async function signRS256Base64Url(data: string, privateKeyPem: string): Promise<string> {
  const pkcs8Der = pemToPkcs8Der(privateKeyPem);

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pkcs8Der,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );

  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(data));

  return base64UrlEncode(new Uint8Array(signature));
}

/**
 * PEM(-----BEGIN PRIVATE KEY-----) -> PKCS#8 DER(Uint8Array)
 * - substring 가정 제거: 정규식으로 안전하게 추출
 * - \n, \\n, \r\n 혼재 케이스 정리
 */
function pemToPkcs8Der(pem: string): Uint8Array {
  if (!pem) throw new Error('Empty private key');

  // Supabase secrets에 따라 \\n 형태로 들어오는 경우가 많음
  const normalized = pem.trim().replace(/\r\n/g, '\n').replace(/\\n/g, '\n');

  // 표준 Service Account 키는 PKCS#8: "BEGIN PRIVATE KEY"
  const match = normalized.match(/-----BEGIN PRIVATE KEY-----([\s\S]*?)-----END PRIVATE KEY-----/m);

  if (!match) {
    // 혹시 "BEGIN RSA PRIVATE KEY" 형태면 여기서 걸리는데,
    // Deno crypto.subtle.importKey('pkcs8', ...)에 바로 못 넣습니다.
    // (변환이 필요) -> 명확히 에러 메시지로 안내
    const rsaMatch = normalized.match(
      /-----BEGIN RSA PRIVATE KEY-----([\s\S]*?)-----END RSA PRIVATE KEY-----/m
    );
    if (rsaMatch) {
      throw new Error(
        'Private key is PKCS#1 (BEGIN RSA PRIVATE KEY). Firebase service account keys should be PKCS#8 (BEGIN PRIVATE KEY). Please download a new key JSON from Firebase Console.'
      );
    }
    throw new Error('Invalid PEM format: missing BEGIN/END PRIVATE KEY block');
  }

  const base64Body = match[1].replace(/\s/g, '');
  if (!base64Body) throw new Error('Invalid PEM: empty base64 body');

  // Base64 padding 보정 (혹시 깨진 경우 대비)
  const padded = base64Body + '='.repeat((4 - (base64Body.length % 4)) % 4);

  let binary: string;
  try {
    binary = atob(padded);
  } catch (e) {
    throw new Error(
      `Failed to base64-decode private key body. (len=${base64Body.length}) Original error: ${String(e)}`
    );
  }

  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/**
 * base64url encode
 * - string 입력: UTF-8로 인코딩 후 base64url
 * - bytes 입력: 그대로 base64url
 */
function base64UrlEncode(input: string | Uint8Array): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;

  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }

  const b64 = btoa(binary);
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

/**
 * Supabase Client 생성
 */
export function createSupabaseClient() {
  return createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
}
