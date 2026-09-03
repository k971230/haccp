/**
 * DocCycleServiceAlarmTest — 마감 임박 알림 배치가 휴면 기준을 SP 로 넘기는지.
 *
 * 개발자: 박승우
 * 일자: 2026-08-28
 * 코멘트:
 *   1) 알림을 만드는 곳은 이제 여기 하나다 — 일일 배치(sp_tbl_schedule_task_generate_c_000)에서
 *      알림 INSERT 를 걷어냈다. 이 경로가 막히면 알림이 아무 데서도 안 생긴다
 *   2) 휴면 날수를 안 넘기면 SP 가 기본 NULL 로 받아 **거르기가 통째로 꺼진다** —
 *      아무도 안 쓰는 업체에도 예정일 수만큼 계속 쌓인다. 값이 실제로 실려 가는지 고정한다
 *   3) DB·Spring 없이 매퍼를 가짜로 세워 넘기는 값만 본다
 *
 * PIPELINE[HB99] 문서 마감 알림 스케줄러
 */
package com.haccp.docs.sch;

import static org.mockito.Mockito.verify;

import com.haccp.sys.logs.auditlog.AuditWriter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class DocCycleServiceAlarmTest {

    @Mock
    private DocCycleMapper mapper;

    @Mock
    private AuditWriter auditWriter;

    @InjectMocks
    private DocCycleService service;

    /** 설정한 휴면 날수가 그대로 SP 로 간다 — 안 가면 거르기가 꺼진 채 돈다. */
    @Test
    void sendTaskAlarmsPassesDormantDays() {
        ReflectionTestUtils.setField(service, "dormantDays", 30);

        service.sendTaskAlarms();

        verify(mapper).sendTaskAlarms("system", 30);
    }

    /**
     * 0 으로 두면 0 이 그대로 간다.
     *
     * SP 는 0 이하를 「안 거른다」로 읽는다. 그 뜻이 서비스에서 임의로 바뀌면
     * 운영에서 끈 줄 알았던 거르기가 켜져 있거나 그 반대가 된다.
     */
    @Test
    void zeroMeansNoFilterAndIsNotRewritten() {
        ReflectionTestUtils.setField(service, "dormantDays", 0);

        service.sendTaskAlarms();

        verify(mapper).sendTaskAlarms("system", 0);
    }
}
