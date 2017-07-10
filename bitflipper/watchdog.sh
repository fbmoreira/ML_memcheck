prevtime=$(date +%s)

prevsize=$(wc -l hackout  |  awk '{print $1}')		#number of lines in hackout translates to number of executions completed

while true; do

        ntime=$(date +%s)

        elapsed=`expr $ntime - $prevtime`		

        size=$(wc -l hackout  |  awk '{print $1}')

        if [ "$elapsed" -gt "$1" ]; then		#if 10s have passed
	
                if [ "$size" -eq "$prevsize" ]; then	#and if the number of executed completions has not changed (i.e. 10 seconds have passed and the same execution is still running)

                        killall hackbin -s 9;		#kill hanging executions

                        echo "FOUND $size"		

                        prevtime=$ntime			#prepare for next iteration	

                fi;

        fi;

        prevsize=$size					#prepare for next iteration

        sleep $1				#avoid busy wait

done


