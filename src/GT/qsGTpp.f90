subroutine qsGTpp(maxSCF,thresh,max_diis,doACFDT,exchange_kernel,doXBS,BSE,TDA_T,TDA,          & 
                  dBSE,dTDA,evDyn,singlet,triplet,eta,regularize,nNuc,ZNuc,rNuc,ENuc,nBas,nC,nO,nV,nR,nS,ERHF, &
                  S,X,T,V,Hc,ERI_AO,ERI_MO,dipole_int_AO,dipole_int_MO,PHF,cHF,eHF)

! Perform a quasiparticle self-consistent GT calculation

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: maxSCF
  integer,intent(in)            :: max_diis
  double precision,intent(in)   :: thresh
  logical,intent(in)            :: doACFDT
  logical,intent(in)            :: exchange_kernel
  logical,intent(in)            :: doXBS
  logical,intent(in)            :: BSE
  logical,intent(in)            :: TDA_T
  logical,intent(in)            :: TDA
  logical,intent(in)            :: dBSE
  logical,intent(in)            :: dTDA
  logical,intent(in)            :: evDyn
  logical,intent(in)            :: singlet
  logical,intent(in)            :: triplet
  double precision,intent(in)   :: eta
  logical,intent(in)            :: regularize

  integer,intent(in)            :: nNuc
  double precision,intent(in)   :: ZNuc(nNuc)
  double precision,intent(in)   :: rNuc(nNuc,ncart)
  double precision,intent(in)   :: ENuc

  integer,intent(in)            :: nBas,nC,nO,nV,nR,nS
  double precision,intent(in)   :: ERHF
  double precision,intent(in)   :: eHF(nBas)
  double precision,intent(in)   :: cHF(nBas,nBas)
  double precision,intent(in)   :: PHF(nBas,nBas)
  double precision,intent(in)   :: S(nBas,nBas)
  double precision,intent(in)   :: T(nBas,nBas)
  double precision,intent(in)   :: V(nBas,nBas)
  double precision,intent(in)   :: Hc(nBas,nBas)
  double precision,intent(in)   :: X(nBas,nBas)
  double precision,intent(in)   :: ERI_AO(nBas,nBas,nBas,nBas)
  double precision,intent(inout):: ERI_MO(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: dipole_int_AO(nBas,nBas,ncart)
  double precision,intent(in)   :: dipole_int_MO(nBas,nBas,ncart)

! Local variables

  integer                       :: nSCF
  integer                       :: nBasSq
  integer                       :: ispin
  integer                       :: iblock
  integer                       :: n_diis
  double precision              :: ET
  double precision              :: EV
  double precision              :: EJ
  double precision              :: Ex
  double precision              :: EqsGT
  double precision              :: EcRPA(nspin)
  double precision              :: EcBSE(nspin)
  double precision              :: EcAC(nspin)
  double precision              :: EcGM
  double precision              :: Conv
  double precision              :: rcond
  double precision,external     :: trace_matrix
  double precision              :: dipole(ncart)

  integer                       :: nOOs,nOOt
  integer                       :: nVVs,nVVt

  double precision,allocatable  :: error_diis(:,:)
  double precision,allocatable  :: F_diis(:,:)
  double precision,allocatable  :: c(:,:)
  double precision,allocatable  :: cp(:,:)
  double precision,allocatable  :: eGT(:)
  double precision,allocatable  :: eOld(:)
  double precision,allocatable  :: Om1s(:),Om1t(:)
  double precision,allocatable  :: X1s(:,:),X1t(:,:)
  double precision,allocatable  :: Y1s(:,:),Y1t(:,:)
  double precision,allocatable  :: rho1s(:,:,:),rho1t(:,:,:)
  double precision,allocatable  :: Om2s(:),Om2t(:)
  double precision,allocatable  :: X2s(:,:),X2t(:,:)
  double precision,allocatable  :: Y2s(:,:),Y2t(:,:)
  double precision,allocatable  :: rho2s(:,:,:),rho2t(:,:,:)
  double precision,allocatable  :: P(:,:)
  double precision,allocatable  :: F(:,:)
  double precision,allocatable  :: Fp(:,:)
  double precision,allocatable  :: J(:,:)
  double precision,allocatable  :: K(:,:)
  double precision,allocatable  :: SigT(:,:)
  double precision,allocatable  :: SigTp(:,:)
  double precision,allocatable  :: SigTm(:,:)
  double precision,allocatable  :: Z(:)
  double precision,allocatable  :: error(:,:)

! Hello world

  write(*,*)
  write(*,*)'************************************************'
  write(*,*)'|       Self-consistent qsGT calculation       |'
  write(*,*)'************************************************'
  write(*,*)

! Dimensions of the pp-RPA linear reponse matrices

  nOOs = nO*nO
  nVVs = nV*nV

  nOOt = nO*(nO - 1)/2
  nVVt = nV*(nV - 1)/2

! Warning 

  write(*,*) '!! ERIs in MO basis will be overwritten in qsGT !!'
  write(*,*)

! Stuff 

  nBasSq = nBas*nBas

! TDA for T

  if(TDA_T) then 
    write(*,*) 'Tamm-Dancoff approximation for T-matrix!'
    write(*,*)
  end if

! TDA 

  if(TDA) then 
    write(*,*) 'Tamm-Dancoff approximation activated!'
    write(*,*)
  end if

! Memory allocation

  allocate(eGT(nBas),eOld(nBas),c(nBas,nBas),cp(nBas,nBas),P(nBas,nBas),F(nBas,nBas),Fp(nBas,nBas), &
           J(nBas,nBas),K(nBas,nBas),SigT(nBas,nBas),SigTp(nBas,nBas),SigTm(nBas,nBas),Z(nBas),     & 
           error(nBas,nBas),error_diis(nBasSq,max_diis),F_diis(nBasSq,max_diis))

  allocate(Om1s(nVVs),X1s(nVVs,nVVs),Y1s(nOOs,nVVs),        &
           Om2s(nOOs),X2s(nVVs,nOOs),Y2s(nOOs,nOOs),        &
           rho1s(nBas,nBas,nVVs),rho2s(nBas,nBas,nOOs),        &
           Om1t(nVVt),X1t(nVVt,nVVt),Y1t(nOOt,nVVt),        &
           Om2t(nOOt),X2t(nVVt,nOOt),Y2t(nOOt,nOOt),        &
           rho1t(nBas,nBas,nVVt),rho2t(nBas,nBas,nOOt))

! Initialization
  
  nSCF            = -1
  n_diis          = 0
  ispin           = 1
  Conv            = 1d0
  P(:,:)          = PHF(:,:)
  eGT(:)          = eHF(:)
  eOld(:)         = eHF(:)
  c(:,:)          = cHF(:,:)
  F_diis(:,:)     = 0d0
  error_diis(:,:) = 0d0
  rcond           = 0d0

!------------------------------------------------------------------------
! Main loop
!------------------------------------------------------------------------

  do while(Conv > thresh .and. nSCF <= maxSCF)

    ! Increment

    nSCF = nSCF + 1

    ! Buid Coulomb matrix

    call Coulomb_matrix_AO_basis(nBas,P,ERI_AO,J)

    ! Compute exchange part of the self-energy 

    call exchange_matrix_AO_basis(nBas,P,ERI_AO,K)

    ! AO to MO transformation of two-electron integrals

    call AOtoMO_integral_transform(1,1,1,1,nBas,c,ERI_AO,ERI_MO)

    ! Compute linear response

    ispin  = 1
    iblock = 3

    call ppLR(iblock,TDA_T,nBas,nC,nO,nV,nR,nOOs,nVVs,1d0,eGT,ERI_MO,Om1s,X1s,Y1s,Om2s,X2s,Y2s,EcRPA(ispin))

    ispin  = 2
    iblock = 4

    call ppLR(iblock,TDA_T,nBas,nC,nO,nV,nR,nOOt,nVVt,1d0,eGT,ERI_MO,Om1t,X1t,Y1t,Om2t,X2t,Y2t,EcRPA(ispin))

    EcRPA(1) = EcRPA(1) - EcRPA(2)
    EcRPA(2) = 3d0*EcRPA(2)

    ! Compute correlation part of the self-energy 

    EcGM      = 0d0
    SigT(:,:) = 0d0
    Z(:)      = 0d0

    iblock =  3

    call GTpp_excitation_density(iblock,nBas,nC,nO,nV,nR,nOOs,nVVs,ERI_MO,X1s,Y1s,rho1s,X2s,Y2s,rho2s)

   if(regularize) then

      call regularized_self_energy_Tmatrix(eta,nBas,nC,nO,nV,nR,nOOs,nVVs,eGT,Om1s,rho1s,Om2s,rho2s,EcGM,SigT)
     
      call regularized_renormalization_factor_Tmatrix(eta,nBas,nC,nO,nV,nR,nOOs,nVVs,eGT,Om1s,rho1s,Om2s,rho2s,Z)

    else

      call GTpp_self_energy(eta,nBas,nC,nO,nV,nR,nOOs,nVVs,eGT,Om1s,rho1s,Om2s,rho2s,EcGM,SigT)
      
      call GTpp_renormalization_factor(eta,nBas,nC,nO,nV,nR,nOOs,nVVs,eGT,Om1s,rho1s,Om2s,rho2s,Z)

    end if

    iblock =  4

    call GTpp_excitation_density(iblock,nBas,nC,nO,nV,nR,nOOt,nVVt,ERI_MO,X1t,Y1t,rho1t,X2t,Y2t,rho2t)

    if(regularize) then

      call regularized_self_energy_Tmatrix(eta,nBas,nC,nO,nV,nR,nOOt,nVVt,eGT,Om1t,rho1t,Om2t,rho2t,EcGM,SigT)
     
      call regularized_renormalization_factor_Tmatrix(eta,nBas,nC,nO,nV,nR,nOOt,nVVt,eGT, &
                                                      Om1t,rho1t,Om2t,rho2t,Z)

     else

      call GTpp_self_energy(eta,nBas,nC,nO,nV,nR,nOOt,nVVt,eGT,Om1t,rho1t,Om2t,rho2t,EcGM,SigT)
     
      call GTpp_renormalization_factor(eta,nBas,nC,nO,nV,nR,nOOt,nVVt,eGT,Om1t,rho1t,Om2t,rho2t,Z)

    end if

    Z(:) = 1d0/(1d0 - Z(:))

    ! Make correlation self-energy Hermitian and transform it back to AO basis
   
    SigTp = 0.5d0*(SigT + transpose(SigT))
    SigTm = 0.5d0*(SigT - transpose(SigT))

    call MOtoAO_transform(nBas,S,c,SigTp)
 
    ! Solve the quasi-particle equation

    F(:,:) = Hc(:,:) + J(:,:) + 0.5d0*K(:,:) + SigTp(:,:)

    ! Compute commutator and convergence criteria

    error = matmul(F,matmul(P,S)) - matmul(matmul(S,P),F)

    ! DIIS extrapolation 

    n_diis = min(n_diis+1,max_diis)
    if(abs(rcond) > 1d-7) then 
      call DIIS_extrapolation(rcond,nBasSq,nBasSq,n_diis,error_diis,F_diis,error,F)
    else
      n_diis = 0
    end if

    ! Diagonalize Hamiltonian in AO basis

    Fp = matmul(transpose(X),matmul(F,X))
    cp(:,:) = Fp(:,:)
    call diagonalize_matrix(nBas,cp,eGT)
    c = matmul(X,cp)
    SigTp = matmul(transpose(c),matmul(SigTp,c))

    ! Compute new density matrix in the AO basis

    P(:,:) = 2d0*matmul(c(:,1:nO),transpose(c(:,1:nO)))

    ! Save quasiparticles energy for next cycle

    Conv = maxval(abs(eGT - eOld))
    eOld(:) = eGT(:)

    !------------------------------------------------------------------------
    !   Compute total energy
    !------------------------------------------------------------------------

    ! Kinetic energy

    ET = trace_matrix(nBas,matmul(P,T))

    ! Potential energy

    EV = trace_matrix(nBas,matmul(P,V))

    ! Coulomb energy

    EJ = 0.5d0*trace_matrix(nBas,matmul(P,J))

    ! Exchange energy

    Ex = 0.25d0*trace_matrix(nBas,matmul(P,K))

    ! Total energy

    EqsGT = ET + EV + EJ + Ex 

    ! Print results

    call dipole_moment(nBas,P,nNuc,ZNuc,rNuc,dipole_int_AO,dipole)
    call print_qsGTpp(nBas,nO,nSCF,Conv,thresh,eHF,eGT,c,SigTp,Z,ENuc,ET,EV,EJ,Ex,EcGM,EcRPA,EqsGT,dipole)

  enddo
!------------------------------------------------------------------------
! End main loop
!------------------------------------------------------------------------

! Did it actually converge?

  if(nSCF == maxSCF+1) then

    write(*,*)
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,*)'                 Convergence failed                 '
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,*)

    stop

  endif

! Deallocate memory

  deallocate(c,cp,P,F,Fp,J,K,SigT,SigTp,SigTm,Z,error,error_diis,F_diis)

! Perform BSE calculation

  if(BSE) then

    call GTpp_phBSE(TDA_T,TDA,dBSE,dTDA,evDyn,singlet,triplet,eta,nBas,nC,nO,nV,nR,nS,nOOs,nVVs,nOOt,nVVt,   &
                    Om1s,X1s,Y1s,Om2s,X2s,Y2s,rho1s,rho2s,Om1t,X1t,Y1t,Om2t,X2t,Y2t,rho1t,rho2t, &
                    ERI_MO,dipole_int_MO,eGT,eGT,EcBSE)

    if(exchange_kernel) then

      EcBSE(1) = 0.5d0*EcBSE(1)
      EcBSE(2) = 1.5d0*EcBSE(2)

    end if

    write(*,*)
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,'(2X,A50,F20.10)') 'Tr@BSE@qsGT correlation energy (singlet) =',EcBSE(1)
    write(*,'(2X,A50,F20.10)') 'Tr@BSE@qsGT correlation energy (triplet) =',EcBSE(2)
    write(*,'(2X,A50,F20.10)') 'Tr@BSE@qsGT correlation energy           =',EcBSE(1) + EcBSE(2)
    write(*,'(2X,A50,F20.10)') 'Tr@BSE@qsGT total energy                 =',ENuc + EqsGT + EcBSE(1) + EcBSE(2)
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,*)

!   Compute the BSE correlation energy via the adiabatic connection 

    if(doACFDT) then

      write(*,*) '------------------------------------------------------'
      write(*,*) 'Adiabatic connection version of BSE correlation energy'
      write(*,*) '------------------------------------------------------'
      write(*,*)

      if(doXBS) then

        write(*,*) '*** scaled screening version (XBS) ***'
        write(*,*)

      end if

      call ACFDT_Tmatrix(exchange_kernel,doXBS,.false.,TDA_T,TDA,BSE,singlet,triplet,eta,nBas,nC,nO,nV,nR,nS, &
                         nOOs,nVVs,nOOt,nVVt,Om1s,X1s,Y1s,Om2s,X2s,Y2s,rho1s,rho2s,Om1t,X1t,Y1t,     &
                         Om2t,X2t,Y2t,rho1t,rho2t,ERI_MO,eGT,eGT,EcAC)

      write(*,*)
      write(*,*)'-------------------------------------------------------------------------------'
      write(*,'(2X,A50,F20.10)') 'AC@BSE@qsGT correlation energy (singlet) =',EcAC(1)
      write(*,'(2X,A50,F20.10)') 'AC@BSE@qsGT correlation energy (triplet) =',EcAC(2)
      write(*,'(2X,A50,F20.10)') 'AC@BSE@qsGT correlation energy           =',EcAC(1) + EcAC(2)
      write(*,'(2X,A50,F20.10)') 'AC@BSE@qsGT total energy                 =',ENuc + EqsGT + EcAC(1) + EcAC(2)
      write(*,*)'-------------------------------------------------------------------------------'
      write(*,*)

    end if

  end if

end subroutine 
