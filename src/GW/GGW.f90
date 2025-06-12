subroutine GGW(dotest,doG0W0,doevGW,doqsGW,maxSCF,thresh,max_diis,doACFDT,exchange_kernel,doXBS,dophBSE,dophBSE2,doppBSE, & 
               TDA_W,TDA,dBSE,dTDA,linearize,eta,doSRG,nNuc,ZNuc,rNuc,ENuc,nBas,nBas2,nC,nO,nV,nR,nS,EGHF,S,X,T,V,Hc,     & 
               ERI_AO,ERI,dipole_int_AO,dipole_int,PHF,cHF,eHF,eGW)

! GW module

  implicit none
  include 'parameters.h'

! Input variables

  logical,intent(in)            :: dotest

  logical,intent(in)            :: doG0W0
  logical,intent(in)            :: doevGW
  logical,intent(in)            :: doqsGW

  integer,intent(in)            :: maxSCF
  integer,intent(in)            :: max_diis
  double precision,intent(in)   :: thresh
  logical,intent(in)            :: doACFDT
  logical,intent(in)            :: exchange_kernel
  logical,intent(in)            :: doXBS
  logical,intent(in)            :: dophBSE
  logical,intent(in)            :: dophBSE2
  logical,intent(in)            :: TDA_W
  logical,intent(in)            :: TDA
  logical,intent(in)            :: dBSE
  logical,intent(in)            :: dTDA
  logical,intent(in)            :: doppBSE
  logical,intent(in)            :: linearize
  double precision,intent(in)   :: eta
  logical,intent(in)            :: doSRG

  integer,intent(in)            :: nNuc
  double precision,intent(in)   :: ZNuc(nNuc)
  double precision,intent(in)   :: rNuc(nNuc,ncart)
  double precision,intent(in)   :: ENuc

  integer,intent(in)            :: nBas
  integer,intent(in)            :: nBas2
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nS

  double precision,intent(in)   :: EGHF
  double precision,intent(in)   :: eHF(nBas2)
  double precision,intent(in)   :: cHF(nBas2,nBas2)
  double precision,intent(in)   :: PHF(nBas2,nBas2)
  double precision,intent(in)   :: S(nBas2,nBas2)
  double precision,intent(in)   :: T(nBas2,nBas2)
  double precision,intent(in)   :: V(nBas2,nBas2)
  double precision,intent(in)   :: Hc(nBas2,nBas2)
  double precision,intent(in)   :: X(nBas2,nBas2)
  double precision,intent(in)   :: ERI_AO(nBas2,nBas2,nBas2,nBas2)
  double precision,intent(in)   :: ERI(nBas2,nBas2,nBas2,nBas2)
  double precision,intent(in)   :: dipole_int_AO(nBas2,nBas2,ncart)
  double precision,intent(in)   :: dipole_int(nBas2,nBas2,ncart)

! Local variables

  double precision              :: start_GW     ,end_GW       ,t_GW

! Output variables

  double precision,intent(out)  :: eGW(nBas2)

!------------------------------------------------------------------------
! Perform G0W0 calculatiom
!------------------------------------------------------------------------

  if(doG0W0) then
    
    call wall_time(start_GW)
    call GG0W0(dotest,doACFDT,exchange_kernel,doXBS,dophBSE,dophBSE2,TDA_W,TDA,dBSE,dTDA,doppBSE, &
              linearize,eta,doSRG,nBas2,nC,nO,nV,nR,nS,ENuc,EGHF,ERI,dipole_int,eHF,eGW)
    call wall_time(end_GW)
  
    t_GW = end_GW - start_GW
    write(*,'(A65,1X,F9.3,A8)') 'Total CPU time for G0W0 = ',t_GW,' seconds'
    write(*,*)

  end if

!------------------------------------------------------------------------
! Perform evGW calculation
!------------------------------------------------------------------------

  if(doevGW) then

    call wall_time(start_GW)
    call evGGW(dotest,maxSCF,thresh,max_diis,doACFDT,exchange_kernel,doXBS,dophBSE,dophBSE2,TDA_W,TDA,dBSE,dTDA,doppBSE, &
               linearize,eta,doSRG,nBas2,nC,nO,nV,nR,nS,ENuc,EGHF,ERI,dipole_int,eHF)
    call wall_time(end_GW)

    t_GW = end_GW - start_GW
    write(*,'(A65,1X,F9.3,A8)') 'Total CPU time for evGW = ',t_GW,' seconds'
    write(*,*)

  end if

!------------------------------------------------------------------------
! Perform qsGW calculation
!------------------------------------------------------------------------

  if(doqsGW) then 

    call wall_time(start_GW)
    call qsGGW(dotest,maxSCF,thresh,max_diis,doACFDT,exchange_kernel,doXBS,dophBSE,dophBSE2,TDA_W,TDA,dBSE,dTDA,doppBSE, & 
               eta,doSRG,nNuc,ZNuc,rNuc,ENuc,nBas,nBas2,nC,nO,nV,nR,nS,EGHF,S,X,T,V,Hc,ERI_AO,ERI,                       & 
               dipole_int_AO,dipole_int,PHF,cHF,eHF)
    call wall_time(end_GW)

    t_GW = end_GW - start_GW
    write(*,'(A65,1X,F9.3,A8)') 'Total CPU time for qsGW = ',t_GW,' seconds'
    write(*,*)

  end if

end subroutine
