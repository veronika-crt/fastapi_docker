pipeline {
  agent any

  environment {
    // Docker registry and image name. Override in Jenkins environment if needed.
    REGISTRY = "docker.io"
    IMAGE_NAME = "${env.DOCKER_IMAGE_NAME ?: 'veronika-crt/fastapi_docker'}"
    TAG = "${env.BUILD_NUMBER ?: 'local'}"
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
      steps {
        script {
          def fullImage = "${REGISTRY}/${IMAGE_NAME}:${TAG}"
          sh "docker build -t ${fullImage} ."
          env.FULL_IMAGE = fullImage
        }
      }
    }

    stage('Push Image') {
      when {
        expression { return env.DOCKER_REGISTRY_USER != null }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-registry-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          // Use double-quoted Groovy strings so ${REGISTRY} and ${FULL_IMAGE} are interpolated before shell runs.
          sh "echo \"$DOCKER_PASS\" | docker login -u \"$DOCKER_USER\" --password-stdin ${REGISTRY}"
          sh "docker push ${FULL_IMAGE}"
        }
      }
    }

    stage('Deploy (optional)') {
      when {
        expression { return env.DEPLOY_HOST != null }
      }
      steps {
        // Example: pull and restart container on remote host via SSH. Requires SSH credentials configured in Jenkins.
        withCredentials([sshUserPrivateKey(credentialsId: 'deploy-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
          sh "ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USER}@${DEPLOY_HOST} 'docker pull ${FULL_IMAGE} && docker stop fastapi_app || true && docker rm fastapi_app || true && docker run -d --name fastapi_app -p 80:80 ${FULL_IMAGE}'"
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
