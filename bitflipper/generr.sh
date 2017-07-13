#!/bin/bash


set -o errexit -o nounset -o pipefail -o errtrace -o posix

#first argument is executable binary which will have bits flipped, second argument is number of threads, following arguments are passed to the program

export OMP_NUM_THREADS=$2
origbin=$1

shift 2

#calculate offsets based on argument binary $1 == basebin
readelf -S $origbin > ELFFILE
init_off=$(grep ELFFILE -e ".text" | awk '{print $6}')  		#obtains offset of .text in the binary
init_offset=$((16#$init_off)) 						#converts to decimal base
text_size=$(grep ELFFILE -e ".text" -A 1 | awk '{print $1}' | tail -1 ) #obtains size of text 
end_text_size=$((16#$text_size))						#converts to decimal base
end_offset=$(echo "obase=10;ibase=10;$init_offset+$end_text_size" | bc)	#sums to get final bytes
echo $init_offset
echo $end_offset
./$origbin $@ > resultBASE	#obtains control output for comparison
rm ELFFILE	#clean up

# loop to generate silent errors
for i in $(eval echo "{$init_offset..$end_offset}");
do
        for k in `seq 0 7`;
        do
                ./dorep $origbin hackbin $i $k						#flip bit #k of byte #i in binary $1, output in binary "hackbin"
                chmod +x hackbin				
                timeout --preserve-status 10s ./hackbin $@ | tee resultFLIP	#generates output of execution with flipped bit. CAREFUL, syscalls with flipped bits can have very weird effects on the system
		ps=${PIPESTATUS[0]}							#pipe status of binary execution					
                echo "return code: $ps" | tee -a hackout		
                if [ $ps -eq 0 ]							#if return code is normal, i.e. OS did not detect anything unusual
                then
					aux=$(diff resultFLIP resultBASE | wc -l)
					#aux=$(grep UNSUCC resultFLIP) 				#use diff for regular benchmarks, grep for UNSUCCESSFULL on NAS parallel benchmarks
					if [ $aux -ne 0 ]
					then							#if there were differences in the outputs or grep caught UNSUCC, record silent error
						echo "$i $k" | tee -a interesting_errors
					fi	 
		fi
		rm hackbin				#clear previous binary
		rm resultFLIP				#clear previous output
	done
done

rm resultBASE								#clean up
awk '{print $1}' interesting_errors > $origbin_serror_BYTES 			#generates file with silent error BYTE in each line
awk '{print $2}' interesting_errors > $origbin_serror_BITS			#generates file with silent error BIT in each line


