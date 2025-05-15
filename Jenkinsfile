node {
	stage ('Checkout') {
		checkout scm
	}
        stage ('Automated ConcordanceCheck test') {
        
        echo "Copy test from repo to molgenis home on Hyperchicken"
        sh "sudo scp nextflow/test/autotest.sh portal+hyperchicken:/home/umcg-molgenis/autotest.sh"
        
        echo "Login to Hyperchicken"
	    
	sh '''
            sudo ssh -tt portal+hyperchicken 'exec bash -l << 'ENDSSH'
		echo "Starting automated test"
		bash /home/umcg-molgenis/autotest.sh '''+env.CHANGE_ID+'''
ENDSSH'
        '''	
	}
}
