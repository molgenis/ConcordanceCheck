node {
	stage ('Checkout') {
		checkout scm
	}
        stage ('Automated ConcordanceCheck test') {
        
        echo "Copy test from repo to molgenis home on Talos"
        sh "sudo scp nextflow/test/autotest.sh reception+talos:/home/umcg-molgenis/autotest.sh"
        
        echo "Login to Talos"
	    
	sh '''
            sudo ssh -tt reception+talos 'exec bash -l << 'ENDSSH'
		echo "Starting automated test"
		bash /home/umcg-molgenis/autotest.sh '''+env.CHANGE_ID+'''
ENDSSH'
        '''	
	}
}
