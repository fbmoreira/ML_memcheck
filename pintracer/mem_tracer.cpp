#include <cstdlib>
#include <iostream>
#include <cstring>
#include <map>
#include "pin.H"

#define MAX_THREADS 32

KNOB<BOOL>   KnobTrackLoads(KNOB_MODE_WRITEONCE,            "pintool",  "tl",   "1",                "track individual loads");
KNOB<BOOL>   KnobTrackStores(KNOB_MODE_WRITEONCE,           "pintool",  "ts",   "1",                "track individual stores");
KNOB<BOOL>   KnobTrackInstructions(KNOB_MODE_WRITEONCE,     "pintool",  "ti",   "1",                "track individual instructions -- increases profiling time");


INT32 Usage()
{
    PIN_ERROR( "This Pintool outputs a trace of 16384 memory access aggregations for each thread\n"
              + KNOB_BASE::StringKnobSummary() + "\n");
    return -1;
}

int num_threads = 0;


PIN_LOCK lock;

FILE * fbm_tracer[32];
std::map<long unsigned, long unsigned> _memmapread;
std::map<long unsigned, long unsigned> _memmapwrite;
std::map<long unsigned, long unsigned> _memmapinstr;
std::map<long unsigned, long unsigned>::iterator _it;
UINT64 _totread = 0;
UINT64 _totwrite = 0;
UINT64 _totinstr = 0;
UINT64 _period = 0;



VOID LoadMulti(ADDRINT addr, UINT32 size, ADDRINT instAddr,THREADID threadid)
{
    PIN_GetLock(&lock, threadid+1);

    UINT64 index = addr << 12;	   
    _totread++;
    _it = _memmapread.find(index);
    if (_it == _memmapread.end()){
        _memmapread[index] = 1;
    } else {
        _memmapread[index]++;
    }      
    _period++;
if (_period == 16384){

				fprintf(fbm_tracer[threadid],"%lu %lu %lu %lu %lu %lu\n", _totread, _memmapread.size(), _totwrite, _memmapwrite.size(), _totinstr, _memmapinstr.size());
                                _memmapread.clear();
                                _memmapwrite.clear();
                                _memmapinstr.clear();
                                _totread = 0;
                                _totwrite = 0;
                                _totinstr = 0;
				_period = 0;
                        }
    

    PIN_ReleaseLock(&lock);
}


VOID StoreMulti(ADDRINT addr, UINT32 size, ADDRINT instAddr,THREADID threadid)
{
    PIN_GetLock(&lock, threadid+1);

   UINT64 index = addr << 12;
    _totread++;
    _it = _memmapwrite.find(index);
    if (_it == _memmapwrite.end()){
	_memmapwrite[index] = 1;
    } else {  
	_memmapwrite[index]++;
    }
    _period++;
if (_period == 16384){  
                                fprintf(fbm_tracer[threadid],"%lu %lu %lu %lu %lu %lu\n", _totread, _memmapread.size(), _totwrite, _memmapwrite.size(), _totinstr, _memmapinstr.size());
                                _memmapread.clear();
                                _memmapwrite.clear();
                                _memmapinstr.clear();
                                _totread = 0;
                                _totwrite = 0;
                                _totinstr = 0;
                                _period = 0;
                        }
                        

    PIN_ReleaseLock(&lock);
}


VOID LoadInstructionMulti(ADDRINT addr, UINT32 size, ADDRINT instAddr,THREADID threadid)
{
    PIN_GetLock(&lock, threadid+1);
    UINT64 index = addr << 12;
    _totinstr++;
    _it = _memmapinstr.find(index);
    if (_it == _memmapinstr.end()){
       _memmapinstr[index] = 1;
    }
    else { 
       _memmapinstr[index]++;
    }
    _period++;

if (_period == 16384){
				fprintf(fbm_tracer[threadid],"%lu %lu %lu %lu %lu %lu\n", _totread, _memmapread.size(), _totwrite, _memmapwrite.size(), _totinstr, _memmapinstr.size());
                                _memmapread.clear();
                                _memmapwrite.clear();
                                _memmapinstr.clear();
                                _totread = 0;
                                _totwrite = 0;
                                _totinstr = 0;
				_period = 0;
                        }

    PIN_ReleaseLock(&lock);
}

VOID Instruction(INS ins, void * v)
{
    // Track the Instructions and send to the Instruction Cache
    if( KnobTrackInstructions )
    {
        INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)LoadInstructionMulti,
            IARG_INST_PTR,
            IARG_UINT32,
            INS_Size(ins),
            IARG_INST_PTR,
            IARG_THREAD_ID,
            IARG_END);
    }


    // Track the Loads and Stores and send to the Data Cache
    if (INS_IsMemoryRead(ins) && KnobTrackLoads)
    {
        INS_InsertPredicatedCall(
            ins, IPOINT_BEFORE,  (AFUNPTR) LoadMulti,
            IARG_MEMORYREAD_EA,
            IARG_MEMORYREAD_SIZE,
            IARG_INST_PTR,
            IARG_THREAD_ID,
            IARG_END);
    }

    if ( INS_IsMemoryWrite(ins) && KnobTrackStores)
    {
        INS_InsertPredicatedCall(
            ins, IPOINT_BEFORE,  (AFUNPTR) StoreMulti,
            IARG_MEMORYWRITE_EA,
            IARG_MEMORYWRITE_SIZE,
            IARG_INST_PTR,
            IARG_THREAD_ID,
            IARG_END);
    }
}

string img_name;
char* apparg; 

VOID binName(IMG img, VOID *v)
{
    if (IMG_IsMainExecutable(img))
        img_name = basename(IMG_Name(img).c_str());
}

VOID func_callback(THREADID pin_id, ADDRINT arg1)
{
       // __sync_add_and_fetch(&n, 1);
        printf("called intercept arg %s\n", (char*)arg1);
	apparg = (char*)arg1;
	apparg = strrchr(apparg, '/');
}

VOID Image(IMG img, VOID *v)
{
        {
                RTN rtn = RTN_FindByName(img, "open");
                if (RTN_Valid(rtn)) {
                        RTN_Open(rtn);
                        RTN_InsertCall(rtn, IPOINT_BEFORE, (AFUNPTR)func_callback,
                                                   IARG_THREAD_ID,
                                                   IARG_FUNCARG_ENTRYPOINT_VALUE, 0,
                                                   IARG_END);
                        RTN_Close(rtn);
                        cout << "RTN intercept installed\n";
                }
        }
}




VOID ThreadStart(THREADID tid, CONTEXT *ctxt, INT32 flags, VOID *v)
{
    __sync_add_and_fetch(&num_threads, 1);
}

int main(int argc, char *argv[])
{
    PIN_InitSymbols();
    PIN_InitLock(&lock);

    //fbm_tracer = fopen("fbm_trace.out", "w");

    if( PIN_Init(argc,argv) ) {
        return Usage();
    }

    for (UINT32 i=0; i<MAX_THREADS; i++){
	char fbmname[80];
	sprintf(fbmname, "mem_trace_%d.out", i);
	fbm_tracer[i] = fopen(fbmname, "w");
    }
	

    PIN_AddThreadStartFunction(ThreadStart, 0);
    IMG_AddInstrumentFunction(binName, 0);
    IMG_AddInstrumentFunction(Image, 0);
    INS_AddInstrumentFunction(Instruction, 0);
    PIN_StartProgram();

    for (UINT32 i=0; i<MAX_THREADS; i++){
    	fclose(fbm_tracer[i]);
    }
    return 0;
}
