import {auth} from '@clerk/nextjs/server';
import {neon} from '@neondatabase/serverless';
import {NextResponse} from 'next/server';

const db=()=>{if(!process.env.DATABASE_URL)throw new Error('DATABASE_URL is not configured');return neon(process.env.DATABASE_URL)};
export async function GET(){const {userId}=await auth();if(!userId)return NextResponse.json({error:'Unauthorized'},{status:401});const rows=await db()`SELECT best,missed,answered FROM quiz_progress WHERE user_id=${userId}`;return NextResponse.json(rows[0]??null)}
export async function POST(req:Request){const {userId}=await auth();if(!userId)return NextResponse.json({error:'Unauthorized'},{status:401});const p=await req.json() as {best?:unknown;missed?:unknown;answered?:unknown};const best=Math.max(0,Math.min(100,Number(p.best)||0));const answered=Math.max(0,Number(p.answered)||0);const missed=Array.isArray(p.missed)?p.missed.filter((x:unknown)=>typeof x==='string'):[];const rows=await db()`INSERT INTO quiz_progress(user_id,best,missed,answered) VALUES(${userId},${best},${JSON.stringify(missed)}::jsonb,${answered}) ON CONFLICT(user_id) DO UPDATE SET best=EXCLUDED.best,missed=EXCLUDED.missed,answered=EXCLUDED.answered,updated_at=now() RETURNING best,missed,answered`;return NextResponse.json(rows[0])}
