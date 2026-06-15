# STOPPED: 2.4 Admin dashboard summary RPC

**Date:** 2026-06-16
**Branch:** sprint-2026-06-16-0519
**Status:** หยุด — judgment call (constraints ขัดกันเอง) → ไม่ commit, รอ M ตัดสินใจ design

## สรุปปัญหา (ทำไมหยุด)

Task ขอ 2 อย่างที่ขัดกันโดยตรง:

1. **"แทนการดาวน์โหลด user_activity ... ทั้งหมดด้วย RPC call"** (server-side aggregate)
2. **"ห้ามลบ/แก้ filteredActs / activity state / state ใดๆ ที่ AdminDashboard ใช้"** + "ห้ามตัด Leaflet map (lat/lng + ชื่อ)" + CSV export

ปัญหา: AdminDashboard (`index.html:7731–8065`) คำนวณ **ทุกอย่าง** จาก raw array `activities` ที่โหลดมา (`.limit(10000)`):

| Derived stat | บรรทัด | อ่านจาก raw activity |
|---|---|---|
| `filteredActs` (activity tab list + CSV) | 7931, 8052, 8137 | ✅ ต้องมี raw rows |
| `userActiveAt` → DAU/WAU/MAU | 7933–7946 | ✅ ทุก user, ทุก row |
| country breakdown | 7953–7959 | ✅ filteredActs |
| hour-of-day / weekday | 7962–7975 | ✅ filteredActs |
| growth chart `dailyData` (สูงสุด **365 วัน**) | 7978–8006 | ✅ activities.filter ต่อวัน |
| `eventsByUser` (users tab) | 8032–8035 | ✅ ทุก row |
| `usersWithMeta[].country` | 8042 | ✅ activities.filter ต่อ user |
| `userGeo` (Leaflet map) | 8055–8065 | ✅ lat/lng ต่อ user |

**ถ้าตัด `.limit(10000)` download → เปลี่ยน `activities` เป็น sample/aggregate:** ทุก stat ด้านบนที่ยังอ่าน `activities`/`filteredActs` จะคำนวณจาก subset → **ยอดผิดเงียบๆ** (DAU/MAU/growth/country/map หาย) นี่คือ correctness regression แบบเดียวกับ v3.7.40 (pos sales `.reduce` บน `.limit(500)`) ที่ bug-hunter ตั้งใจจับเป็น HIGH

→ จะทำให้ "replace download" ถูกต้องได้ ต้อง **re-source ทุก stat ให้มาจาก RPC** (map geo, recent list, growth series, breakdowns ทั้งหมด server-side) = rewrite data layer ของ dashboard ทั้งก้อน ซึ่งขัด "ห้ามแก้ state/filteredActs" และเสี่ยงสูง — เป็น **design decision ที่ M ควรตัดสิน** ไม่ใช่ AI ตัดสินเอง

## คำถามที่ต้องการคำตอบจาก M (เพื่อ unblock)

1. RPC ควร return อะไรบ้าง? (aggregates อย่างเดียว / + geo points / + recent sample / + daily series)
2. ยอม **เปลี่ยน source** ของ growth chart, country/hour/weekday, DAU/MAU จาก client-compute → RPC fields ไหม? (ถ้าไม่ → ตัด download ไม่ได้)
3. CSV export activity tab: ยอมเปลี่ยนเป็น "recent N rows" หรือ server-export แทน "ทุก row ในช่วง" ไหม?
4. `activities` state ยังต้องเป็น raw array (เพื่อ map + filteredActs) — ถ้าใช่ RPC ต้อง return rows อยู่ดี → "ไม่ได้ replace download จริง" แค่ bound ขนาด ตกลงไหม?

## แผนที่แนะนำ (phased, ปลอดภัย — ทำเมื่อ M เคลียร์ design)

**Phase A (low-risk, additive):** สร้าง RPC + ใช้เฉพาะ summary cards
- เพิ่ม RPC `admin_dashboard_summary(p_since)` (SQL ด้านล่าง พร้อมใช้)
- Client: **คงทุก state/download เดิมไว้** เพิ่ม state `summary` จาก RPC แล้วใช้แทน *เฉพาะ* ตัวเลขการ์ด overview (DAU/MAU/total events/top-actions) ที่ตอนนี้ derive จาก activities
- ยังไม่ตัด download → ไม่มี regression. ได้ accuracy เกิน 10k limit ทันที (เหมือน v3.7.40)

**Phase B (ต้อง M ยืนยัน):** ลด download
- RPC return `geo[]` (per-user last lat/lng) + `recent[]` (N rows) + `daily[]` series
- เปลี่ยน map → `summary.geo`, growth → `summary.daily`, activity list/CSV → `summary.recent`
- ตัด `.limit(10000)` ออก, profiles เปลี่ยนเป็น paginated query
- ต้อง audit ทุกจุดในตารางด้านบนว่า re-source ครบ ("ตรวจให้ครบ")

## RPC SQL (พร้อมใช้ — ใส่ pending/ เมื่อ M อนุมัติ direction)

```sql
-- admin_dashboard_summary(p_since timestamptz)
-- Server-side aggregation: DAU/WAU/MAU, total events, top actions, new users.
-- SECURITY DEFINER + is_admin gate. (Phase A: aggregates only.)
create or replace function public.admin_dashboard_summary(p_since timestamptz)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean;
  result json;
begin
  select coalesce(is_admin, false) into v_is_admin
    from public.profiles where id = auth.uid();
  if not coalesce(v_is_admin, false) then
    raise exception 'not_admin';
  end if;

  select json_build_object(
    'dau', (select count(distinct user_id) from public.user_activity
              where created_at >= now() - interval '1 day'),
    'wau', (select count(distinct user_id) from public.user_activity
              where created_at >= now() - interval '7 days'),
    'mau', (select count(distinct user_id) from public.user_activity
              where created_at >= now() - interval '30 days'),
    'total_events', (select count(*) from public.user_activity
              where created_at >= p_since),
    'total_users', (select count(*) from public.profiles),
    'new_users_today', (select count(*) from public.profiles
              where created_at >= now() - interval '1 day'),
    'new_users_week', (select count(*) from public.profiles
              where created_at >= now() - interval '7 days'),
    'top_actions', (select coalesce(json_agg(row_to_json(t)), '[]'::json) from (
        select event_type, count(*) as n
          from public.user_activity
          where created_at >= p_since
          group by event_type order by n desc limit 10
      ) t),
    'top_countries', (select coalesce(json_agg(row_to_json(c)), '[]'::json) from (
        select coalesce(country,'—') as country, count(*) as n
          from public.user_activity
          where created_at >= p_since
          group by country order by n desc limit 8
      ) c)
  ) into result;

  return result;
end;
$$;

revoke all on function public.admin_dashboard_summary(timestamptz) from public, anon;
grant execute on function public.admin_dashboard_summary(timestamptz) to authenticated;
```

## ไฟล์ที่เกี่ยวข้อง
- `index.html:7752–7795` — `loadData()` (download 10k activity + all profiles)
- `index.html:7799–7846` — Leaflet map effect (ใช้ activities geo + profiles names)
- `index.html:7920–8065` — derived stats ทั้งหมด
- `index.html:8136–8147` — CSV export activity
- `docs/2026-06-15-research-action-plan.md` task 2.4

**ไม่มีการแก้ index.html / ไม่ commit** — ตาม policy (ambiguous → note + exit).
