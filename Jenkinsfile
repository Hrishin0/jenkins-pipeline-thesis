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
        stage('SonarCloud Analysis'){
            steps{
                withSonarQubeEnv('SonarQube'){ //The name of sonarcloud server set up in jenkins system config
                    bat "${env.SONAR_SCANNER_HOME}/bin/sonar-scanner"
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