subroutine BQuAcK(working_dir,dotest,doHFB,nNuc,nBas,nOrb,nC,nO,nV,nR,ENuc,ZNuc,rNuc,                                    &
                  S,T,V,Hc,X,dipole_int_AO,maxSCF_HF,max_diis_HF,thresh_HF,level_shift,                                  &
                  guess_type,mix,temperature,sigma,chem_pot_hf,restart_hfb)

! Restricted branch of QuAcK

  implicit none
  include 'parameters.h'

  character(len=256),intent(in) :: working_dir

  logical,intent(in)            :: dotest

  logical,intent(in)            :: doHFB

  logical,intent(in)            :: restart_hfb
  logical,intent(in)            :: chem_pot_hf
  integer,intent(in)            :: nNuc,nBas,nOrb
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  double precision,intent(in)   :: ENuc
  double precision,intent(in)   :: temperature,sigma

  double precision,intent(in)   :: ZNuc(nNuc),rNuc(nNuc,ncart)

  double precision,intent(in)   :: S(nBas,nBas)
  double precision,intent(in)   :: T(nBas,nBas)
  double precision,intent(in)   :: V(nBas,nBas)
  double precision,intent(in)   :: Hc(nBas,nBas)
  double precision,intent(in)   :: X(nBas,nOrb)
  double precision,intent(in)   :: dipole_int_AO(nBas,nBas,ncart)

  integer,intent(in)            :: maxSCF_HF,max_diis_HF
  double precision,intent(in)   :: thresh_HF,level_shift,mix
  integer,intent(in)            :: guess_type

! Local variables

  integer                       :: nOrb2

  double precision              :: start_HF     ,end_HF       ,t_HF

  double precision              :: start_int, end_int, t_int
  double precision,allocatable  :: eHF(:)
  double precision,allocatable  :: eHFB_state(:)
  double precision,allocatable  :: cHF(:,:)
  double precision,allocatable  :: PHF(:,:)
  double precision,allocatable  :: PanomHF(:,:)
  double precision,allocatable  :: FHF(:,:)
  double precision,allocatable  :: Delta(:,:)
  double precision,allocatable  :: W_vec(:,:)
  double precision,allocatable  :: V_vec(:,:)
  double precision              :: ERHF,EHFB
  double precision,allocatable  :: ERI_AO(:,:,:,:)

  write(*,*)
  write(*,*) '******************************'
  write(*,*) '* Bogoliubov Branch of QuAcK *'
  write(*,*) '******************************'
  write(*,*)

!-------------------!
! Memory allocation !
!-------------------!

  nOrb2=nOrb+nOrb

  allocate(eHF(nOrb))

  allocate(cHF(nBas,nOrb))

  allocate(PHF(nBas,nBas))
  allocate(PanomHF(nBas,nBas))
  allocate(FHF(nBas,nBas))
  allocate(Delta(nBas,nBas))

  allocate(eHFB_state(nOrb2))

  allocate(W_vec(nOrb2,nOrb))
  allocate(V_vec(nOrb2,nOrb))

  allocate(ERI_AO(nBas,nBas,nBas,nBas))
  call wall_time(start_int)
  call read_2e_integrals(working_dir,nBas,ERI_AO)
  call wall_time(end_int)
  t_int = end_int - start_int
  write(*,*)
  write(*,'(A65,1X,F9.3,A8)') 'Total wall time for reading 2e-integrals =',t_int,' seconds'
  write(*,*)

!--------------------------------!
! Hartree-Fock Bogoliubov module !
!--------------------------------!

  if(doHFB) then

    ! Run first a RHF calculation 
    call wall_time(start_HF)
    call RHF(dotest,maxSCF_HF,thresh_HF,max_diis_HF,guess_type,level_shift,nNuc,ZNuc,rNuc,ENuc, &
             nBas,nOrb,nO,S,T,V,Hc,ERI_AO,dipole_int_AO,X,ERHF,eHF,cHF,PHF,FHF)
    call wall_time(end_HF)

    t_HF = end_HF - start_HF
    write(*,'(A65,1X,F9.3,A8)') 'Total wall time for RHF = ',t_HF,' seconds'
    write(*,*)

    ! Continue with a HFB calculation
    call wall_time(start_HF)
    call HFB(dotest,maxSCF_HF,thresh_HF,max_diis_HF,level_shift,nNuc,ZNuc,rNuc,ENuc,       &
             nBas,nOrb,nOrb2,nO,S,T,V,Hc,ERI_AO,dipole_int_AO,X,EHFB,eHF,cHF,PHF,PanomHF,  &
             FHF,Delta,temperature,sigma,chem_pot_hf,restart_hfb,W_vec,V_vec,eHFB_state)
    call wall_time(end_HF)

    t_HF = end_HF - start_HF
    write(*,'(A65,1X,F9.3,A8)') 'Total wall time for HFB = ',t_HF,' seconds'
    write(*,*)

  end if

! Memory deallocation
    
  deallocate(eHF)
  deallocate(cHF)
  deallocate(PHF)
  deallocate(PanomHF)
  deallocate(FHF)
  deallocate(Delta)
  deallocate(ERI_AO)

end subroutine
