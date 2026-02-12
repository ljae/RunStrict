#!/usr/bin/env python3
"""Push Day 1 simulation data via Supabase REST API (PostgREST).
Uses service_role key to bypass RLS."""

import json
import requests

SUPABASE_URL = "https://vhooaslzkmbnzmzwiium.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZob29hc2x6a21ibnptendpaXVtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2OTIyNTQ0NSwiZXhwIjoyMDg0ODAxNDQ1fQ.xb3RnprzMqVMRqMcIL8U0Yp7fNDPyigkAFM3Bo5mFD0"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}

def post(table, data, upsert=False):
    """POST to a table. If upsert=True, merge on conflict."""
    headers = dict(HEADERS)
    if upsert:
        headers["Prefer"] = "resolution=merge-duplicates"
    resp = requests.post(f"{SUPABASE_URL}/rest/v1/{table}", headers=headers, json=data)
    if resp.status_code not in (200, 201):
        print(f"ERROR {table}: {resp.status_code} {resp.text[:500]}")
        return False
    return True

def patch(table, filters, data):
    """PATCH (update) rows matching filters."""
    resp = requests.patch(f"{SUPABASE_URL}/rest/v1/{table}?{filters}", headers=HEADERS, json=data)
    if resp.status_code not in (200, 204):
        print(f"ERROR PATCH {table}: {resp.status_code} {resp.text[:500]}")
        return False
    return True

# ============================================================
# 1. INSERT RUN HISTORY (45 runs)
# ============================================================
print("=== Inserting run_history (45 runs) ===")
runs = [
    {"id": "323f2221-3126-41e5-bade-98b373aae29a", "user_id": "aaaaaaaa-0000-0000-0000-000000000000", "run_date": "2026-02-11", "start_time": "2026-02-11T16:00:00+00:00", "end_time": "2026-02-11T16:51:11+00:00", "distance_km": 9.36, "duration_seconds": 3071, "avg_pace_min_per_km": 5.47, "flip_count": 18, "flip_points": 18, "team_at_run": "red", "cv": 7.6},
    {"id": "fd515e95-b257-48a1-a0c1-eb8de312be99", "user_id": "aaaaaaaa-0001-0001-0001-000000000001", "run_date": "2026-02-11", "start_time": "2026-02-11T17:54:00+00:00", "end_time": "2026-02-11T19:09:25+00:00", "distance_km": 13.74, "duration_seconds": 4525, "avg_pace_min_per_km": 5.49, "flip_count": 23, "flip_points": 23, "team_at_run": "red", "cv": 5.2},
    {"id": "cb8a2a0c-e652-4052-bc65-1dfee5f610a1", "user_id": "aaaaaaaa-0002-0002-0002-000000000002", "run_date": "2026-02-11", "start_time": "2026-02-11T19:42:00+00:00", "end_time": "2026-02-11T20:39:09+00:00", "distance_km": 12.59, "duration_seconds": 3429, "avg_pace_min_per_km": 4.54, "flip_count": 11, "flip_points": 11, "team_at_run": "red", "cv": 4.7},
    {"id": "f3be83a3-b6f2-482b-b0ad-fde505fda152", "user_id": "aaaaaaaa-0003-0003-0003-000000000003", "run_date": "2026-02-11", "start_time": "2026-02-11T06:07:00+00:00", "end_time": "2026-02-11T07:04:09+00:00", "distance_km": 12.32, "duration_seconds": 3429, "avg_pace_min_per_km": 4.64, "flip_count": 9, "flip_points": 9, "team_at_run": "red", "cv": 6.7},
    {"id": "5d108e90-ac3f-443f-800b-0f8d6bf80f9d", "user_id": "aaaaaaaa-0004-0004-0004-000000000004", "run_date": "2026-02-11", "start_time": "2026-02-11T09:31:00+00:00", "end_time": "2026-02-11T10:35:20+00:00", "distance_km": 11.72, "duration_seconds": 3860, "avg_pace_min_per_km": 5.49, "flip_count": 4, "flip_points": 4, "team_at_run": "red", "cv": 4.5},
    {"id": "0880ea59-ecf8-41e1-8985-5b40e0b866e8", "user_id": "aaaaaaaa-0006-0006-0006-000000000006", "run_date": "2026-02-11", "start_time": "2026-02-11T07:12:00+00:00", "end_time": "2026-02-11T08:19:37+00:00", "distance_km": 14.42, "duration_seconds": 4057, "avg_pace_min_per_km": 4.69, "flip_count": 6, "flip_points": 6, "team_at_run": "red", "cv": 6.4},
    {"id": "08db3b28-5634-4bda-af7d-8e1b04f65af9", "user_id": "aaaaaaaa-0007-0007-0007-000000000007", "run_date": "2026-02-11", "start_time": "2026-02-11T11:08:00+00:00", "end_time": "2026-02-11T12:11:32+00:00", "distance_km": 11.92, "duration_seconds": 3812, "avg_pace_min_per_km": 5.33, "flip_count": 6, "flip_points": 6, "team_at_run": "red", "cv": 3.6},
    {"id": "4b3641b0-e013-456b-bd31-f07d656453c4", "user_id": "aaaaaaaa-0008-0008-0008-000000000008", "run_date": "2026-02-11", "start_time": "2026-02-11T19:24:00+00:00", "end_time": "2026-02-11T20:20:27+00:00", "distance_km": 10.9, "duration_seconds": 3387, "avg_pace_min_per_km": 5.18, "flip_count": 4, "flip_points": 4, "team_at_run": "red", "cv": 7.4},
    {"id": "2ff6169c-c9c1-4c40-99eb-5dea3c723b19", "user_id": "aaaaaaaa-0009-0009-0009-000000000009", "run_date": "2026-02-11", "start_time": "2026-02-11T17:05:00+00:00", "end_time": "2026-02-11T17:51:49+00:00", "distance_km": 9.92, "duration_seconds": 2809, "avg_pace_min_per_km": 4.72, "flip_count": 4, "flip_points": 4, "team_at_run": "red", "cv": 7.2},
    {"id": "b4bfd467-199f-4c38-aa48-eee72acdb7a0", "user_id": "aaaaaaaa-0010-0010-0010-000000000010", "run_date": "2026-02-11", "start_time": "2026-02-11T06:25:00+00:00", "end_time": "2026-02-11T07:12:52+00:00", "distance_km": 8.55, "duration_seconds": 2872, "avg_pace_min_per_km": 5.6, "flip_count": 3, "flip_points": 3, "team_at_run": "red", "cv": 14.0},
    {"id": "17662f51-63ab-48ed-bc8b-4907325294d7", "user_id": "aaaaaaaa-0011-0011-0011-000000000011", "run_date": "2026-02-11", "start_time": "2026-02-11T21:36:00+00:00", "end_time": "2026-02-11T22:06:04+00:00", "distance_km": 5.02, "duration_seconds": 1804, "avg_pace_min_per_km": 5.99, "flip_count": 3, "flip_points": 3, "team_at_run": "red", "cv": 12.2},
    {"id": "f4e84666-ccbf-40e2-88c1-9887ec5a1f6a", "user_id": "aaaaaaaa-0012-0012-0012-000000000012", "run_date": "2026-02-11", "start_time": "2026-02-11T07:04:00+00:00", "end_time": "2026-02-11T07:47:28+00:00", "distance_km": 8.25, "duration_seconds": 2608, "avg_pace_min_per_km": 5.27, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 11.7},
    {"id": "c48efb35-9edd-4c25-98a9-f927e870a1ae", "user_id": "aaaaaaaa-0016-0016-0016-000000000016", "run_date": "2026-02-11", "start_time": "2026-02-11T11:51:00+00:00", "end_time": "2026-02-11T12:31:07+00:00", "distance_km": 6.38, "duration_seconds": 2407, "avg_pace_min_per_km": 6.29, "flip_count": 1, "flip_points": 1, "team_at_run": "red", "cv": 7.9},
    {"id": "7e09eb37-ad5d-47db-b427-d32b16567a82", "user_id": "aaaaaaaa-0018-0018-0018-000000000018", "run_date": "2026-02-11", "start_time": "2026-02-11T21:45:00+00:00", "end_time": "2026-02-11T22:25:06+00:00", "distance_km": 6.88, "duration_seconds": 2406, "avg_pace_min_per_km": 5.83, "flip_count": 1, "flip_points": 1, "team_at_run": "red", "cv": 10.4},
    {"id": "54d451d4-cd44-49bc-8849-c739d3fed925", "user_id": "aaaaaaaa-0019-0019-0019-000000000019", "run_date": "2026-02-11", "start_time": "2026-02-11T17:32:00+00:00", "end_time": "2026-02-11T18:33:53+00:00", "distance_km": 9.87, "duration_seconds": 3713, "avg_pace_min_per_km": 6.27, "flip_count": 4, "flip_points": 4, "team_at_run": "red", "cv": 9.6},
    {"id": "adadf39f-165a-4020-bf3f-d4ecb33f17a9", "user_id": "aaaaaaaa-0020-0020-0020-000000000020", "run_date": "2026-02-11", "start_time": "2026-02-11T06:33:00+00:00", "end_time": "2026-02-11T07:19:13+00:00", "distance_km": 9.17, "duration_seconds": 2773, "avg_pace_min_per_km": 5.04, "flip_count": 3, "flip_points": 3, "team_at_run": "red", "cv": 9.3},
    {"id": "b4568f69-ba9f-42f7-8336-ce6d27e5bb91", "user_id": "aaaaaaaa-0021-0021-0021-000000000021", "run_date": "2026-02-11", "start_time": "2026-02-11T06:31:00+00:00", "end_time": "2026-02-11T07:15:32+00:00", "distance_km": 7.4, "duration_seconds": 2672, "avg_pace_min_per_km": 6.02, "flip_count": 0, "flip_points": 0, "team_at_run": "red", "cv": 6.5},
    {"id": "23f817f4-287d-4529-9671-c294e1fbf064", "user_id": "aaaaaaaa-0022-0022-0022-000000000022", "run_date": "2026-02-11", "start_time": "2026-02-11T20:12:00+00:00", "end_time": "2026-02-11T20:51:52+00:00", "distance_km": 7.82, "duration_seconds": 2392, "avg_pace_min_per_km": 5.1, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 9.1},
    {"id": "0882ef31-6ce5-4fd6-a0a3-59349d3198dc", "user_id": "aaaaaaaa-0023-0023-0023-000000000023", "run_date": "2026-02-11", "start_time": "2026-02-11T21:22:00+00:00", "end_time": "2026-02-11T21:55:00+00:00", "distance_km": 6.46, "duration_seconds": 1980, "avg_pace_min_per_km": 5.11, "flip_count": 1, "flip_points": 1, "team_at_run": "red", "cv": 5.8},
    {"id": "b12abf86-15e1-4a22-9a7d-1caba4ceeb41", "user_id": "aaaaaaaa-0024-0024-0024-000000000024", "run_date": "2026-02-11", "start_time": "2026-02-11T07:47:00+00:00", "end_time": "2026-02-11T08:33:55+00:00", "distance_km": 9.13, "duration_seconds": 2815, "avg_pace_min_per_km": 5.14, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 8.6},
    {"id": "44fbbafa-6f34-4490-b25c-0884ea95a4f0", "user_id": "aaaaaaaa-0026-0026-0026-000000000026", "run_date": "2026-02-11", "start_time": "2026-02-11T08:49:00+00:00", "end_time": "2026-02-11T09:27:38+00:00", "distance_km": 6.44, "duration_seconds": 2318, "avg_pace_min_per_km": 6.0, "flip_count": 4, "flip_points": 4, "team_at_run": "red", "cv": 9.0},
    {"id": "90306e33-7684-4b86-afeb-f0dac2f77cdb", "user_id": "aaaaaaaa-0029-0029-0029-000000000029", "run_date": "2026-02-11", "start_time": "2026-02-11T18:50:00+00:00", "end_time": "2026-02-11T19:25:00+00:00", "distance_km": 6.33, "duration_seconds": 2100, "avg_pace_min_per_km": 5.53, "flip_count": 0, "flip_points": 0, "team_at_run": "red", "cv": 14.2},
    {"id": "eb7ef9d1-1036-4a2f-a9e6-eafeb9751b8e", "user_id": "aaaaaaaa-0032-0032-0032-000000000032", "run_date": "2026-02-11", "start_time": "2026-02-11T14:09:00+00:00", "end_time": "2026-02-11T14:42:27+00:00", "distance_km": 5.76, "duration_seconds": 2007, "avg_pace_min_per_km": 5.81, "flip_count": 1, "flip_points": 1, "team_at_run": "red", "cv": 7.3},
    {"id": "a7edafae-faf3-49a6-8cb9-036a70aed062", "user_id": "aaaaaaaa-0033-0033-0033-000000000033", "run_date": "2026-02-11", "start_time": "2026-02-11T19:32:00+00:00", "end_time": "2026-02-11T20:20:11+00:00", "distance_km": 9.32, "duration_seconds": 2891, "avg_pace_min_per_km": 5.17, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 5.9},
    {"id": "88978d86-1456-411d-b774-353f9929a077", "user_id": "aaaaaaaa-0034-0034-0034-000000000034", "run_date": "2026-02-11", "start_time": "2026-02-11T20:15:00+00:00", "end_time": "2026-02-11T21:08:24+00:00", "distance_km": 9.71, "duration_seconds": 3204, "avg_pace_min_per_km": 5.5, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 14.5},
    {"id": "ebbf8cc8-c7ca-4daa-8898-466ea6365d24", "user_id": "aaaaaaaa-0035-0035-0035-000000000035", "run_date": "2026-02-11", "start_time": "2026-02-11T19:48:00+00:00", "end_time": "2026-02-11T20:34:16+00:00", "distance_km": 7.83, "duration_seconds": 2776, "avg_pace_min_per_km": 5.91, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 12.2},
    {"id": "9ce3ca57-bcce-4900-853e-9e78136ca5ac", "user_id": "aaaaaaaa-0036-0036-0036-000000000036", "run_date": "2026-02-11", "start_time": "2026-02-11T06:35:00+00:00", "end_time": "2026-02-11T07:27:22+00:00", "distance_km": 9.47, "duration_seconds": 3142, "avg_pace_min_per_km": 5.53, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 9.1},
    {"id": "e72eabad-4042-478e-b673-1c1885a1e247", "user_id": "aaaaaaaa-0037-0037-0037-000000000037", "run_date": "2026-02-11", "start_time": "2026-02-11T11:54:00+00:00", "end_time": "2026-02-11T12:46:19+00:00", "distance_km": 8.96, "duration_seconds": 3139, "avg_pace_min_per_km": 5.84, "flip_count": 2, "flip_points": 2, "team_at_run": "red", "cv": 14.6},
    {"id": "027708b7-4715-483f-89d4-6c80bed0c9c3", "user_id": "aaaaaaaa-0039-0039-0039-000000000039", "run_date": "2026-02-11", "start_time": "2026-02-11T15:11:00+00:00", "end_time": "2026-02-11T16:06:35+00:00", "distance_km": 8.66, "duration_seconds": 3335, "avg_pace_min_per_km": 6.42, "flip_count": 1, "flip_points": 1, "team_at_run": "red", "cv": 8.0},
    {"id": "6a81e0e8-f11f-4e22-8ee6-7c119b874c5b", "user_id": "aaaaaaaa-0041-0041-0041-000000000041", "run_date": "2026-02-11", "start_time": "2026-02-11T14:15:00+00:00", "end_time": "2026-02-11T14:46:23+00:00", "distance_km": 5.77, "duration_seconds": 1883, "avg_pace_min_per_km": 5.44, "flip_count": 13, "flip_points": 13, "team_at_run": "blue", "cv": 5.2},
    {"id": "8e16dabe-440f-4fb8-8f82-b9e3194be14b", "user_id": "aaaaaaaa-0042-0042-0042-000000000042", "run_date": "2026-02-11", "start_time": "2026-02-11T16:11:00+00:00", "end_time": "2026-02-11T16:45:27+00:00", "distance_km": 6.54, "duration_seconds": 2067, "avg_pace_min_per_km": 5.27, "flip_count": 11, "flip_points": 11, "team_at_run": "blue", "cv": 11.9},
    {"id": "6ac748d5-c5d1-4a61-bf31-30dd8b04e349", "user_id": "aaaaaaaa-0043-0043-0043-000000000043", "run_date": "2026-02-11", "start_time": "2026-02-11T08:07:00+00:00", "end_time": "2026-02-11T09:01:10+00:00", "distance_km": 9.26, "duration_seconds": 3250, "avg_pace_min_per_km": 5.85, "flip_count": 15, "flip_points": 15, "team_at_run": "blue", "cv": 6.0},
    {"id": "f9dd327e-5dcf-4a26-baec-d1c6431a5ca6", "user_id": "aaaaaaaa-0045-0045-0045-000000000045", "run_date": "2026-02-11", "start_time": "2026-02-11T06:37:00+00:00", "end_time": "2026-02-11T07:26:03+00:00", "distance_km": 8.43, "duration_seconds": 2943, "avg_pace_min_per_km": 5.82, "flip_count": 9, "flip_points": 9, "team_at_run": "blue", "cv": 6.3},
    {"id": "337bf90e-bf51-4ae9-a95c-36a149bf4503", "user_id": "aaaaaaaa-0047-0047-0047-000000000047", "run_date": "2026-02-11", "start_time": "2026-02-11T16:01:00+00:00", "end_time": "2026-02-11T16:38:44+00:00", "distance_km": 6.95, "duration_seconds": 2264, "avg_pace_min_per_km": 5.43, "flip_count": 3, "flip_points": 3, "team_at_run": "blue", "cv": 14.5},
    {"id": "8ffa596a-80e7-4180-a6b5-7eb2a4da00fa", "user_id": "aaaaaaaa-0048-0048-0048-000000000048", "run_date": "2026-02-11", "start_time": "2026-02-11T18:34:00+00:00", "end_time": "2026-02-11T19:15:57+00:00", "distance_km": 6.9, "duration_seconds": 2517, "avg_pace_min_per_km": 6.08, "flip_count": 4, "flip_points": 4, "team_at_run": "blue", "cv": 12.6},
    {"id": "48552241-ea8b-451b-9aa3-2bbfce3d2d19", "user_id": "aaaaaaaa-0054-0054-0054-000000000054", "run_date": "2026-02-11", "start_time": "2026-02-11T13:03:00+00:00", "end_time": "2026-02-11T13:39:56+00:00", "distance_km": 5.9, "duration_seconds": 2216, "avg_pace_min_per_km": 6.26, "flip_count": 7, "flip_points": 7, "team_at_run": "blue", "cv": 13.5},
    {"id": "7564d7ca-caaf-46e9-b17f-0a0c9bf09b3c", "user_id": "aaaaaaaa-0055-0055-0055-000000000055", "run_date": "2026-02-11", "start_time": "2026-02-11T14:56:00+00:00", "end_time": "2026-02-11T15:34:11+00:00", "distance_km": 5.77, "duration_seconds": 2291, "avg_pace_min_per_km": 6.62, "flip_count": 2, "flip_points": 2, "team_at_run": "blue", "cv": 18.6},
    {"id": "c97b3972-d9d7-4009-81db-f41c29ec62e1", "user_id": "aaaaaaaa-0061-0061-0061-000000000061", "run_date": "2026-02-11", "start_time": "2026-02-11T09:53:00+00:00", "end_time": "2026-02-11T10:09:47+00:00", "distance_km": 2.41, "duration_seconds": 1007, "avg_pace_min_per_km": 6.97, "flip_count": 3, "flip_points": 3, "team_at_run": "blue", "cv": 21.5},
    {"id": "b001686d-8622-4929-8ce7-55074e80b483", "user_id": "aaaaaaaa-0065-0065-0065-000000000065", "run_date": "2026-02-11", "start_time": "2026-02-11T10:58:00+00:00", "end_time": "2026-02-11T11:35:41+00:00", "distance_km": 5.4, "duration_seconds": 2261, "avg_pace_min_per_km": 6.98, "flip_count": 2, "flip_points": 2, "team_at_run": "blue", "cv": 10.4},
    {"id": "1e9af057-ee80-4096-b122-a7a97bf0255a", "user_id": "aaaaaaaa-0067-0067-0067-000000000067", "run_date": "2026-02-11", "start_time": "2026-02-11T20:48:00+00:00", "end_time": "2026-02-11T21:25:45+00:00", "distance_km": 5.81, "duration_seconds": 2265, "avg_pace_min_per_km": 6.5, "flip_count": 7, "flip_points": 7, "team_at_run": "blue", "cv": 23.1},
    {"id": "2f3a4f2b-4054-4bd7-9f75-a84c356a16a5", "user_id": "aaaaaaaa-0070-0070-0070-000000000070", "run_date": "2026-02-11", "start_time": "2026-02-11T18:21:00+00:00", "end_time": "2026-02-11T18:45:46+00:00", "distance_km": 3.45, "duration_seconds": 1486, "avg_pace_min_per_km": 7.18, "flip_count": 2, "flip_points": 2, "team_at_run": "blue", "cv": 24.8},
    {"id": "e2c8c192-3573-4a56-a97b-0c1c8c349677", "user_id": "aaaaaaaa-0072-0072-0072-000000000072", "run_date": "2026-02-11", "start_time": "2026-02-11T19:19:00+00:00", "end_time": "2026-02-11T19:35:36+00:00", "distance_km": 2.58, "duration_seconds": 996, "avg_pace_min_per_km": 6.44, "flip_count": 1, "flip_points": 1, "team_at_run": "blue", "cv": 21.1},
    {"id": "5ee9a79a-263f-47c4-9ad1-fe0ffadd3584", "user_id": "aaaaaaaa-0074-0074-0074-000000000074", "run_date": "2026-02-11", "start_time": "2026-02-11T19:24:00+00:00", "end_time": "2026-02-11T19:43:39+00:00", "distance_km": 3.16, "duration_seconds": 1179, "avg_pace_min_per_km": 6.22, "flip_count": 3, "flip_points": 3, "team_at_run": "blue", "cv": 21.7},
    {"id": "2546af93-9e95-42f2-bf78-da61726c5b35", "user_id": "aaaaaaaa-0083-0083-0083-000000000083", "run_date": "2026-02-11", "start_time": "2026-02-11T12:23:00+00:00", "end_time": "2026-02-11T13:00:17+00:00", "distance_km": 5.06, "duration_seconds": 2237, "avg_pace_min_per_km": 7.37, "flip_count": 10, "flip_points": 10, "team_at_run": "purple", "cv": 22.6},
    {"id": "5321c17f-4bd3-4b6e-9423-d3a03dee4a72", "user_id": "aaaaaaaa-0086-0086-0086-000000000086", "run_date": "2026-02-11", "start_time": "2026-02-11T06:36:00+00:00", "end_time": "2026-02-11T07:00:20+00:00", "distance_km": 3.22, "duration_seconds": 1460, "avg_pace_min_per_km": 7.56, "flip_count": 6, "flip_points": 6, "team_at_run": "purple", "cv": 15.6},
]
ok = post("run_history", runs, upsert=True)
print(f"  run_history: {'OK' if ok else 'FAILED'} ({len(runs)} rows)")

# ============================================================
# 2. UPSERT HEXES (146 hexes - ON CONFLICT UPDATE)
# ============================================================
print("\n=== Upserting hexes (146 hexes) ===")

# Read hex_teams from sim state
with open("test_simulation/.sim_state.json") as f:
    state = json.load(f)

hexes = [{"id": hex_id, "last_runner_team": team} for hex_id, team in state["hex_teams"].items()]
ok = post("hexes", hexes, upsert=True)
print(f"  hexes: {'OK' if ok else 'FAILED'} ({len(hexes)} rows)")

# ============================================================
# 3. UPDATE USER SEASON STATS (45 runners)
# ============================================================
print("\n=== Updating user season stats ===")

user_updates = [
    ("aaaaaaaa-0001-0001-0001-000000000001", 23, 13.74, 1, 5.49, 5.2),
    ("aaaaaaaa-0000-0000-0000-000000000000", 18, 9.36, 1, 5.47, 7.6),
    ("aaaaaaaa-0043-0043-0043-000000000043", 15, 9.26, 1, 5.85, 6.0),
    ("aaaaaaaa-0041-0041-0041-000000000041", 13, 5.77, 1, 5.44, 5.2),
    ("aaaaaaaa-0002-0002-0002-000000000002", 11, 12.59, 1, 4.54, 4.7),
    ("aaaaaaaa-0042-0042-0042-000000000042", 11, 6.54, 1, 5.27, 11.9),
    ("aaaaaaaa-0083-0083-0083-000000000083", 10, 5.06, 1, 7.37, 22.6),
    ("aaaaaaaa-0003-0003-0003-000000000003", 9, 12.32, 1, 4.64, 6.7),
    ("aaaaaaaa-0045-0045-0045-000000000045", 9, 8.43, 1, 5.82, 6.3),
    ("aaaaaaaa-0054-0054-0054-000000000054", 7, 5.9, 1, 6.26, 13.5),
    ("aaaaaaaa-0067-0067-0067-000000000067", 7, 5.81, 1, 6.5, 23.1),
    ("aaaaaaaa-0006-0006-0006-000000000006", 6, 14.42, 1, 4.69, 6.4),
    ("aaaaaaaa-0007-0007-0007-000000000007", 6, 11.92, 1, 5.33, 3.6),
    ("aaaaaaaa-0086-0086-0086-000000000086", 6, 3.22, 1, 7.56, 15.6),
    ("aaaaaaaa-0004-0004-0004-000000000004", 4, 11.72, 1, 5.49, 4.5),
    ("aaaaaaaa-0008-0008-0008-000000000008", 4, 10.9, 1, 5.18, 7.4),
    ("aaaaaaaa-0009-0009-0009-000000000009", 4, 9.92, 1, 4.72, 7.2),
    ("aaaaaaaa-0019-0019-0019-000000000019", 4, 9.87, 1, 6.27, 9.6),
    ("aaaaaaaa-0026-0026-0026-000000000026", 4, 6.44, 1, 6.0, 9.0),
    ("aaaaaaaa-0048-0048-0048-000000000048", 4, 6.9, 1, 6.08, 12.6),
    ("aaaaaaaa-0010-0010-0010-000000000010", 3, 8.55, 1, 5.6, 14.0),
    ("aaaaaaaa-0011-0011-0011-000000000011", 3, 5.02, 1, 5.99, 12.2),
    ("aaaaaaaa-0020-0020-0020-000000000020", 3, 9.17, 1, 5.04, 9.3),
    ("aaaaaaaa-0047-0047-0047-000000000047", 3, 6.95, 1, 5.43, 14.5),
    ("aaaaaaaa-0061-0061-0061-000000000061", 3, 2.41, 1, 6.97, 21.5),
    ("aaaaaaaa-0074-0074-0074-000000000074", 3, 3.16, 1, 6.22, 21.7),
    ("aaaaaaaa-0012-0012-0012-000000000012", 2, 8.25, 1, 5.27, 11.7),
    ("aaaaaaaa-0022-0022-0022-000000000022", 2, 7.82, 1, 5.1, 9.1),
    ("aaaaaaaa-0024-0024-0024-000000000024", 2, 9.13, 1, 5.14, 8.6),
    ("aaaaaaaa-0033-0033-0033-000000000033", 2, 9.32, 1, 5.17, 5.9),
    ("aaaaaaaa-0034-0034-0034-000000000034", 2, 9.71, 1, 5.5, 14.5),
    ("aaaaaaaa-0035-0035-0035-000000000035", 2, 7.83, 1, 5.91, 12.2),
    ("aaaaaaaa-0036-0036-0036-000000000036", 2, 9.47, 1, 5.53, 9.1),
    ("aaaaaaaa-0037-0037-0037-000000000037", 2, 8.96, 1, 5.84, 14.6),
    ("aaaaaaaa-0055-0055-0055-000000000055", 2, 5.77, 1, 6.62, 18.6),
    ("aaaaaaaa-0065-0065-0065-000000000065", 2, 5.4, 1, 6.98, 10.4),
    ("aaaaaaaa-0070-0070-0070-000000000070", 2, 3.45, 1, 7.18, 24.8),
    ("aaaaaaaa-0016-0016-0016-000000000016", 1, 6.38, 1, 6.29, 7.9),
    ("aaaaaaaa-0018-0018-0018-000000000018", 1, 6.88, 1, 5.83, 10.4),
    ("aaaaaaaa-0023-0023-0023-000000000023", 1, 6.46, 1, 5.11, 5.8),
    ("aaaaaaaa-0032-0032-0032-000000000032", 1, 5.76, 1, 5.81, 7.3),
    ("aaaaaaaa-0039-0039-0039-000000000039", 1, 8.66, 1, 6.42, 8.0),
    ("aaaaaaaa-0072-0072-0072-000000000072", 1, 2.58, 1, 6.44, 21.1),
    ("aaaaaaaa-0021-0021-0021-000000000021", 0, 7.4, 1, 6.02, 6.5),
    ("aaaaaaaa-0029-0029-0029-000000000029", 0, 6.33, 1, 5.53, 14.2),
]

ok_count = 0
fail_count = 0
for uid, pts, dist, runs, pace, cv in user_updates:
    data = {
        "season_points": pts,
        "total_distance_km": dist,
        "total_runs": runs,
        "avg_pace_min_per_km": pace,
        "avg_cv": cv,
    }
    if patch("users", f"id=eq.{uid}", data):
        ok_count += 1
    else:
        fail_count += 1

print(f"  users: {ok_count} OK, {fail_count} FAILED (out of {len(user_updates)})")

# ============================================================
# 4. VERIFY
# ============================================================
print("\n=== Verification ===")

# Check hex count
resp = requests.get(
    f"{SUPABASE_URL}/rest/v1/hexes?select=id",
    headers={**HEADERS, "Prefer": "count=exact", "Range": "0-0"},
)
hex_count = resp.headers.get("Content-Range", "?")
print(f"  Hexes: {hex_count}")

# Check run_history for 2026-02-11
resp = requests.get(
    f"{SUPABASE_URL}/rest/v1/run_history?run_date=eq.2026-02-11&select=id",
    headers={**HEADERS, "Prefer": "count=exact", "Range": "0-0"},
)
run_count = resp.headers.get("Content-Range", "?")
print(f"  Runs (2026-02-11): {run_count}")

# Check hex dominance
resp = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/get_hex_dominance",
    headers=HEADERS,
    json={"p_city_hex": None},
)
print(f"  Hex dominance: {resp.json()}")

# Check top users
resp = requests.get(
    f"{SUPABASE_URL}/rest/v1/users?select=name,team,season_points&order=season_points.desc&limit=10&id=like.aaaaaaaa-%25",
    headers=HEADERS,
)
print(f"  Top 10 sim users: {json.dumps(resp.json(), indent=2)}")

print("\n=== DONE ===")
