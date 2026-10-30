

while true; do
	    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Start synchronizacji"

	        python3 l-github-gitlab-sync.py --workers 8 --apply

		    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Koniec synchronizacji"

		        sleep 100
		done
