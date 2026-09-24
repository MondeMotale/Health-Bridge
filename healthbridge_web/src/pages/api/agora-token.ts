// @ts-ignore
import { RtcTokenBuilder } from 'agora-token';

export default function handler(req: any, res: any) {
  const appId = '1322cf355b274a11bef58eb0abb46111'; // <--- PASTE YOUR APP ID HERE
  const appCertificate = 'bf12954db8fd40c8b156a97cc617c074'; // <--- PASTE YOUR CERTIFICATE HERE
  
  const channelName = typeof req.query.channel === 'string' ? req.query.channel : 'default-channel';
  
  const uid = 0; 
  const role = 1; // <--- 1 = PUBLISHER (FIXED!)
  const expirationTimeInSeconds = 3600;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  // @ts-ignore
  const token = RtcTokenBuilder.buildTokenWithUid(appId, appCertificate, channelName, uid, role, privilegeExpiredTs);

  res.status(200).json({ token });
}