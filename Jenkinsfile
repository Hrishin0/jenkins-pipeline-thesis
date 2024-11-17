pipeline {

    parameters {
        booleanParam(name: 'autoApprove', defaultValue: false, description: 'Automatically run apply after generating plan?')
    } 
    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        SONAR_SCANNER_HOME = tool name: 'Sonar' //The name in Jenkins pipeline config
    }

   agent  any
    stages {
        stage('checkout') {
            steps {
                 script{
                        dir("terraform")
                        {
                            git "https://github.com/Hrishin0/jenkins-pipeline-thesis.git"
                        }
                    }
                }
            }
        stage('Trivy Terraform Scan') {
            steps {
                script {
                    def trivyReport = 'trivy-main-tf-report.txt'
                    // Run the Trivy config scan
                    bat "trivy config --severity HIGH,CRITICAL --exit-code 1 --format table -o ${trivyReport} main.tf"
                }
            }
            post {
                always {
                    // Archive the report for visibility
                    archiveArtifacts artifacts: 'trivy-main-tf-report.txt', allowEmptyArchive: true
                }
            }
        }
        stage('SonarCloud Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') { // The name of the SonarCloud server set up in Jenkins system config
                    bat "${env.SONAR_SCANNER_HOME}/bin/sonar-scanner"
                }
                // Wait for the Quality Gate result. If qg has failed, pipeline should fail
                script {
                    def qg = waitForQualityGate()
                    if (qg.status != 'OK') {
                        error "Pipeline aborted due to Quality Gate failure: ${qg.status}"
                    }
                }
            }
        }
        stage('Plan') {
            steps {
                bat 'cd terraform && terraform init'
                bat 'cd terraform && terraform plan -out tfplan'
                bat 'cd terraform && terraform show -no-color tfplan > tfplan.txt'
            }
        }
        stage('Approval') {
           when {
               not {
                   equals expected: true, actual: params.autoApprove
               }
           }

           steps {
               script {
                    def plan = readFile 'terraform/tfplan.txt'
                    input message: "Do you want to apply the plan?",
                    parameters: [text(name: 'Plan', description: 'Please review the plan', defaultValue: plan)]
               }
           }
       }

        stage('Apply') {
            steps {
                bat 'cd terraform && terraform apply -input=false tfplan'
            }
        }
    }

  }