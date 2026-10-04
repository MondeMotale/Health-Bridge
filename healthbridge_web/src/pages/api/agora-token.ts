// @ts-ignore
import { RtcTokenBuilder } from 'agora-token';

export default function handler(req: any, res: any) {
  // Read secrets from environment variables (set in Vercel)
  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  if (!appId || !appCertificate) {
    res.status(500).json({ error: 'Agora credentials not configured on server' });
    return;
  }

  const channelName =
    typeof req.query.channel === 'string' ? req.query.channel : 'default-channel';

  // Allow the client to specify its uid (fallback to 0)
  const uid =
    typeof req.query.uid === 'string' && req.query.uid.length > 0
      ? parseInt(req.query.uid, 10)
      : 0;

  const role = 1; // 1 = PUBLISHER (can send audio/video)
  const expirationTimeInSeconds = 3600;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  // @ts-ignore
  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    role,
    privilegeExpiredTs
  );

  res.status(200).json({ token, uid, channel: channelName });
}
