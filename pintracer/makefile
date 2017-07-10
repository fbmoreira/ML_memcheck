override PIN_ROOT = /opt/pin

ifdef PIN_ROOT
CONFIG_ROOT := $(PIN_ROOT)/source/tools/Config
else
CONFIG_ROOT := ../Config
endif
include $(CONFIG_ROOT)/makefile.config

TOOL_CXXFLAGS += -Wall -g -std=c++0x -Wno-error
TOOL_LDFLAGS += -Wl,-rpath,/opt/pin/intel64/runtime


TEST_TOOL_ROOTS := mem_tracer

include $(TOOLS_ROOT)/Config/makefile.default.rules

#$(OBJDIR)cache_sim$(OBJ_SUFFIX): cache.H  cache_parameters.H
