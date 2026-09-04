import {auth} from '@clerk/nextjs/server';
import {getDb} from '@/lib/db';

export type Permission =
  | 'organization.manage' | 'instructors.manage' | 'curriculum.publish_shared'
  | 'members.view' | 'members.approve' | 'belts.assign_initial'
  | 'grading.create' | 'grading.record' | 'grading.confirm' | 'grading.publish' | 'grading.correct'
  | 'resources.manage' | 'quizzes.manage' | 'announcements.manage' | 'audit.view'
  | 'attendance.record' | 'attendance.correct' | 'attendance.view_reports' | 'recognition.publish';

export class AuthorizationError extends Error {
  constructor(public readonly status: 401 | 403, message: string) {
    super(message);
  }
}

export async function requireDojangPermission(dojangId: string, permission: Permission) {
  const {userId} = await auth();
  if (!userId) throw new AuthorizationError(401, 'Unauthorized');

  const rows = await getDb()`
    SELECT EXISTS (
      SELECT 1
      FROM dojangs d
      WHERE d.id = ${dojangId}::uuid AND d.is_active = true
        AND (
          EXISTS (
            SELECT 1 FROM organization_roles r
            JOIN organization_role_permissions p ON p.role = r.role
            WHERE r.organization_id = d.organization_id
              AND r.clerk_user_id = ${userId}
              AND p.permission_key = ${permission}
          )
          OR EXISTS (
            SELECT 1 FROM dojang_roles r
            JOIN dojang_role_permissions p ON p.role = r.role
            WHERE r.dojang_id = d.id
              AND r.clerk_user_id = ${userId}
              AND p.permission_key = ${permission}
          )
        )
    ) AS allowed`;

  if (!rows[0]?.allowed) throw new AuthorizationError(403, 'Forbidden');
  return {userId};
}
