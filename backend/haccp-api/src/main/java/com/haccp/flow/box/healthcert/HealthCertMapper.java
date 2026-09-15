/**
 * HealthCertMapper — 보건증 화면 SP 호출.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 행 통제는 SP 가 p_actor_id 로 한다
 *   2) coCd 는 Service 가 JWT 에서만 채운다
 *   3) 알림 발송 SP 는 배치가 부른다
 *
 * PIPELINE[HB149] 보건증 Mapper
 */
package com.haccp.flow.box.healthcert;

import com.haccp.common.validation.DeleteBlocker;
import com.haccp.flow.box.healthcert.dto.HealthCertAlarmRow;
import com.haccp.flow.box.healthcert.dto.HealthCertCalRow;
import com.haccp.flow.box.healthcert.dto.HealthCertCanRow;
import com.haccp.flow.box.healthcert.dto.HealthCertEmpRow;
import com.haccp.flow.box.healthcert.dto.HealthCertFileMeta;
import com.haccp.flow.box.healthcert.dto.HealthCertHistRow;
import com.haccp.flow.box.healthcert.dto.HealthCertMgrRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface HealthCertMapper {

    HealthCertCanRow selectCan(@Param("coCd") String coCd, @Param("actorId") String actorId);

    List<HealthCertEmpRow> selectEmps(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("expiringYn") String expiringYn);

    List<HealthCertHistRow> selectHist(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("userId") String userId);

    void insertHist(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("userId") String userId,
            @Param("regDt") String regDt,
            @Param("expireDt") String expireDt,
            @Param("fileNm") String fileNm,
            @Param("filePath") String filePath,
            @Param("fileExt") String fileExt,
            @Param("fileSize") Long fileSize,
            @Param("mimeType") String mimeType,
            @Param("wrappedDek") String wrappedDek,
            @Param("keyVersion") Integer keyVersion);

    List<HealthCertFileMeta> selectRewrap(@Param("fromVersion") Integer fromVersion);

    void updateWrappedDek(
            @Param("coCd") String coCd,
            @Param("idx") Long idx,
            @Param("wrappedDek") String wrappedDek,
            @Param("keyVersion") Integer keyVersion);

    DeleteBlocker selectHistDeleteBlocker(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("idxs") List<Long> idxs);

    List<HealthCertFileMeta> selectHistPaths(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("idxs") List<Long> idxs);

    void deleteHist(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("idx") Long idx);

    List<HealthCertMgrRow> selectMgrs(@Param("coCd") String coCd);

    void saveMgrs(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("userIds") List<String> userIds);

    HealthCertAlarmRow selectAlarm(@Param("coCd") String coCd);

    void saveAlarm(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("alarmDay1") Integer alarmDay1,
            @Param("alarmDay2") Integer alarmDay2,
            @Param("alarmDay3") Integer alarmDay3);

    List<HealthCertCalRow> selectCalendar(
            @Param("coCd") String coCd,
            @Param("actorId") String actorId,
            @Param("fromYmd") String fromYmd,
            @Param("toYmd") String toYmd);

    void sendAlarms(@Param("actorId") String actorId, @Param("dormantDays") Integer dormantDays);

    List<HealthCertFileMeta> purgeSuperseded(@Param("retentionDays") Integer retentionDays);
}
