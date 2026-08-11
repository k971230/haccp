// ============================================================
//  HACCP main 배포 파이프라인
//
//  개발자: 박승우
//  일자: 2026-08-10
//  코멘트:
//    1) main push → 빌드·이미지 push·DB migrate·배포·스모크까지 한 줄로 돌린다
//    2) 시크릿은 credentials() 만 사용한다 — 이 파일에 실값을 적지 않는다
//    3) disableConcurrentBuilds 로 compose up 충돌을 막는다
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
    // 호스트 apache 가 :80 점유 중이라 edge 는 8443 우회 — 표준 443 확보 후 포트 없이 되돌린다
    SMOKE_BASE_URL = 'https://180.71.58.87:8443'
    // self-signed 인증서라 curl -k 필요 — Let's Encrypt 전환 후 0 으로 둔다
    SMOKE_INSECURE = '1'
    // MSYS_NO_PATHCONV 는 전역으로 켜지 않는다 — Windows mvnw 클래스패스가 깨진다.
    // SSH 원격 경로만 migrate/deploy 스테이지에서 //home... + 지역 export 로 처리한다.
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
            ./mvnw -q -B -DskipITs test
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

    stage('DB migrate dry-run') {
      steps {
        sh 'bash scripts/db_migrate_dryrun.sh'
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

    stage('Prod DB migrate') {
      steps {
        withCredentials([sshUserPrivateKey(
            credentialsId: 'haccp-deploy-ssh-key',
            keyFileVariable: 'SSH_KEY',
            usernameVariable: 'SSH_USER')]) {
          sh '''
            set -euo pipefail
            # DEPLOY_HOST 가 user@host 형이면 호스트만 뽑고, 아니면 SSH_USER 를 쓴다
            HOST="$DEPLOY_HOST"
            USER="$SSH_USER"
            case "$DEPLOY_HOST" in
              *@*) USER="${DEPLOY_HOST%%@*}"; HOST="${DEPLOY_HOST#*@}" ;;
            esac
            # 리터럴 //home/... — env DEPLOY_DIR 을 쓰면 Git Bash 가 이미 Windows 경로로 바꿔 둔다
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
              "$USER@$HOST" \
              "cd //home/ubuntu/haccp && docker compose --env-file .env.docker -f docker-compose.prod.yml --profile migrate run --rm migrate"
          '''
        }
      }
    }

    stage('Deploy to prod') {
      steps {
        withCredentials([sshUserPrivateKey(
            credentialsId: 'haccp-deploy-ssh-key',
            keyFileVariable: 'SSH_KEY',
            usernameVariable: 'SSH_USER')]) {
          sh '''
            set -euo pipefail
            HOST="$DEPLOY_HOST"
            USER="$SSH_USER"
            case "$DEPLOY_HOST" in
              *@*) USER="${DEPLOY_HOST%%@*}"; HOST="${DEPLOY_HOST#*@}" ;;
            esac
            export SSH_KEY
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
          sh 'bash scripts/prod_smoke.sh "$SMOKE_BASE_URL"'
        }
      }
    }
  }

  post {
    success { echo "배포 성공: TAG=$TAG" }
    failure { echo "배포 실패: TAG=$TAG — 로그 확인 후 롤백은 런북 §12 절차" }
    always  { sh 'docker logout ghcr.io || true' }
  }
}
