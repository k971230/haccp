// ============================================================
//  HACCP main 배포 파이프라인
//
//  개발자: 박승우
//  일자: 2026-09-07
//  코멘트:
//    1) 빌드·이미지 push·배포·스모크까지 한 줄로 돌린다. 누를 것은 Build Now 하나다
//    2) 시크릿은 credentials() 만 사용한다 — 이 파일에 실값을 적지 않는다
//    3) disableConcurrentBuilds 로 compose up 충돌을 막는다
//
//  ** DB 는 이 파이프라인이 건드리지 않는다 **
//    스키마 정본은 db_sasshaccp/ 7본이다(00_ddl → 01_sp → 02_seed →
//    03_code_seed → 05_form_seed → 06_company_seed → 07_company_forms).
//    스키마가 있으면 apply-all 이 00_ddl·02_seed 를 건너뛴다. 01_sp 는 항상 돈다.
//    운영 반영은 배포 담당이 따로 돌린다:
//      PGHOST=... PGUSER=... PGPASSWORD=*** bash db_sasshaccp/apply-all.sh
//    자동 적용을 넣지 않는 이유 — 스키마 변경은 되돌리기 어렵고,
//    배포와 같은 트랜잭션으로 묶을 수 없어 실패 시 반쪽 상태가 남는다.
//
//  필요한 Credentials (Jenkins > Credentials 에 미리 등록)
//    haccp-deploy-host    Secret text        user@host 또는 host
//    haccp-deploy-ssh-key SSH Username+Key   배포 서버 접속
//    haccp-registry-cred  Username+Password  ghcr.io push
//    haccp-smoke-user     Username+Password  배포 후 스모크 로그인
// ============================================================
pipeline {
  agent any

  options {
    disableConcurrentBuilds()
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  environment {
    REGISTRY    = 'ghcr.io/k971230'
    IMAGE_API   = "${REGISTRY}/haccp-api"
    IMAGE_WEB   = "${REGISTRY}/haccp-web"
    IMAGE_NGX   = "${REGISTRY}/haccp-nginx"
    TAG         = "1.0.${env.BUILD_NUMBER}"
    // sudo 없이 배포 계정 홈에 둔다 — /opt/haccp 는 root 소유 시 권한 문제로 막힌다
    DEPLOY_DIR  = '/home/ubuntu/haccp'
    // Secret text: user@host 또는 host 만 — deploy 스크립트가 USER/HOST 로 나눈다
    DEPLOY_HOST = credentials('haccp-deploy-host')
    // Apache Path 분기 — origin 만 (포트 없음). FE는 prod_smoke 의 SMOKE_WEB_PREFIX=/haccp
    SMOKE_BASE_URL = 'https://180.71.58.87'
    // Apache self-signed 이면 1 — 공인 인증서 전환 후 0
    SMOKE_INSECURE = '1'
    // Apache /haccp/ → edge. 루프백 직행 스모크만 빈 값으로 덮는다
    SMOKE_WEB_PREFIX = '/haccp'
    // MSYS_NO_PATHCONV 는 전역으로 켜지 않는다 — Windows mvnw 클래스패스가 깨진다.
    // SSH 원격 경로는 deploy 스테이지에서 //home... + 지역 export 로 처리한다.
  }

  triggers {
    githubPush()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git log -1 --oneline'
      }
    }

    stage('BE test & compile') {
      steps {
        dir('backend/haccp-api') {
          // Windows 에이전트에 깨진 MAVEN_HOME/M2_HOME 이 있으면 only-script mvnw 가 Launcher 를 못 찾는다
          sh '''
            set -euo pipefail
            unset MAVEN_HOME M2_HOME || true
            sed -i "s/\\r$//" mvnw
            chmod +x mvnw
            # clean 을 반드시 붙인다 — Jenkins 워크스페이스는 빌드마다 지워지지 않는다.
            # 시험 클래스를 옮기거나 이름을 바꾸면 target/test-classes 에 **옛 .class 가 남고**,
            # surefire 가 그것까지 찾아 돌린다. 리포트 건수가 소스보다 많아지고,
            # 이미 없는 시험이 통과했다고 나온다. 실제로 로컬 104건이 Jenkins 에서 117건으로 찍혔다.
            ./mvnw -q -B -DskipITs clean test
            ./mvnw -q -B -DskipTests package
          '''
        }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'backend/haccp-api/target/surefire-reports/*.xml'
        }
      }
    }

    stage('FE test & build') {
      steps {
        dir('frontend/haccp-web') {
          sh 'npm ci --no-audit --no-fund'
          sh 'npx tsc --noEmit'
          sh 'npm run lint'
          sh 'npm test -- --run'
          sh 'npm run build'
        }
      }
    }

    stage('Build images') {
      steps {
        withCredentials([usernamePassword(
            credentialsId: 'haccp-registry-cred',
            usernameVariable: 'REG_USER',
            passwordVariable: 'REG_PASS')]) {
          sh 'echo "$REG_PASS" | docker login ghcr.io -u "$REG_USER" --password-stdin'
          sh 'bash scripts/build_images.sh "$TAG"'
        }
      }
    }

    stage('Push images') {
      steps {
        sh '''
          docker push $IMAGE_API:$TAG
          docker push $IMAGE_WEB:$TAG
          docker push $IMAGE_NGX:$TAG
          docker tag $IMAGE_API:$TAG $IMAGE_API:latest && docker push $IMAGE_API:latest
          docker tag $IMAGE_WEB:$TAG $IMAGE_WEB:latest && docker push $IMAGE_WEB:latest
          docker tag $IMAGE_NGX:$TAG $IMAGE_NGX:latest && docker push $IMAGE_NGX:latest
        '''
      }
    }

    stage('Deploy to prod') {
      steps {
        // SSH 키 + GHCR — 원격 pull 이 private 패키지라 서버 쪽 login 이 필요하다
        withCredentials([
            sshUserPrivateKey(
              credentialsId: 'haccp-deploy-ssh-key',
              keyFileVariable: 'SSH_KEY',
              usernameVariable: 'SSH_USER'),
            usernamePassword(
              credentialsId: 'haccp-registry-cred',
              usernameVariable: 'REG_USER',
              passwordVariable: 'REG_PASS')
        ]) {
          sh '''
            set -euo pipefail
            HOST="$DEPLOY_HOST"
            USER="$SSH_USER"
            case "$DEPLOY_HOST" in
              *@*) USER="${DEPLOY_HOST%%@*}"; HOST="${DEPLOY_HOST#*@}" ;;
            esac
            export SSH_KEY REG_USER REG_PASS
            # 세 번째 인자도 리터럴 //home — DEPLOY_DIR env 치환을 피한다
            bash scripts/deploy_remote.sh "$USER" "$HOST" //home/ubuntu/haccp "$TAG"
          '''
        }
      }
    }

    stage('Prod smoke') {
      steps {
        withCredentials([usernamePassword(
            credentialsId: 'haccp-smoke-user',
            usernameVariable: 'SMOKE_USER',
            passwordVariable: 'SMOKE_PASS')]) {
          // Git Bash 가 SMOKE_WEB_PREFIX=/haccp 를 /C:/Program Files/Git/haccp 로 깨뜨린다
          sh '''
            export MSYS_NO_PATHCONV=1
            bash scripts/prod_smoke.sh "$SMOKE_BASE_URL"
          '''
        }
      }
    }
  }

  post {
    success { echo "배포 성공: TAG=$TAG" }
    failure { echo "배포 실패: TAG=$TAG — 로그 확인 후 롤백은 DEPLOY.md §5 되돌리기" }
    always  { sh 'docker logout ghcr.io || true' }
  }
}
