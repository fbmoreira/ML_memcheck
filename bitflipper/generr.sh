#!/bin/bash


#receives 1 argument, executable binary which will have bits flipped


#calculate offsets based on argument binary $1 == basebin
readelf -S $1 > ELFFILE
init_off=$(grep ELFFILE -e ".text" | awk '{print $6}')  		#obtains offset of .text in the binary
init_offset=$((16#$init_off)) 						#converts to decimal base
text_size=$(grep ELFFILE -e ".text" -A 1 | awk '{print $1}' | tail -1 ) #obtains size of text 
end_text_size=$((16#$text_size))						#converts to decimal base
end_offset=$(echo "obase=10;ibase=10;$init_offset+$end_text_size" | bc)	#sums to get final bytes
echo $init_offset
echo $end_offset
./$1 ../../cbench/automotive_qsort_data/10.dat > resultBASE		#obtains control output for comparison
rm ELFFILE	#clean up

# loop to generate silent errors
for i in $(eval echo "{$init_offset..$end_offset}");
do
        for k in `seq 0 7`;
        do
                ./dorep $1 hackbin $i $k						#flip bit #k of byte #i in binary $1, output in binary "hackbin"
                chmod +x hackbin				
                ./hackbin ../../cbench/automotive_qsort_data/10.dat > resultFLIP	#generates output of execution with flipped bit. CAREFUL, syscalls with flipped bits can have very weird effects on the system
                ps=${PIPESTATUS[0]}					
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
awk '{print $1}' interesting_errors > $1_serror_BYTES 			#generates file with silent error BYTE in each line
awk '{print $2}' interesting_errors > $1_serror_BITS			#generates file with silent error BIT in each line


