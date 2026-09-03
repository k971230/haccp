/**
 * RhwpCliClient — 로컬 rhwp CLI로 HWP/HWPX를 PDF로 내보낸다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) APP_RHWP_CLI_PATH가 파일이면 그걸 쓰고, 없거나 비면 Docker(/opt/rhwp/rhwp)·tools/rhwp 를 찾는다
 *   2) Nanum 계열 fallback·font-path는 값이 있을 때만 붙여 폰트 없는 환경에서도 안전하게 동작한다
 *   3) 타임아웃·작업 디렉터리는 env만 사용하고 소스에 초·경로 매직 넘버를 두지 않는다
 *
 * PIPELINE[HB93] rhwp CLI PDF 변환
 * PIPELINE[HB85, HB86] 연관 모듈
 */
package com.haccp.docs.templates;

// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 프로세스 입출력·대기
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
// 역할 — 기동 로그
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
// 역할 — 설정 주입·컴포넌트
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** 서버 측 rhwp export-pdf 실행기 */
@Component
public class RhwpCliClient {

    // CLI 실패·타임아웃만 남기고 문서 경로는 업무 문구에 노출하지 않는다
    private static final Logger log = LoggerFactory.getLogger(RhwpCliClient.class);

    // rhwp.exe 또는 linux/rhwp 바이너리 절대·상대 경로 — 비우면 PDF 내보내기 불가
    private final String cliPath;
    // 프로세스 최대 대기 초 — httpFile(120s)보다 짧게 두어 프록시 Grace를 남긴다
    private final int timeoutSeconds;
    // 한컴 전용 폰트 탐색 경로 — 비우면 --font-path를 붙이지 않는다
    private final String fontPath;
    // 세리프 대체 글꼴명 — 비우거나 미설치여도 CLI가 WARN만 내고 계속할 수 있다
    private final String fallbackSerif;
    // 산세리프 대체 글꼴명 — NanumGothic 권장
    private final String fallbackSans;
    // 고정폭 대체 글꼴명 — 비우면 옵션 생략
    private final String fallbackMono;
    // CLI 임시 PDF 작업 루트 — APP_FILE_ROOT 하위가 아니면 시스템 temp를 쓴다
    private final Path workRoot;

    public RhwpCliClient(
            // APP_RHWP_CLI_PATH — 비우면 Docker /opt/rhwp/rhwp 또는 저장소 tools/rhwp 를 찾는다
            @Value("${app.rhwp.cli-path:}") String cliPath,
            // APP_RHWP_TIMEOUT_SECONDS — 변환 프로세스 대기 한도
            @Value("${app.rhwp.timeout-seconds}") int timeoutSeconds,
            // APP_RHWP_FONT_PATH — 선택적 폰트 디렉터리
            @Value("${app.rhwp.font-path:}") String fontPath,
            // APP_RHWP_FALLBACK_SERIF — 선택적 세리프 대체
            @Value("${app.rhwp.fallback-serif:}") String fallbackSerif,
            // APP_RHWP_FALLBACK_SANS — 선택적 산세리프 대체
            @Value("${app.rhwp.fallback-sans:}") String fallbackSans,
            // APP_RHWP_FALLBACK_MONO — 선택적 고정폭 대체
            @Value("${app.rhwp.fallback-mono:}") String fallbackMono,
            // APP_RHWP_WORK_DIR — 비우면 java.io.tmpdir/haccp-rhwp
            @Value("${app.rhwp.work-dir:}") String workDir
    ) {
        // 설정된 경로가 없거나 파일이 아닐 때(= 로컬·Docker env 가 서로 다름) 잘 알려진 위치를 본다
        this.cliPath = resolveCliPath(
                cliPath,
                Path.of(System.getProperty("user.dir", ".")).toAbsolutePath().normalize()
        );
        // 경로가 잡혔을 때(= 로컬 exe 또는 컨테이너 바이너리) 기동 로그에 절대경로를 남긴다
        if (!this.cliPath.isBlank()) {
            log.info("rhwp CLI: {}", this.cliPath);
        }
        this.timeoutSeconds = timeoutSeconds;
        this.fontPath = fontPath == null ? "" : fontPath.trim();
        this.fallbackSerif = fallbackSerif == null ? "" : fallbackSerif.trim();
        this.fallbackSans = fallbackSans == null ? "" : fallbackSans.trim();
        this.fallbackMono = fallbackMono == null ? "" : fallbackMono.trim();
        // workDir가 비었을 때(= 미설정) JVM 임시 디렉터리 아래 전용 폴더를 쓴다
        this.workRoot = workDir == null || workDir.isBlank()
                ? Path.of(System.getProperty("java.io.tmpdir"), "haccp-rhwp").toAbsolutePath().normalize()
                : Path.of(workDir).toAbsolutePath().normalize();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) env 경로가 실제 파일이면 그걸 우선한다 — Docker .env.docker 의 /opt/rhwp/rhwp
     *   2) 없거나 비면 컨테이너 기본 경로와 저장소 tools/rhwp (exe·확장자 없는 리눅스 바이너리)를 본다
     *   3) 후보가 하나도 없으면 원래 문자열을 그대로 돌려 호출 시점에 업무 오류를 낸다
     */
    static String resolveCliPath(
            // APP_RHWP_CLI_PATH 원문 — 공백이면 후보만 본다
            String configured,
            // JVM user.dir — IntelliJ 는 backend/haccp-api, mvnw 루트 실행이면 저장소 루트
            Path cwd
    ) {
        List<Path> candidates = new ArrayList<>();
        if (configured != null && !configured.isBlank()) {
            Path given = Path.of(configured.trim());
            // 상대경로일 때(= .env 의 ../../tools/...) 기동 디렉터리 기준으로 붙인다
            candidates.add(given.isAbsolute() ? given : cwd.resolve(given));
        }
        candidates.add(Path.of("/opt/rhwp/rhwp"));
        Path dir = cwd.toAbsolutePath().normalize();
        for (int i = 0; i < 6 && dir != null; i++) {
            candidates.add(dir.resolve("tools/rhwp/rhwp.exe"));
            candidates.add(dir.resolve("tools/rhwp/rhwp"));
            dir = dir.getParent();
        }
        for (Path c : candidates) {
            Path abs = c.toAbsolutePath().normalize();
            if (Files.isRegularFile(abs)) {
                return abs.toString();
            }
        }
        return configured == null ? "" : configured.trim();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 입력 HWP/HWPX를 PDF 파일로 변환해 호출자에게 임시 Path를 반환한다
     *   2) DocumentService.exportPdf가 HWP_SRC 원본을 PDF 첨부 전에 호출한다
     *   3) 성공 시 생성 PDF Path, 실패·타임아웃·미설정은 BizException
     */
    public Path exportPdf(
            // 테넌트 볼륨 안의 HWP_SRC 절대 경로 — 호출 전에 DocumentFileStorage.read로 검증한다
            Path sourceFile
    ) {
        if (cliPath.isBlank()) {
            throw new BizException("PDF 변환기가 설정되지 않았습니다. 관리자에게 문의하세요.");
        }
        Path cli = Path.of(cliPath).toAbsolutePath().normalize();
        if (!Files.isRegularFile(cli)) {
            throw new BizException("PDF 변환기를 찾을 수 없습니다. 관리자에게 문의하세요.");
        }
        if (sourceFile == null || !Files.isRegularFile(sourceFile)) {
            throw new BizException("PDF로 변환할 원본 파일을 찾을 수 없습니다.");
        }
        try {
            Files.createDirectories(workRoot);
            Path outDir = Files.createTempDirectory(workRoot, "pdf-");
            Path outFile = outDir.resolve("export.pdf");
            List<String> command = buildCommand(cli, sourceFile, outFile);
            Path logFile = outDir.resolve("rhwp.log");
            ProcessBuilder builder = new ProcessBuilder(command);
            builder.directory(outDir.toFile());
            // stdout/stderr를 파일로 보내 파이프 버퍼 포화 데드락을 피한다
            builder.redirectErrorStream(true);
            builder.redirectOutput(logFile.toFile());
            Process process = builder.start();
            // timeoutSeconds 초과일 때(= 대용량·폰트 탐색 지연) 프로세스를 끊고 업무 안내
            boolean finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS);
            String output = Files.isRegularFile(logFile)
                    ? Files.readString(logFile, StandardCharsets.UTF_8).trim()
                    : "";
            if (!finished) {
                process.destroyForcibly();
                cleanupQuietly(outDir);
                throw new BizException("PDF 변환 시간이 초과되었습니다. 잠시 후 다시 시도하세요.");
            }
            if (process.exitValue() != 0 || !Files.isRegularFile(outFile) || Files.size(outFile) <= 0) {
                log.warn("rhwp export-pdf 실패 exit={} output={}", process.exitValue(), shorten(output));
                cleanupQuietly(outDir);
                throw new BizException("PDF 변환에 실패했습니다.");
            }
            Files.deleteIfExists(logFile);
            return outFile;
        } catch (BizException e) {
            throw e;
        } catch (IOException | InterruptedException e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            throw new BizException("PDF 변환을 시작하지 못했습니다.");
        }
    }

    /** export-pdf 인자 목록 — 설정된 font/fallback만 선택적으로 추가한다 */
    private List<String> buildCommand(Path cli, Path sourceFile, Path outFile) {
        List<String> command = new ArrayList<>();
        command.add(cli.toString());
        command.add("export-pdf");
        command.add(sourceFile.toString());
        command.add("-o");
        command.add(outFile.toString());
        // fontPath가 실제 디렉터리일 때(= Nanum 등 로컬 폰트 배포) 탐색 경로를 전달한다
        if (!fontPath.isBlank() && Files.isDirectory(Path.of(fontPath))) {
            command.add("--font-path");
            command.add(fontPath);
        }
        // fallback 글꼴명이 있을 때(= 한컴 전용 폰트 대체) CLI 옵션을 붙인다
        if (!fallbackSerif.isBlank()) {
            command.add("--fallback-serif");
            command.add(fallbackSerif);
        }
        if (!fallbackSans.isBlank()) {
            command.add("--fallback-sans");
            command.add(fallbackSans);
        }
        if (!fallbackMono.isBlank()) {
            command.add("--fallback-mono");
            command.add(fallbackMono);
        }
        return command;
    }

    /** 실패 시 임시 작업 폴더를 남기지 않는다 */
    private void cleanupQuietly(Path outDir) {
        try {
            Files.deleteIfExists(outDir.resolve("export.pdf"));
            Files.deleteIfExists(outDir.resolve("rhwp.log"));
            Files.deleteIfExists(outDir);
        } catch (IOException ignored) {
            // 임시 잔여는 운영 디스크 정리 대상이다
        }
    }

    /** 로그에 남길 CLI 출력을 짧게 자른다 */
    private String shorten(String value) {
        if (value == null || value.isBlank()) return "";
        return value.length() <= 500 ? value : value.substring(0, 500);
    }
}
