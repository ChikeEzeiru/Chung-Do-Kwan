import {NextResponse} from 'next/server';
import {apiError} from '@/lib/api-errors';
import {requireDojangPermission} from '@/lib/authorization';
import {getDb} from '@/lib/db';

type Context = {params: Promise<{sessionId: string}>};
const statuses = new Set(['present', 'late', 'excused', 'absent']);

async function sessionDojang(sessionId: string) {
  const rows = await getDb()`SELECT dojang_id FROM class_sessions WHERE id = ${sessionId}::uuid`;
  return rows[0]?.dojang_id as string | undefined;
}

export async function GET(_request: Request, {params}: Context) {
  try {
    const {sessionId} = await params;
    const dojangId = await sessionDojang(sessionId);
    if (!dojangId) return NextResponse.json({error: 'Session not found'}, {status: 404});
    await requireDojangPermission(dojangId, 'attendance.view_reports');
    const rows = await getDb()`
      SELECT ar.student_id, s.full_name, ar.status, ar.private_note, ar.recorded_at, ar.updated_at
      FROM attendance_records ar JOIN students s ON s.id = ar.student_id
      WHERE ar.class_session_id = ${sessionId}::uuid ORDER BY s.full_name`;
    return NextResponse.json(rows);
  } catch (error) {
    return apiError(error);
  }
}

export async function PUT(request: Request, {params}: Context) {
  try {
    const {sessionId} = await params;
    const dojangId = await sessionDojang(sessionId);
    if (!dojangId) return NextResponse.json({error: 'Session not found'}, {status: 404});
    const {userId} = await requireDojangPermission(dojangId, 'attendance.correct');
    const body = await request.json() as {records?: unknown};
    if (!Array.isArray(body.records) || body.records.length > 500) {
      return NextResponse.json({error: 'Records must be an array of at most 500 entries'}, {status: 400});
    }
    const records = body.records.map((item: unknown) => {
      const value = item as {studentId?: unknown; status?: unknown; privateNote?: unknown};
      return {
        studentId: typeof value.studentId === 'string' ? value.studentId : '',
        status: typeof value.status === 'string' ? value.status : '',
        privateNote: typeof value.privateNote === 'string' ? value.privateNote.trim().slice(0, 1000) : null,
      };
    });
    if (records.some(record => !record.studentId || !statuses.has(record.status))) {
      return NextResponse.json({error: 'Every record requires a valid student and attendance status'}, {status: 400});
    }

    const db = getDb();
    const eligible = await db`
      SELECT sm.student_id FROM student_memberships sm
      WHERE sm.dojang_id = ${dojangId}::uuid AND sm.status = 'active'
        AND sm.student_id = ANY(${records.map(record => record.studentId)}::uuid[])`;
    if (eligible.length !== new Set(records.map(record => record.studentId)).size) {
      return NextResponse.json({error: 'Attendance can only be recorded for active students in this dojang'}, {status: 400});
    }

    for (const record of records) {
      await db`INSERT INTO attendance_records
        (class_session_id, student_id, status, private_note, recorded_by_user_id)
        VALUES (${sessionId}::uuid, ${record.studentId}::uuid, ${record.status}, ${record.privateNote}, ${userId})
        ON CONFLICT (class_session_id, student_id) DO UPDATE SET
          status = EXCLUDED.status, private_note = EXCLUDED.private_note,
          recorded_by_user_id = EXCLUDED.recorded_by_user_id, updated_at = now()`;
    }
    await db`INSERT INTO audit_events (organization_id, actor_user_id, action, entity_type, entity_id, details)
      SELECT d.organization_id, ${userId}, 'attendance.records_updated', 'class_session', ${sessionId},
        jsonb_build_object('dojang_id', d.id, 'record_count', ${records.length})
      FROM dojangs d WHERE d.id = ${dojangId}::uuid`;
    return NextResponse.json({updated: records.length});
  } catch (error) {
    return apiError(error);
  }
}
