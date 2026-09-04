import {NextResponse} from 'next/server';
import {AuthorizationError} from '@/lib/authorization';

export function apiError(error: unknown) {
  if (error instanceof AuthorizationError) {
    return NextResponse.json({error: error.message}, {status: error.status});
  }
  console.error(error);
  return NextResponse.json({error: 'Internal server error'}, {status: 500});
}
