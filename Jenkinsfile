pipeline {
  agent any

  environment {
    // Docker registry and image name. Override in Jenkins environment if needed.
    REGISTRY = "docker.io"
    IMAGE_NAME = "${env.DOCKER_IMAGE_NAME ?: 'veronika-crt/fastapi_docker'}"
    TAG = "${env.BUILD_NUMBER ?: 'local'}"
    // The Jenkins agent label that has Docker installed. Override in job config if different.
    DOCKER_AGENT_LABEL = "${env.DOCKER_AGENT_LABEL ?: 'docker'}"
  }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '10'))
    skipDefaultCheckout()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Setup Python & Install') {
      steps {
        // create venv and install runtime + test deps (pytest)
        sh 'python3 -m venv .venv'
        sh '. .venv/bin/activate && python -m pip install --upgrade pip setuptools wheel'
        sh '. .venv/bin/activate && pip install -r requirements.txt pytest'
      }
    }

    stage('Run Tests') {
      steps {
        // Run pytest and produce JUnit XML for Jenkins to consume. Failing tests will fail the build.
        sh "set -e; . .venv/bin/activate; mkdir -p tests/reports; pytest -q --junitxml=tests/reports/junit.xml"
      }
      post {
        always {
          archiveArtifacts artifacts: 'tests/reports/**', allowEmptyArchive: true
          // publish test results to the Jenkins test report tab
          junit allowEmptyResults: true, testResults: 'tests/reports/*.xml'
        }
      }
    }

    stage('Build Docker Image') {
      // run this stage on the same node as the pipeline (built-in node)
      steps {
        script {
          def fullImage = "${REGISTRY}/${IMAGE_NAME}:${TAG}"
          // diagnostic info to help debug agent/docker availability
          sh 'echo "Running on $(hostname); USER=$(whoami); PATH=$PATH"; which docker || true; docker --version || true; ls -l /var/run/docker.sock || true'
          // fail fast with a clear message if docker CLI/daemon are not available on the agent
          sh 'if ! command -v docker >/dev/null 2>&1; then echo "Docker CLI not found on agent"; exit 1; fi'
          sh "docker build -t ${fullImage} ."
          env.FULL_IMAGE = fullImage
        }
      }
    }

    stage('Push Image') {
      // push image using the same node (built-in) — ensure this node has docker access
      when {
        expression { return env.DOCKER_REGISTRY_USER != null }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-registry-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          // diagnostic info and check docker CLI availability
          sh 'echo "Running on $(hostname); USER=$(whoami); PATH=$PATH"; which docker || true; docker --version || true; ls -l /var/run/docker.sock || true'
          sh 'if ! command -v docker >/dev/null 2>&1; then echo "Docker CLI not found on agent"; exit 1; fi'
          // Use single-quoted Groovy strings concatenated with Groovy variables to avoid accidental GString expansion of shell $VARIABLES
          sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin ' + REGISTRY
          sh 'docker push ' + env.FULL_IMAGE
        }
      }
    }

    stage('Deploy (optional)') {
      // run deploy steps on a node with docker/ssh available; you can override label as needed
      agent { label "${DOCKER_AGENT_LABEL}" }
      when {
        expression { return env.DEPLOY_HOST != null }
      }
      steps {
        // Example: pull and restart container on remote host via SSH. Requires SSH credentials configured in Jenkins.
        withCredentials([sshUserPrivateKey(credentialsId: 'deploy-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
          // Use single-quoted groovy string concatenation so shell $ variables are evaluated at runtime inside the shell and FULL_IMAGE is injected from env
          sh 'ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@' + DEPLOY_HOST + ' ' + "'docker pull ${env.FULL_IMAGE} && docker stop fastapi_app || true && docker rm fastapi_app || true && docker run -d --name fastapi_app -p 80:80 ${env.FULL_IMAGE}'"
        }
      }
    }
  }

  post {
    success {
      echo "Build succeeded: ${env.FULL_IMAGE}"
    }
    failure {
      echo 'Build failed'
    }
  }
}
