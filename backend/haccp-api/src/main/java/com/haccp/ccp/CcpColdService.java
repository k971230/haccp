/**
 * CcpColdService — CCP 냉장보관 모니터링 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 목록·상세 조립·저장·삭제(validate-delete Double Check)를 담당한다
 *   2) 저장 시 행 목록을 JSON으로 직렬화해 SP 한 번에 넘긴다 — 부분 패치가 아니다
 *   3) coCd·userId는 LoginUserContext에서만 읽는다
 *
 * PIPELINE[HB71] Service
 * PIPELINE[HB69, HB19, HB51] 연관 모듈
 */
package com.haccp.ccp;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.ccp.dto.CcpLimitRow;
import com.haccp.ccp.dto.ColdMonitorDeleteItem;
import com.haccp.ccp.dto.ColdMonitorDetail;
import com.haccp.ccp.dto.ColdMonitorHeader;
import com.haccp.ccp.dto.ColdMonitorListRow;
import com.haccp.ccp.dto.ColdMonitorRowDto;
import com.haccp.ccp.dto.ColdMonitorSaveRequest;
import com.haccp.ccp.dto.ColdMonitorTempCell;
import com.haccp.ccp.dto.ColdMonitorTempJoinRow;
import com.haccp.ccp.dto.DocCorrectiveDto;
import com.haccp.ccp.dto.StorageRow;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.doc.DocCorrectiveSupport;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CcpColdService {

    private final CcpColdMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 작성일 구간으로 일지 목록을 조회한다
     *   2) 화면 조회 버튼에서 호출한다
     *   3) 성공 시 목록, 조건 없으면 회사 전체(최근순)
     */
    public List<ColdMonitorListRow> list(
            // 작성일 시작 YYYYMMDD — 공백 허용
            String fromDt,
            // 작성일 종료 YYYYMMDD — 공백 허용
            String toDt,
            // CCP 필터 — 공백이면 전체
            String ccpCd,
            // 문서번호 부분검색
            String docNo,
            // 작성자 ID·이름 부분검색
            String writer
    ) {
        return mapper.selectList(
                LoginUserContext.coCd(),
                nvl(fromDt),
                nvl(toDt),
                nvl(ccpCd),
                nvl(docNo),
                nvl(writer)
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 신규 양식 뼈대(보관고·한계기준) 또는 기존 문서 상세를 반환한다
     *   2) docIdx가 null/0이면(= 신규) header·rows는 비우고 마스터만 채운다
     *   3) 없는 문서면 BizException
     */
    public ColdMonitorDetail detail(
            // 문서 idx — 신규면 null
            Long docIdx
    ) {
        String coCd = LoginUserContext.coCd();
        ColdMonitorDetail out = new ColdMonitorDetail();
        // 냉장·냉동 보관고만 열로 쓴다 — 상온(ROOM)은 이 양식 범위 밖
        out.setStorages(mapper.selectStorages(coCd, "", "Y").stream()
                .filter(s -> "COLD".equals(s.getStorageType()) || "FROZEN".equals(s.getStorageType()))
                .collect(Collectors.toList()));
        out.setLimits(mapper.selectLimits(coCd, ""));

        if (docIdx == null || docIdx <= 0) {
            return out;
        }

        ColdMonitorHeader header = mapper.selectHeader(coCd, docIdx);
        if (header == null) {
            throw new BizException("문서를 찾을 수 없습니다.");
        }
        out.setHeader(header);
        out.setRows(loadRows(coCd, header.getHdrIdx()));
        out.setCorrective(correctiveSupport.load(coCd, docIdx));
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 일지를 저장하고 문서 idx를 반환한다
     *   2) 저장 버튼에서 호출한다 — 결재 잠금 문서는 SP가 막는다
     *   3) 성공 시 docIdx, 검증 실패 시 BizException
     */
    @Transactional
    public Long save(
            // 저장 요청 — 행 전체 교체
            ColdMonitorSaveRequest req
    ) {
        if (req.getRows() == null || req.getRows().isEmpty()) {
            throw new BizException("점검 행이 없습니다.");
        }
        String rowsJson = toRowsJson(req.getRows());
        Long docIdx = mapper.saveColdMonitor(
                LoginUserContext.coCd(),
                req.getDocIdx(),
                req.getBaseDt().trim(),
                req.getCcpCd().trim(),
                nvl(req.getMngUserId()),
                nvl(req.getMngNm()),
                rowsJson,
                LoginUserContext.userId()
        );
        if (docIdx == null || docIdx <= 0) {
            throw new BizException("저장에 실패했습니다.");
        }
        boolean hasNg = req.getRows().stream().anyMatch(r -> {
            String j = r.getJudgeCd() == null ? "" : r.getJudgeCd().trim().toUpperCase();
            return "F".equals(j) || "X".equals(j) || "NG".equals(j);
        });
        correctiveSupport.saveAutoIfNg(
                LoginUserContext.coCd(),
                docIdx,
                "html_sys_001",
                req.getBaseDt().trim(),
                req.getCorrective(),
                hasNg,
                LoginUserContext.userId()
        );
        return docIdx;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다(실제 삭제 없음)
     *   2) FE validateDeleteApi → 확인창 전에 호출한다
     *   3) 차단 시 BizException, 통과 시 void
     */
    public void validateDelete(
            // 삭제 키 배열
            List<ColdMonitorDeleteItem> keys
    ) {
        assertDeletable(LoginUserContext.coCd(), keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 임시·반려 문서를 삭제한다 — assertDeletable Double Check 후 SP 루프
     *   2) FE 삭제 확인 후 호출한다
     *   3) 성공 시 삭제 건수
     */
    @Transactional
    public int delete(
            // 삭제 키 배열
            List<ColdMonitorDeleteItem> keys
    ) {
        String coCd = LoginUserContext.coCd();
        assertDeletable(coCd, keys);
        String userId = LoginUserContext.userId();
        int n = 0;
        for (ColdMonitorDeleteItem key : keys) {
            mapper.deleteColdMonitor(coCd, key.getDocIdx(), userId);
            n++;
        }
        return n;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 키 정규화 + 결재 잠금 차단을 검사한다
     *   2) validateDelete·delete 양쪽에서 호출한다(Double Check)
     *   3) 문제 있으면 BizException
     */
    private void assertDeletable(
            // JWT 회사코드
            String coCd,
            // 삭제 키 목록
            List<ColdMonitorDeleteItem> keys
    ) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (ColdMonitorDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(mapper.selectDeleteBlocker(coCd, docIdxs), "문서");
    }

    /** 점검행 + 온도 셀 조립 */
    private List<ColdMonitorRowDto> loadRows(String coCd, Long hdrIdx) {
        List<ColdMonitorRowDto> rows = mapper.selectRows(coCd, hdrIdx);
        List<ColdMonitorTempJoinRow> temps = mapper.selectTempJoins(coCd, hdrIdx);
        Map<Long, List<ColdMonitorTempCell>> byRow = new HashMap<>();
        for (ColdMonitorTempJoinRow t : temps) {
            ColdMonitorTempCell cell = new ColdMonitorTempCell();
            cell.setStorageCd(t.getStorageCd());
            cell.setTempVal(t.getTempVal());
            cell.setJudgeCd(t.getJudgeCd());
            byRow.computeIfAbsent(t.getRowIdx(), k -> new ArrayList<>()).add(cell);
        }
        for (ColdMonitorRowDto row : rows) {
            row.setTemps(byRow.getOrDefault(row.getIdx(), new ArrayList<>()));
        }
        return rows;
    }

    /**
     * SP가 기대하는 camelCase JSON 배열로 직렬화한다.
     * Jackson 기본 필드명과 SP 키(rowSeq, temps.storageCd …)를 맞춘다.
     */
    private String toRowsJson(List<ColdMonitorRowDto> rows) {
        List<Map<String, Object>> payload = new ArrayList<>();
        for (ColdMonitorRowDto row : rows) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("rowSeq", row.getRowSeq());
            m.put("checkTime", row.getCheckTime());
            m.put("judgeCd", row.getJudgeCd());
            m.put("judgeModYn", row.getJudgeModYn() == null ? "N" : row.getJudgeModYn());
            m.put("checkerId", row.getCheckerId());
            m.put("checkerNm", row.getCheckerNm());
            // 작성자 — 비면 점검자와 동일 스냅샷
            m.put("writerId", row.getWriterId() != null ? row.getWriterId() : row.getCheckerId());
            m.put("writerNm", row.getWriterNm() != null ? row.getWriterNm() : row.getCheckerNm());
            // 서명은 보유여부만 넘긴다 — 실물은 SP가 tbl_user.sign_img에서 복사한다
            m.put("signYn", row.getSignYn());
            List<Map<String, Object>> temps = new ArrayList<>();
            if (row.getTemps() != null) {
                for (ColdMonitorTempCell t : row.getTemps()) {
                    Map<String, Object> tm = new LinkedHashMap<>();
                    tm.put("storageCd", t.getStorageCd());
                    tm.put("tempVal", t.getTempVal());
                    temps.add(tm);
                }
            }
            m.put("temps", temps);
            payload.add(m);
        }
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            throw new BizException("점검 행 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    private static String nvl(String s) {
        return s == null ? "" : s.trim();
    }
}
