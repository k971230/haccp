/**
 * healthCertApi — 보건증 등록 관리 API.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 회사·사용자는 JWT. 쿼리에 userId 를 실어도 서버가 행을 가른다
 *   2) 파일은 httpFile. 열람은 blob 을 새 탭으로. 캘린더는 days·holidays·workdays
 *   3) 삭제는 validate-delete → delete
 *
 * PIPELINE[HF214] 보건증 API
 */
import { http, httpFile } from "@/api/http";
import { apiOf } from "@/shell/tabRoute";
import type { CommonResponse } from "@/types/common";
import { camelizeRows } from "@/lib/camelKeys";

const BASE = apiOf("health-cert-management");

export type HealthCertCan = {
  mgrYn: string;
  adminYn: string;
  expireWindowDays: number;
  alarmDay1: number;
  alarmDay2: number;
  alarmDay3: number;
};
export type HealthCertEmp = {
  userId: string;
  userNm: string;
  deptCd?: string;
  deptNm?: string;
  expireDt?: string;
  histCnt?: number;
  _key?: string;
};
export type HealthCertHist = {
  idx?: number;
  userId?: string;
  regDt?: string;
  expireDt?: string;
  fileNm?: string;
  fileExt?: string;
  fileSize?: number;
  mimeType?: string;
  insNm?: string;
  _key?: string;
};
export type HealthCertMgr = { userId: string; userNm?: string; deptNm?: string };
export type HealthCertCal = { userId: string; userNm?: string; expireDt: string };
export type HealthCertCalHoliday = { ymd: string; name: string };
export type HealthCertCalMonth = {
  days: HealthCertCal[];
  holidays: HealthCertCalHoliday[];
  workdays: string[];
};

export async function fetchHealthCertCan() {
  const { data } = await http.get<CommonResponse<HealthCertCan>>(`${BASE}/can`);
  return data.data;
}

export async function listHealthCertEmps(expiringYn: string) {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(`${BASE}/emp/list`, {
    params: { expiringYn },
  });
  return camelizeRows<HealthCertEmp>(data.data);
}

export async function listHealthCertHist(userId: string) {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(`${BASE}/hist/list`, {
    params: { userId },
  });
  return camelizeRows<HealthCertHist>(data.data);
}

export async function uploadHealthCert(params: {
  userId: string;
  regDt: string;
  expireDt: string;
  file: File;
  maskedYn: string;
}) {
  const form = new FormData();
  form.append("file", params.file);
  await httpFile.post(`${BASE}/hist/upload`, form, {
    params: {
      userId: params.userId,
      regDt: params.regDt,
      expireDt: params.expireDt,
      maskedYn: params.maskedYn,
    },
  });
}

export async function viewHealthCert(idx: number) {
  const { data } = await httpFile.get<Blob>(`${BASE}/hist/${idx}/view`, { responseType: "blob" });
  return data;
}

export const validateDeleteHealthCert = (keys: { idx: number }[]) =>
  http.post(`${BASE}/hist/validate-delete`, keys);
export const deleteHealthCert = (keys: { idx: number }[]) =>
  http.post(`${BASE}/hist/delete`, keys);

export async function listHealthCertMgrs() {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(`${BASE}/mgr/list`);
  return camelizeRows<HealthCertMgr>(data.data);
}

export async function fetchHealthCertAlarm() {
  const { data } = await http.get<CommonResponse<HealthCertCan>>(`${BASE}/alarm`);
  return data.data;
}

export const saveHealthCertMgrs = (body: {
  userIds: string[];
  alarmDay1: number;
  alarmDay2: number;
  alarmDay3: number;
}) => http.put(`${BASE}/mgr/save`, body);

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 만료 사원·공휴일·영업일 전환을 한 번에 받는다
 *   2) 일정 캘린더 API 를 부르지 않는다
 *   3) from~to 는 6주 칸
 */
export async function listHealthCertCalendar(
  // 조회 시작일 YYYYMMDD
  fromYmd: string,
  // 조회 종료일 YYYYMMDD
  toYmd: string,
): Promise<HealthCertCalMonth> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>>>(`${BASE}/calendar`, {
    params: { fromYmd, toYmd },
  });
  const raw = (data.data ?? {}) as Record<string, unknown>;
  const daysRaw = Array.isArray(raw.days) ? raw.days : [];
  const holRaw = Array.isArray(raw.holidays) ? raw.holidays : [];
  const wdRaw = Array.isArray(raw.workdays) ? raw.workdays : [];
  return {
    days: camelizeRows<HealthCertCal>(daysRaw as Record<string, unknown>[]),
    holidays: camelizeRows<HealthCertCalHoliday>(holRaw as Record<string, unknown>[]),
    workdays: wdRaw.map((v) => String(v ?? "")).filter(Boolean),
  };
}
