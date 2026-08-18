/**
 * DocCycleMapper — 문서주기관리 MyBatis 매퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 85_migrate_doc_cycle.sql + 86_migrate_doc_cycle_form_use_yn.sql 의 SP만 호출한다
 *   2) 조회는 FUNCTION(map), 저장·삭제·재생성은 PROCEDURE CALL이다
 *   3) coCd·userId는 Service가 JWT에서만 채워 전달한다 (배치는 'system')
 *
 * PIPELINE[HB99] 문서주기 MyBatis 매퍼
 * PIPELINE[HB94, HB98] 연관 모듈
 */
package com.haccp.hwp.doccycle;

// 역할 — 목록·행 타입
import java.util.List;
import java.util.Map;
// 역할 — MyBatis 매퍼 표식·이름 바인딩
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface DocCycleMapper {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 좌측 양식 목록 — 사용여부 검색 + 구분 + 주기 등록여부
     *   2) 화면 진입·조회 버튼에서 호출한다
     *   3) 성공 시 tmpl_cd·tmpl_nm·form_ty·doc_kind·cycle_cd·rule_yn·use_yn 행 목록
     */
    List<Map<String, Object>> selectForms(
            // JWT 회사코드 — 자사 사용양식 범위
            @Param("coCd") String coCd,
            // 양식코드 검색어 — 공백이면 전체
            @Param("tmplCd") String tmplCd,
            // 양식명 검색어 — 공백이면 전체
            @Param("tmplNm") String tmplNm,
            // 사용여부 Y/N — 공백이면 전체
            @Param("useYn") String useYn
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 선택 양식의 주기 1건 + 반복 상세(details jsonb)를 조회한다
     *   2) 좌측 행 선택 시 우측 폼을 채우기 위해 호출한다
     *   3) 성공 시 1행, 주기 미설정이면 빈 목록
     */
    List<Map<String, Object>> selectCycle(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 좌측에서 선택한 양식코드
            @Param("tmplCd") String tmplCd
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 주기 1건을 업서트하고 반복 상세를 전량 교체한다
     *   2) 우측 폼 저장 버튼에서 호출한다
     *   3) 성공 시 void — 검증 실패는 SP RAISE(45000)로 업무 문구가 올라온다
     */
    void saveCycle(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // camelCase JSON 폼 1건 — tmplCd·baseDt·cycleCd·nonworkRule·dueTime·deptCd·userId·useYn·details[]
            @Param("payload") String payload,
            // JWT 작업자 ID — 감사 컬럼
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 주기·상세를 삭제하고 미래 미작성 예정일만 정리한다
     *   2) Service Double Check 뒤 호출한다
     *   3) 성공 시 void — 대상이 없으면 SP가 업무 예외를 던진다
     */
    void deleteCycle(
            // JWT 회사코드
            @Param("coCd") String coCd,
            // 삭제 대상 양식코드
            @Param("tmplCd") String tmplCd,
            // JWT 작업자 ID
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) CycleScheduleGenerator가 만든 예정일 배열로 tbl_schedule_task를 재생성한다
     *   2) 주기 저장 직후와 일일 배치에서 호출한다
     *   3) 성공 시 void — 규칙에서 빠진 미래 TODO는 지워지고 남은 행의 마감·알림시각이 맞춰진다
     */
    void regenerateTasks(
            // 회사코드 — 배치는 대상 회사, 화면은 JWT 회사
            @Param("coCd") String coCd,
            // 양식코드
            @Param("tmplCd") String tmplCd,
            // 예정일 JSON 배열 ["yyyyMMdd", …] — 비영업일 이동까지 끝난 최종 값
            @Param("dates") String dates,
            // 마감시각 HHMM — 공백이면 SP가 1800
            @Param("dueTime") String dueTime,
            // 담당 부서코드 — null 허용
            @Param("deptCd") String deptCd,
            // 담당자 ID — null 허용
            @Param("assignUserId") String assignUserId,
            // 마감 몇 분 전에 알릴지 — app.schedule.alarm-before-minutes
            @Param("alarmMinutes") Integer alarmMinutes,
            // 배치 또는 작업자 ID — 감사 컬럼
            @Param("userId") String userId
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 일일 배치가 다시 생성할 회사·양식 주기를 모두 읽는다
     *   2) 화면 조회와 달리 회사 전체가 대상이라 별도 쿼리를 둔다
     *   3) 성공 시 사용 중(use_yn=Y) 주기 행 + details jsonb 목록
     */
    List<Map<String, Object>> selectActiveCycles();

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 마감 임박 예정일의 알림을 적재하고 발송 플래그를 올린다
     *   2) DocumentAlarmScheduler가 주기적으로 호출한다
     *   3) 성공 시 void — 같은 예정일은 alarm_send_yn='Y'로 재발송되지 않는다
     */
    void sendTaskAlarms(
            // 배치 실행 주체 ID — 감사 로그용
            @Param("userId") String userId
    );
}
