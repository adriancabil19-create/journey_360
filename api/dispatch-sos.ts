export const config = { runtime: 'edge' };

type AlertPayload = {
  userId?: string;
  userName?: string;
  latitude?: number;
  longitude?: number;
  alertType?: 'CRASH_DETECTED' | 'MANUAL_SOS';
  speedMph?: number;
};

export default async function dispatchSos(req: Request): Promise<Response> {
  if (req.method !== 'POST') return Response.json({ error: 'POST required' }, { status: 405 });

  const body = (await req.json()) as AlertPayload;
  const { userId, userName, latitude, longitude, alertType, speedMph } = body;
  if (!userId || !userName || !Number.isFinite(latitude) || !Number.isFinite(longitude) || !alertType) {
    return Response.json({ error: 'Missing emergency payload fields' }, { status: 400 });
  }

  const dispatchedAt = new Date().toISOString();
  const mapsUrl = `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`;
  const liveTrackingUrl = `https://www.google.com/maps/dir/?api=1&destination=${latitude},${longitude}`;

  // Billing is intentionally absent: every Journey360 account is VIP by default.
  console.info('JOURNEY360_EMERGENCY_DISPATCH', {
    userId,
    userName,
    alertType,
    latitude,
    longitude,
    speedMph: speedMph ?? 0,
    dispatchedAt,
  });

  return Response.json({
    ok: true,
    alertType,
    dispatchedAt,
    coordinates: { latitude, longitude },
    mapsUrl,
    liveTrackingUrl,
    message: `${alertType === 'CRASH_DETECTED' ? 'Crash' : 'SOS'} dispatch started for ${userName}.`,
  });
}
