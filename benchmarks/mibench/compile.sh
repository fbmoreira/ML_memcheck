

gcc -v

declare -a BMS_DIR=(
	"automotive/bitcount"
	"automotive/qsort"
	"automotive/susan"
	
	"consumer/jpeg/jpeg-6a/"
	
	"network/dijkstra"
	"network/patricia"
	
	"telecomm/CRC32"
	"telecomm/FFT"
	
	"security/sha")

for BM in ${BMS_DIR[@]}; do
	echo "Compiling BM in " ${BM}
	{
		cd ${BM}
		make clean
		make
		cd -
	} #&> /dev/null
done
