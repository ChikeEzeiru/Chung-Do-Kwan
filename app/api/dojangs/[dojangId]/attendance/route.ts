import {NextResponse} from 'next/server';
import {apiError} from '@/lib/api-errors';
import {requireDojangPermission} from '@/lib/authorization';
import {getDb} from '@/lib/db';

type Context = {params: Promise<{dojangId: string}>};

export async function GET(_request: Request, {params}: Context) {
  try {
    const {dojangId} = await params;
    await requireDojangPermission(dojangId, 'attendance.view_reports');
    const rows = await getDb()`
      SELECT cs.id, cs.title, cs.starts_at, cs.ends_at, cs.status,
        COUNT(ar.id)::integer AS attendance_count
      FROM class_sessions cs
      LEFT JOIN attendance_records ar ON ar.class_session_id = cs.id
      WHERE cs.dojang_id = ${dojangId}::uuid
      GROUP BY cs.id
      ORDER BY cs.starts_at DESC
      LIMIT 100`;
    return NextResponse.json(rows);
  } catch (error) {
    return apiError(error);
  }
}

export async function POST(request: Request, {params}: Context) {
  try {
    const {dojangId} = await params;
    const {userId} = await requireDojangPermission(dojangId, 'attendance.record');
    const body = await request.json() as {title?: unknown; startsAt?: unknown; endsAt?: unknown};
    const title = typeof body.title === 'string' ? body.title.trim() : '';
    const startsAt = typeof body.startsAt === 'string' ? body.startsAt : '';
    const endsAt = typeof body.endsAt === 'string' && body.endsAt ? body.endsAt : null;
    if (!title || title.length > 120 || !startsAt || Number.isNaN(Date.parse(startsAt)) || (endsAt && Number.isNaN(Date.parse(endsAt)))) {
      return NextResponse.json({error: 'A valid title and session time are required'}, {status: 400});
    }
    if (endsAt && Date.parse(endsAt) <= Date.parse(startsAt)) {
      return NextResponse.json({error: 'Session end must be after its start'}, {status: 400});
    }

    const db = getDb();
    const rows = await db`
      INSERT INTO class_sessions (dojang_id, title, starts_at, ends_at, created_by_user_id)
      VALUES (${dojangId}::uuid, ${title}, ${startsAt}::timestamptz, ${endsAt}::timestamptz, ${userId})
      RETURNING id, title, starts_at, ends_at, status`;
    await db`INSERT INTO audit_events (organization_id, actor_user_id, action, entity_type, entity_id, details)
      SELECT organization_id, ${userId}, 'attendance.session_created', 'class_session', ${rows[0].id}::text,
        jsonb_build_object('dojang_id', id, 'title', ${title}) FROM dojangs WHERE id = ${dojangId}::uuid`;
    return NextResponse.json(rows[0], {status: 201});
  } catch (error) {
    return apiError(error);
  }
}
