#
# File:  ibm_mpi.gnu
#
# The commenting in this file is intended for occasional maintainers who 
# have better uses for their time than learning "make", "awk", etc.  There 
# will someday be a file which is a cookbook in Q&A style: "How do I do X?" 
# is followed by something like "Go to file Y and add Z to line NNN."
#
FC = mpxlf90_r
LD = mpxlf90_r
CC = mpcc_r
Cp = /usr/bin/cp
Cpp = /usr/ccs/lib/cpp -P
AWK = /usr/bin/awk
ABI = -q64 
COMMDIR = mpi
USEPIO  = yes

ifeq ($(USEPIO),yes)
   
   USEMCT = yes

   # Serial NETCDF libraries
   SNETCDF = /usr/local/netcdf
   SNETCDFINC = -I$(SNETCDF)/include -I$(SNETCDF)/lib
   SNETCDFLIB = -L$(SNETCDF)/lib -lnetcdf

   # Parallel NETCDF libraries
   PNETCDF=/contrib/parallel-netcdf-1.0.2pre1
   PNETCDFINC = -I$(PNETCDF)/include
   PNETCDFLIB = -L$(PNETCDF)/lib -lpnetcdf

   NETCDFINCS = $(SNETCDFINC) $(PNETCDFINC)
   NETCDFLIBS = $(SNETCDFLIB) $(PNETCDFLIB)


   # MCT libraries
   PIO =/ptmp/dennis/pio_prod_01/
   PIOINCS = -I$(PIO)/pio
   ifeq ($(USEMCT),yes)
      MPEU=$(PIO)/mct/mpeu
      MPEUINC= -I$(MPEU)
      MPEULIB=-L$(MPEU) -lmpeu

      MCT=$(PIO)/mct/mct
      MCTINC=-I$(MCT)
      MCTLIB= -L$(MCT) -lmct
   else
      MPEUINC =
      MPEULIB = 
      MCTINC =
      MCTLIB = 
   endif
   PIO_DEFINE = _USEPIO
   PIOLIBS = -L$(PIO)/pio -l pio $(MCTLIB) $(MPEULIB)

else

   # Serial NETCDF libraries
   SNETCDF = /usr/local/netcdf
   NETCDFINCS = -I$(SNETCDF)/include -I$(SNETCDF)/lib
   NETCDFLIBS = -L$(SNETCDF)/lib -lnetcdf

   
   # Still need to library to compile
   PIO =/ptmp/dennis/pio_prod_01/
   PIOINCS = -I$(PIO)/pio
  
   PIO_DEFINE = _NOPIO

endif



#  Enable MPI library for parallel code, yes/no.

MPI = yes

#  Enable trapping and traceback of floating point exceptions, yes/no.
#  Note - Requires 'setenv TRAP_FPE "ALL=ABORT,TRACE"' for traceback.

TRAP_FPE = no

#------------------------------------------------------------------
#  precompiler options
#------------------------------------------------------------------

#DCOUPL              = -Dcoupled


Cpp_opts =   \
      $(DCOUPL)

Cpp_opts := $(Cpp_opts) -DPOSIX -D$(PIO_DEFINE)
 
#----------------------------------------------------------------------------
#
#                           C Flags
#
#----------------------------------------------------------------------------
 
CFLAGS = $(ABI)

ifeq ($(OPTIMIZE),yes)
  CFLAGS := $(CFLAGS) -O
else
  CFLAGS := $(CFLAGS) -g
endif
 
#----------------------------------------------------------------------------
#
#                           FORTRAN Flags
#
#----------------------------------------------------------------------------
 
FBASE = $(ABI) -qarch=auto -qnosave -bmaxdata:0x80000000 $(PIOINCS) $(NETCDFINCS) -I$(ObjDepDir)

ifeq ($(TRAP_FPE),yes)
  FBASE := $(FBASE) -qflttrap=overflow:zerodivide:enable -qspillsize=32704
endif

ifeq ($(OPTIMIZE),yes)
#  FFLAGS = $(FBASE) -g -pg -O4 -qnoipa -qmaxmem=-1 -qstrict
  FFLAGS = $(FBASE) -O4 -qnoipa -qmaxmem=-1 -qstrict
else
  FFLAGS := $(FBASE) -g 
# below does bounds checking
# FFLAGS := $(FBASE) -g -C
endif
 
#----------------------------------------------------------------------------
#
#                           Loader Flags and Libraries
#
#----------------------------------------------------------------------------
 
LDFLAGS = $(FFLAGS) -qspillsize=32704
 
#LIBS = $(NETCDFLIB) -lnetcdf -lX11
LIBS = $(PIOLIBS) $(NETCDFLIBS)
 
ifeq ($(MPI),yes)
#  LIBS := $(LIBS) -lmpi
endif

ifeq ($(TRAP_FPE),yes)
  LIBS := $(LIBS) 
endif
 
#LDLIBS = $(TARGETLIB) $(LIBRARIES) $(LIBS)
LDLIBS = $(LIBS)
 
#----------------------------------------------------------------------------
#
#                           Explicit Rules for Compilation Problems
#
#----------------------------------------------------------------------------

#----------------------------------------------------------------------------
#
#                           Implicit Rules for Compilation
#
#----------------------------------------------------------------------------
 
# Cancel the implicit gmake rules for compiling
%.o : %.f
%.o : %.f90
%.o : %.c

%.o: %.f
	@echo IBM_MPI Compiling with implicit rule $<
	@$(FC) $(FFLAGS) -qfixed -c $<
	@if test -f *.mod; then mv -f *.mod $(ObjDepDir); fi
 
%.o: %.f90
	@echo IBM_MPI Compiling with implicit rule $<
	$(FC) $(FFLAGS) -qsuffix=f=f90 -qfree=f90 -c $<
	@if test -f *.mod; then mv -f *.mod $(ObjDepDir); fi
 
%.o: %.c
	@echo IBM_MPI Compiling with implicit rule $<
	@$(CC) $(Cpp_opts) $(CFLAGS) -c $<

#----------------------------------------------------------------------------
#
#                           Implicit Rules for Dependencies
#
#----------------------------------------------------------------------------
 
ifeq ($(OPTIMIZE),yes)
  DEPSUF = .do
else
  DEPSUF = .d
endif

# Cancel the implicit gmake rules for preprocessing

%.c : %.C
%.o : %.C

%.f90 : %.F90
%.o : %.F90

%.f : %.F
%.o : %.F

%.h : %.H
%.o : %.H

# Preprocessing  dependencies are generated for Fortran (.F, F90) and C files
$(SrcDepDir)/%$(DEPSUF): %.F
	@echo 'IBM_MPI Making depends for preprocessing' $<
	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.f
	@echo '$(*).f: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

$(SrcDepDir)/%$(DEPSUF): %.F90
	@echo 'IBM_MPI Making depends for preprocessing' $<
	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.f90
	@echo '$(*).f90: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

$(SrcDepDir)/%$(DEPSUF): %.C
	@echo 'IBM_MPI Making depends for preprocessing' $<
#  For some reason, our current Cpp options are incorrect for C files.
#  Therefore, let the C compiler take care of #ifdef's, etc.  Just copy.
#	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.c
	@$(Cp) $< $(TOP)/compile/$*.c
	@echo '$(*).c: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

# Compiling dependencies are generated for all normal .f files
$(ObjDepDir)/%$(DEPSUF): %.f
	@if test -f $(TOP)/compile/$*.f;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.f; fi
	@echo 'IBM_MPI Making depends for compiling' $<
	@$(AWK) -f $(TOP)/fdepends.awk -v NAME=$(basename $<) -v ObjDepDir=$(ObjDepDir) -v SUF=$(suffix $<) -v DEPSUF=$(DEPSUF) $< > $(ObjDepDir)/$(@F)

# Compiling dependencies are generated for all normal .f90 files
$(ObjDepDir)/%$(DEPSUF): %.f90
	@if test -f $(TOP)/compile/$*.f90;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.f90; fi
	@echo 'IBM_MPI Making depends for compiling' $<
	@$(AWK) -f $(TOP)/fdepends.awk -v NAME=$(basename $<) -v ObjDepDir=$(ObjDepDir) -v SUF=$(suffix $<) -v DEPSUF=$(DEPSUF) $< > $(ObjDepDir)/$(@F)

# Compiling dependencies are also generated for all .c files, but 
# locally included .h files are not treated.  None exist at this 
# time.  The two .c files include only system .h files with names 
# delimited by angle brackets, "<...>"; these are not, and should 
# not, be analyzed.  If the c programming associated with this code 
# gets complicated enough to warrant it, the file "cdepends.awk" 
# will need to test for includes delimited by quotes.
$(ObjDepDir)/%$(DEPSUF): %.c
	@if test -f $(TOP)/compile/$*.c;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.c; fi
	@echo 'IBM_MPI Making depends for compiling' $<
	@echo '$(*).o $(ObjDepDir)/$(*)$(DEPSUF): $(basename $<)$(suffix $<)' > $(ObjDepDir)/$(@F)
