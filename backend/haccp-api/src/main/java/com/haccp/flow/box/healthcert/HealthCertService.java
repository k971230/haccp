/**
 * HealthCertService — 보건증 등록·열람·담당자·알림.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 이력·파일은 본인 또는 담당자만. ADMIN 이라고 타 직원 파일을 열지 않는다
 *   2) 열람·등록·삭제는 감사에 남긴다. 삭제는 담당자만
 *   3) 디스크 삭제는 커밋 뒤에만 — 롤백되면 실물이 남는다
 *
 * PIPELINE[HB148] 보건증 Service
 */
package com.haccp.flow.box.healthcert;

import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.sys.logs.auditlog.AuditWriter;
import com.haccp.flow.box.healthcert.dto.HealthCertAlarmRow;
import com.haccp.board.CalendarMapper;
import com.haccp.board.dto.CalendarHolidayRow;
import com.haccp.docs.sch.KoreanHolidayDates;
import com.haccp.flow.box.healthcert.dto.HealthCertCalMonth;
import com.haccp.flow.box.healthcert.dto.HealthCertCalRow;
import com.haccp.flow.box.healthcert.dto.HealthCertCanRow;
import com.haccp.flow.box.healthcert.dto.HealthCertDeleteItem;
import com.haccp.flow.box.healthcert.dto.HealthCertEmpRow;
import com.haccp.flow.box.healthcert.dto.HealthCertFileMeta;
import com.haccp.flow.box.healthcert.dto.HealthCertHistRow;
import com.haccp.flow.box.healthcert.dto.HealthCertMgrRow;
import com.haccp.flow.box.healthcert.dto.HealthCertMgrSaveRequest;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class HealthCertService {

    private static final String LABEL = "보건증 이력";
    private static final Set<String> ALLOWED_EXT = Set.of("pdf");
    private static final DateTimeFormatter YMD = DateTimeFormatter.BASIC_ISO_DATE;

    private final HealthCertMapper mapper;
    private final HealthCertFileStorage storage;
    private final AuditWriter auditWriter;
    private final CalendarMapper calendarMapper;

    @Value("${app.hr.retention-days:730}")
    private int retentionDays;

    public HealthCertCanRow can() {
        return mapper.selectCan(LoginUserContext.coCd(), LoginUserContext.userId());
    }

    public List<HealthCertEmpRow> listEmps(String expiringYn) {
        return mapper.selectEmps(LoginUserContext.coCd(), LoginUserContext.userId(),
                text(expiringYn).isEmpty() ? "N" : text(expiringYn));
    }

    public List<HealthCertHistRow> listHist(String userId) {
        String target = text(userId);
        if (target.isEmpty()) {
            throw new BizException("사원을 선택하세요.");
        }
        List<HealthCertHistRow> rows = mapper.selectHist(
                LoginUserContext.coCd(), LoginUserContext.userId(), target);
        return rows;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) 파일을 HrDocs 에 쓴 뒤 SP 로 이력을 넣는다
     *   2) SP 가 실패하면 방금 쓴 파일을 지운다
     *   3) 확장자는 pdf 만. 가림 확인(maskedYn=Y) 없이 받지 않는다
     */
    @Transactional
    public void upload(String userId, String regDt, String expireDt, MultipartFile file, String maskedYn) {
        String target = text(userId);
        if (target.isEmpty()) {
            throw new BizException("사원을 선택하세요.");
        }
        if (!"Y".equals(text(maskedYn).toUpperCase(Locale.ROOT))) {
            throw new BizException("주민번호 뒷자리를 가린 사본만 업로드할 수 있습니다.");
        }
        assertAllowedFile(file);
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        HealthCertFileStorage.SavedFile saved = storage.save(coCd, file);
        try {
            String original = text(file.getOriginalFilename());
            String ext = extOf(original);
            mapper.insertHist(coCd, actor, target, text(regDt), text(expireDt),
                    original, saved.relativePath(), ext, file.getSize(), mimeOf(ext),
                    saved.wrappedDek(), saved.keyVersion());
            auditWriter.record("tbl_health_cert_hist", null, "I",
                    Map.of("userId", target, "expireDt", text(expireDt), "maskedYn", "Y"));
        } catch (RuntimeException e) {
            // INSERT 가 실패한 원인(e)을 남긴다. 실물 삭제가 또 터져도 원인이 가려지지 않게
            deleteQuietly(saved.relativePath());
            throw e;
        }
    }

    public HealthCertFile view(Long idx) {
        HealthCertFileMeta meta = requirePath(idx);
        byte[] bytes = storage.load(meta.getFilePath(), meta.getWrappedDek(), meta.getKeyVersion());
        String name = text(meta.getFileNm());
        if (name.isEmpty()) {
            name = text(meta.getFilePath());
            int slash = name.lastIndexOf('/');
            if (slash >= 0) name = name.substring(slash + 1);
        }
        String ext = text(meta.getFileExt());
        if (ext.isEmpty()) {
            ext = extOf(name);
        }
        auditWriter.record("tbl_health_cert_hist", meta.getIdx(), "VIEW",
                Map.of("userId", text(meta.getUserId()), "idx", meta.getIdx()));
        return new HealthCertFile(name, mimeOf(ext), bytes);
    }

    public void validateDelete(List<HealthCertDeleteItem> keys) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) Double Check 후 이력을 지운다
     *   2) 실물 삭제는 커밋 뒤 — 롤백 때 실물만 사라지지 않게
     *   3) 디스크 실패는 삼킨다. 남은 파일은 운영 정리
     */
    @Transactional
    public void delete(List<HealthCertDeleteItem> keys) {
        List<Long> idxs = assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        List<HealthCertFileMeta> metas = mapper.selectHistPaths(coCd, actor, idxs);
        if (metas.size() != idxs.size()) {
            throw new BizException("보건증 이력은 담당자만 삭제할 수 있습니다.");
        }
        for (HealthCertFileMeta meta : metas) {
            mapper.deleteHist(coCd, actor, meta.getIdx());
            auditWriter.record("tbl_health_cert_hist", meta.getIdx(), "D",
                    Map.of("userId", text(meta.getUserId()), "idx", meta.getIdx()));
        }
        deleteAfterCommit(metas.stream().map(HealthCertFileMeta::getFilePath).toList());
    }

    public List<HealthCertMgrRow> listMgrs() {
        assertCanAssign();
        return mapper.selectMgrs(LoginUserContext.coCd());
    }

    public HealthCertAlarmRow alarm() {
        assertCanAssign();
        return mapper.selectAlarm(LoginUserContext.coCd());
    }

    @Transactional
    public void saveMgrs(HealthCertMgrSaveRequest req) {
        if (req == null) {
            throw new BizException("저장할 담당자 정보가 없습니다.");
        }
        assertCanAssign();
        String coCd = LoginUserContext.coCd();
        String actor = LoginUserContext.userId();
        List<String> ids = req.getUserIds() == null ? List.of() : req.getUserIds().stream()
                .map(HealthCertService::text)
                .filter(s -> !s.isEmpty())
                .distinct()
                .toList();
        mapper.saveMgrs(coCd, actor, ids);
        mapper.saveAlarm(coCd, actor, req.getAlarmDay1(), req.getAlarmDay2(), req.getAlarmDay3());
        auditWriter.record("tbl_health_cert_mgr", null, "U",
                Map.of("userIds", ids,
                        "alarmDay1", String.valueOf(req.getAlarmDay1()),
                        "alarmDay2", String.valueOf(req.getAlarmDay2()),
                        "alarmDay3", String.valueOf(req.getAlarmDay3())));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) 만료 사원과 공휴일·영업일 전환을 한 응답으로 내린다
     *   2) 공휴일은 KoreanHolidayDates. 영업일은 CalendarMapper.selectWorkdays
     *   3) 일정 화면 API 를 타지 않는다
     */
    public HealthCertCalMonth calendar(
            // 조회 시작일 YYYYMMDD — 6주 칸 첫날
            String fromYmd,
            // 조회 종료일 YYYYMMDD — 6주 칸 마지막
            String toYmd
    ) {
        String from = text(fromYmd);
        String to = text(toYmd);
        String coCd = LoginUserContext.coCd();
        HealthCertCalMonth out = new HealthCertCalMonth();
        List<HealthCertCalRow> days = mapper.selectCalendar(coCd, LoginUserContext.userId(), from, to);
        out.setDays(days == null ? List.of() : days);
        try {
            LocalDate start = LocalDate.parse(from, YMD);
            LocalDate end = LocalDate.parse(to, YMD);
            List<CalendarHolidayRow> holidays = new ArrayList<>();
            for (LocalDate d = start; !d.isAfter(end); d = d.plusDays(1)) {
                if (!KoreanHolidayDates.ALL.contains(d)) continue;
                holidays.add(new CalendarHolidayRow(d.format(YMD), KoreanHolidayDates.nameOf(d)));
            }
            out.setHolidays(holidays);
        } catch (DateTimeParseException e) {
            throw new BizException("조회 기간이 올바르지 않습니다.");
        }
        List<String> workdays = calendarMapper.selectWorkdays(coCd, from, to);
        out.setWorkdays(workdays == null ? List.of() : workdays);
        return out;
    }

    public void sendAlarms(int dormantDays) {
        mapper.sendAlarms("system", dormantDays);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) 최신이 아닌 이력만, 만료일로부터 retentionDays 가 지난 행을 지운다
     *   2) 최신 1건은 만료돼도 남긴다 — 미갱신 증빙
     *   3) 크론이 부른다. JWT 없다
     */
    @Transactional
    public void purgeExpired() {
        if (retentionDays > 0) {
            List<HealthCertFileMeta> purged = mapper.purgeSuperseded(retentionDays);
            deleteAfterCommit(purged.stream().map(HealthCertFileMeta::getFilePath).toList());
        }
        rewrapStaleKeys();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) PREV 키가 있을 때만, 한 세대 전 행의 wrapped_dek 만 현재 키로 다시 감싼다
     *   2) 파일 바이트는 안 건드린다. UPDATE 는 co_cd+idx
     *   3) 크론이 부른다
     */
    public void rewrapStaleKeys() {
        if (!storage.canRewrap()) {
            return;
        }
        int from = storage.currentVersion() - 1;
        if (from < 1) {
            return;
        }
        List<HealthCertFileMeta> rows = mapper.selectRewrap(from);
        for (HealthCertFileMeta row : rows) {
            if (row.getCoCd() == null || row.getIdx() == null || text(row.getWrappedDek()).isEmpty()) {
                continue;
            }
            String next = storage.rewrapDek(row.getWrappedDek(), from);
            mapper.updateWrappedDek(row.getCoCd(), row.getIdx(), next, storage.currentVersion());
        }
    }

    private List<Long> assertDeletable(List<HealthCertDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 " + LABEL + " 행을 선택하세요.");
        HealthCertCanRow can = can();
        if (can == null || !"Y".equals(can.getMgrYn())) {
            throw new BizException("보건증 이력은 담당자만 삭제할 수 있습니다.");
        }
        List<Long> idxs = new ArrayList<>();
        for (HealthCertDeleteItem key : keys) {
            if (key == null) {
                throw new BizException("삭제할 " + LABEL + " 키가 올바르지 않습니다.");
            }
            idxs.add(DeleteValidation.requirePositive(
                    key.getIdx(), "삭제할 " + LABEL + " 키가 올바르지 않습니다."));
        }
        DeleteValidation.throwIfBlocked(
                mapper.selectHistDeleteBlocker(LoginUserContext.coCd(), LoginUserContext.userId(), idxs),
                LABEL);
        return idxs;
    }

    private HealthCertFileMeta requirePath(Long idx) {
        Long key = DeleteValidation.requirePositive(idx, "보건증 이력이 올바르지 않습니다.");
        List<HealthCertFileMeta> rows = mapper.selectHistPaths(
                LoginUserContext.coCd(), LoginUserContext.userId(), List.of(key));
        if (rows.isEmpty()) {
            throw new BizException("본인 또는 보건증 담당자만 열람할 수 있습니다.");
        }
        return rows.get(0);
    }

    private void assertCanAssign() {
        HealthCertCanRow can = can();
        if (can == null || !"Y".equals(can.getAdminYn())) {
            throw new BizException("관리자만 담당자를 지정할 수 있습니다.");
        }
    }

    private void assertAllowedFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException("보건증 파일을 선택하세요.");
        }
        String ext = extOf(text(file.getOriginalFilename()));
        if (!ALLOWED_EXT.contains(ext)) {
            throw new BizException("PDF 파일만 업로드할 수 있습니다.");
        }
    }

    private void deleteAfterCommit(List<String> paths) {
        List<String> targets = paths.stream()
                .filter(p -> p != null && !p.isBlank())
                .distinct()
                .toList();
        if (targets.isEmpty()) {
            return;
        }
        Runnable wipe = () -> targets.forEach(this::deleteQuietly);
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            wipe.run();
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                wipe.run();
            }
        });
    }

    private void deleteQuietly(String path) {
        try {
            storage.delete(path);
        } catch (RuntimeException ignored) {
            // 메타는 이미 지워졌다. 남은 파일은 운영 정리
        }
    }

    private static String extOf(String name) {
        int dot = name.lastIndexOf('.');
        return dot < 0 ? "" : name.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private static String mimeOf(String ext) {
        if ("pdf".equals(ext)) return "application/pdf";
        if ("png".equals(ext)) return "image/png";
        if ("jpg".equals(ext) || "jpeg".equals(ext)) return "image/jpeg";
        return "application/octet-stream";
    }

    private static String text(String value) {
        return value == null ? "" : value.trim();
    }

    public record HealthCertFile(String fileNm, String mimeType, byte[] content) {}
}
