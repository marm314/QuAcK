subroutine evRGF2(dotest,dophBSE,doppBSE,TDA,dBSE,dTDA,maxSCF,thresh,max_diis,singlet,triplet, &
                 linearize,eta,doSRG,nBas,nOrb,nC,nO,nV,nR,nS,ENuc,ERHF,ERI,dipole_int,eHF)

! Perform eigenvalue self-consistent second-order Green function calculation

  implicit none
  include 'parameters.h'

! Input variables

  logical,intent(in)            :: dotest

  logical,intent(in)            :: dophBSE
  logical,intent(in)            :: doppBSE
  logical,intent(in)            :: TDA
  logical,intent(in)            :: dBSE
  logical,intent(in)            :: dTDA
  integer,intent(in)            :: maxSCF
  double precision,intent(in)   :: thresh
  integer,intent(in)            :: max_diis
  logical,intent(in)            :: singlet
  logical,intent(in)            :: triplet
  logical,intent(in)            :: linearize
  double precision,intent(in)   :: eta
  logical,intent(in)            :: doSRG

  integer,intent(in)            :: nBas
  integer,intent(in)            :: nOrb
  integer,intent(in)            :: nO
  integer,intent(in)            :: nC
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nS
  double precision,intent(in)   :: ENuc
  double precision,intent(in)   :: ERHF
  double precision,intent(in)   :: eHF(nOrb)
  double precision,intent(in)   :: ERI(nOrb,nOrb,nOrb,nOrb)
  double precision,intent(in)   :: dipole_int(nOrb,nOrb,ncart)

! Local variables

  integer                       :: nSCF
  integer                       :: n_diis
  double precision              :: Ec
  double precision              :: EcBSE(nspin)
  double precision              :: Conv
  double precision              :: rcond
  double precision              :: flow
  double precision,allocatable  :: eGF(:)
  double precision,allocatable  :: eOld(:)
  double precision,allocatable  :: SigC(:)
  double precision,allocatable  :: Z(:)
  double precision,allocatable  :: error_diis(:,:)
  double precision,allocatable  :: e_diis(:,:)

! Hello world

  write(*,*)
  write(*,*)'********************************'
  write(*,*)'* Restricted evGF2 Calculation *'
  write(*,*)'********************************'
  write(*,*)

! SRG regularization

  flow = 500d0

  if(doSRG) then

    write(*,*) '*** SRG regularized evGF2 scheme ***'
    write(*,*)

  end if

! Memory allocation

  allocate(SigC(nOrb), Z(nOrb), eGF(nOrb), eOld(nOrb), error_diis(nOrb,max_diis), e_diis(nOrb,max_diis))

! Initialization

  Conv            = 1d0
  nSCF            = 0
  n_diis          = 0
  e_diis(:,:)     = 0d0
  error_diis(:,:) = 0d0
  eGF(:)         = eHF(:)
  eOld(:)         = eHF(:)
  rcond           = 0d0
!------------------------------------------------------------------------
! Main SCF loop
!------------------------------------------------------------------------

  do while(Conv > thresh .and. nSCF < maxSCF)

    ! Frequency-dependent second-order contribution

    if(doSRG) then 

      call RGF2_SRG_self_energy_diag(flow,nOrb,nC,nO,nV,nR,eGF,ERI,Ec,SigC,Z)

    else

      call RGF2_self_energy_diag(eta,nOrb,nC,nO,nV,nR,eGF,ERI,Ec,SigC,Z)

    end if

    ! Solve the quasi-particle equation
 
    if(linearize) then
 
    else
 
      write(*,*) ' *** Quasiparticle energies obtained by root search *** '
      write(*,*)
 
      call RGF2_QP_graph(doSRG,eta,flow,nOrb,nC,nO,nV,nR,eHF,ERI,eOld,eOld,eGF,Z)
 
    end if

    Conv = maxval(abs(eGF - eOld))

    ! Print results

    call print_evRGF2(nOrb,nC,nO,nV,nR,nSCF,Conv,eHF,SigC,Z,eGF,ENuc,ERHF,Ec)

    ! DIIS extrapolation

    n_diis = min(n_diis+1,max_diis)
    call DIIS_extrapolation(rcond,nOrb,nOrb,n_diis,error_diis,e_diis,eGF-eOld,eGF)

    if(abs(rcond) < 1d-15) n_diis = 0

    eOld(:) = eGF(:)

    ! Increment

    nSCF = nSCF + 1

  end do
!------------------------------------------------------------------------
! End main SCF loop
!------------------------------------------------------------------------

! Did it actually converge?

  if(nSCF == maxSCF+1) then

    write(*,*)
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,*)'                 Convergence failed                 '
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,*)

    stop

  end if

! Perform BSE@GF2 calculation

  if(dophBSE) then 
  
    call RGF2_phBSE(TDA,dBSE,dTDA,singlet,triplet,eta,nOrb,nC,nO,nV,nR,nS,ERI,dipole_int,eGF,EcBSE)

    write(*,*)
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@evGF2 correlation energy (singlet) =',EcBSE(1)
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@evGF2 correlation energy (triplet) =',EcBSE(2)
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@evGF2 correlation energy           =',sum(EcBSE(:))
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@evGF2 total energy                 =',ENuc + ERHF + sum(EcBSE(:))
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,*)

  end if

! Perform ppBSE@GF2 calculation

  if(doppBSE) then

    call RGF2_ppBSE(TDA,dBSE,dTDA,singlet,triplet,eta,nOrb,nC,nO,nV,nR,ERI,dipole_int,eGF,EcBSE)

    write(*,*)
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@evGF2 correlation energy (singlet) =',EcBSE(1),' au'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@evGF2 correlation energy (triplet) =',3d0*EcBSE(2),' au'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@evGF2 correlation energy           =',EcBSE(1) + 3d0*EcBSE(2),' au'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@evGF2 total energy                 =',ENuc + ERHF + EcBSE(1) + 3d0*EcBSE(2),' au'
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,*)

  end if

! Testing zone

  if(dotest) then

    call dump_test_value('R','evGF2 correlation energy',Ec)
    call dump_test_value('R','evGF2 HOMO energy',eGF(nO))
    call dump_test_value('R','evGF2 LUMO energy',eGF(nO+1))

  end if

  deallocate(SigC, Z, eGF, eOld, error_diis, e_diis)

end subroutine 
