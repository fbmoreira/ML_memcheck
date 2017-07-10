#!/bin/bash

#array declarations
declare -a ARRAYBYTES
declare -a ARRAYBITS

objdump -d $1 > base_dump
echo "$1"

#read file with silent error bytes
ARRAYBYTES=( $(cat sample_serror_BYTES) )
#read file with silent error bits
ARRAYBITS=( $(cat sample_serror_BITS) )
errors=$(wc -l sample_serror_BYTES | awk '{print $1}')
errnum=$(echo "$errors - 1" | bc)
for k in $(eval echo "{0..$3}");		#get user-chosen number of executions from the possible silent errors
        do
		i=$((RANDOM % errnum))							#randomize a silent error
                ./dorep $1 hackbin ${ARRAYBYTES[$i]} ${ARRAYBITS[$i]}			#flip corresponding bit
                chmod +x hackbin
                echo "${ARRAYBYTES[$i]} ${ARRAYBITS[$i]}" | tee -a $2-sample_info.out

                #run
                ./run.sh ./hackbin
                echo "return code: ${PIPESTATUS[0]}" | tee -a $2-sample_info.out
		for it in {0..7};
			do
				mv mem_trace_$it.out $2-err_$k-thread-$it		# $2 is the user defined prefix for the trace files
		done
			
	
                #catch the instruction change - might be interesting to understand the silent error
                objdump -d hackbin > hack_dump
                echo "base instructions were\n" | tee -a $2-sample_info.out
                offhex=$(printf '%X' ${ARRAYBYTES[$i]})
                target=$(echo "obase=16; ibase=16; $offhex + 400000" | bc )
                grep {$target::-1} base_dump | tee -a $2-sample_info.out

                echo "changed instructions were\n" | tee -a $2-sample_info.out
                grep {$target::-1} hack_dump | tee -a $2-sample_info.out

                #cleanup
                rm hack_dump
                rm hackbin

done;


