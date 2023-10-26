subroutine GHF(maxSCF,thresh,max_diis,guess_type,mix,level_shift,nNuc,ZNuc,rNuc,ENuc, & 
               nBas,nBas2,nO,Ov,T,V,Hc,ERI,dipole_int,Or,EHF,e,c,P)

! Perform unrestricted Hartree-Fock calculation

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: maxSCF
  integer,intent(in)            :: max_diis
  integer,intent(in)            :: guess_type
  double precision,intent(in)   :: mix 
  double precision,intent(in)   :: level_shift
  double precision,intent(in)   :: thresh
  integer,intent(in)            :: nBas
  integer,intent(in)            :: nBas2

  integer,intent(in)            :: nNuc
  double precision,intent(in)   :: ZNuc(nNuc)
  double precision,intent(in)   :: rNuc(nNuc,ncart)
  double precision,intent(in)   :: ENuc

  integer,intent(in)            :: nO(nspin)
  double precision,intent(in)   :: Ov(nBas,nBas)
  double precision,intent(in)   :: T(nBas,nBas)
  double precision,intent(in)   :: V(nBas,nBas)
  double precision,intent(in)   :: Hc(nBas,nBas) 
  double precision,intent(in)   :: Or(nBas,nBas) 
  double precision,intent(in)   :: ERI(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: dipole_int(nBas,nBas,ncart)

! Local variables

  integer                       :: nSCF
  integer                       :: nBasSq
  integer                       :: nBas2Sq
  integer                       :: nOa
  integer                       :: nOb
  integer                       :: nOcc
  integer                       :: n_diis
  double precision              :: Conv
  double precision              :: rcond
  double precision              :: ET,ETaa,ETbb
  double precision              :: EV,EVaa,EVbb
  double precision              :: EJ,EJaaaa,EJaabb,EJbbaa,EJbbbb
  double precision              :: Ex,Exaaaa,Exabba,Exbaab,Exbbbb
  double precision              :: dipole(ncart)

  double precision,allocatable  :: Ca(:,:),Cb(:,:)
  double precision,allocatable  :: Jaa(:,:),Jbb(:,:)
  double precision,allocatable  :: Kaa(:,:),Kab(:,:),Kba(:,:),Kbb(:,:)
  double precision,allocatable  :: Faa(:,:),Fab(:,:),Fba(:,:),Fbb(:,:)
  double precision,allocatable  :: Paa(:,:),Pab(:,:),Pba(:,:),Pbb(:,:)
  double precision,allocatable  :: F(:,:)
  double precision,allocatable  :: Fp(:,:)
  double precision,allocatable  :: Cp(:,:)
  double precision,allocatable  :: H(:,:)
  double precision,allocatable  :: S(:,:)
  double precision,allocatable  :: X(:,:)
  double precision,allocatable  :: err(:,:)
  double precision,allocatable  :: err_diis(:,:)
  double precision,allocatable  :: F_diis(:,:)
  double precision,external     :: trace_matrix

  integer                       :: ispin

! Output variables

  double precision,intent(out)  :: EHF
  double precision,intent(out)  :: e(nBas2)
  double precision,intent(out)  :: C(nBas2,nBas2)
  double precision,intent(out)  :: P(nBas2,nBas2)

! Hello world

  write(*,*)
  write(*,*)'***********************************************'
  write(*,*)'*    Generalized Hartree-Fock calculation     *'
  write(*,*)'***********************************************'
  write(*,*)

! Useful stuff

  nBasSq = nBas*nBas
  nBas2Sq = nBas2*nBas2

  nOa  = nO(1)
  nOb  = nO(2)
  nOcc = nOa + nOb

! Memory allocation

  allocate(Ca(nBas,nBas2),Cb(nBas,nBas2),Jaa(nBas,nBas),Jbb(nBas,nBas), &
           Kaa(nBas,nBas),Kab(nBas,nBas),Kba(nBas,nBas),Kbb(nBas,nBas), &
           Faa(nBas,nBas),Fab(nBas,nBas),Fba(nBas,nBas),Fbb(nBas,nBas), &
           Paa(nBas,nBas),Pab(nBas,nBas),Pba(nBas,nBas),Pbb(nBas,nBas), &
           F(nBas2,nBas2),Fp(nBas2,nBas2),Cp(nBas2,nBas2),              &
           H(nBas2,nBas2),S(nBas2,nBas2),X(nBas2,nBas2),err(nBas2,nBas2), &
           err_diis(nBas2Sq,max_diis),F_diis(nBas2Sq,max_diis))

! Initialization

  nSCF = 0
  Conv = 1d0

  n_diis        = 0
  F_diis(:,:)   = 0d0
  err_diis(:,:) = 0d0

! Construct super overlap matrix

  S(      :     ,       :    ) = 0d0
  S(     1:nBas ,     1:nBas ) = Ov(1:nBas,1:nBas)
  S(nBas+1:nBas2,nBas+1:nBas2) = Ov(1:nBas,1:nBas)

! Construct super orthogonalization matrix

  X(      :     ,       :    ) = 0d0
  X(     1:nBas ,     1:nBas ) = Or(1:nBas,1:nBas)
  X(nBas+1:nBas2,nBas+1:nBas2) = Or(1:nBas,1:nBas)

! Construct super orthogonalization matrix

  H(      :     ,       :    ) = 0d0
  H(     1:nBas ,     1:nBas ) = Hc(1:nBas,1:nBas)
  H(nBas+1:nBas2,nBas+1:nBas2) = Hc(1:nBas,1:nBas)

! Guess coefficients and density matrices

  call mo_guess(nBas2,guess_type,S,H,X,C)

  P(:,:) = matmul(C(:,1:nOcc),transpose(C(:,1:nOcc)))

  Paa(:,:) = P(1:nBas,1:nBas)
  Pab(:,:) = P(1:nBas,nBas+1:nBas2)
  Pba(:,:) = P(nBas+1:nBas2,1:nBas)
  Pbb(:,:) = P(nBas+1:nBAs2,nBAs+1:nBas2)

!------------------------------------------------------------------------
! Main SCF loop
!------------------------------------------------------------------------

  write(*,*)
  write(*,*)'-----------------------------------------------------------------------------'
  write(*,'(1X,A1,1X,A3,1X,A1,1X,A16,1X,A1,1X,A16,1X,A1,1X,A16,1X,A1,1X,A10,1X,A1,1X)') & 
            '|','#','|','E(GHF)','|','EJ(GHF)','|','Ex(GHF)','|','Conv','|'
  write(*,*)'-----------------------------------------------------------------------------'
  
  do while(Conv > thresh .and. nSCF < maxSCF)

!   Increment 

    nSCF = nSCF + 1

!   Build individual Hartree matrices

    call Hartree_matrix_AO_basis(nBas,Paa,ERI,Jaa)
    call Hartree_matrix_AO_basis(nBas,Pbb,ERI,Jbb)

!   Compute individual exchange matrices

    call exchange_matrix_AO_basis(nBas,Paa,ERI,Kaa)
    call exchange_matrix_AO_basis(nBas,Pba,ERI,Kab)
    call exchange_matrix_AO_basis(nBas,Pab,ERI,Kba)
    call exchange_matrix_AO_basis(nBas,Pbb,ERI,Kbb)
 
!   Build individual Fock matrices

    Faa(:,:) = Hc(:,:) + Jaa(:,:) + Jbb(:,:) + Kaa(:,:)
    Fab(:,:) =                               + Kab(:,:)
    Fba(:,:) =                               + Kba(:,:)
    Fbb(:,:) = Hc(:,:) + Jbb(:,:) + Jaa(:,:) + Kbb(:,:)

!  Build super Fock matrix

    F(     1:nBas ,     1:nBas ) = Faa(1:nBas,1:nBas)
    F(     1:nBas ,nBas+1:nBas2) = Fab(1:nBas,1:nBas)
    F(nBas+1:nBas2,     1:nBas ) = Fba(1:nBas,1:nBas)
    F(nBas+1:nBas2,nBas+1:nBas2) = Fbb(1:nBas,1:nBas)

!   Check convergence 

    err(:,:) = matmul(F,matmul(P,S)) - matmul(matmul(S,P),F)

    if(nSCF > 1) Conv = maxval(abs(err))
    
!   DIIS extrapolation

    if(max_diis > 1) then

      n_diis = min(n_diis+1,max_diis)
      call DIIS_extrapolation(rcond,nBas2Sq,nBas2Sq,n_diis,err_diis(:,1:n_diis),F_diis(:,1:n_diis),err,F)

    end if

!   Level-shifting

    if(level_shift > 0d0 .and. Conv > thresh) then

      call level_shifting(level_shift,nBas,nOa+nOb,S,C,F)

    end if

!  Transform Fock matrix in orthogonal basis

    Fp(:,:) = matmul(transpose(X),matmul(F,X))

!  Diagonalize Fock matrix to get eigenvectors and eigenvalues

    Cp(:,:) = Fp(:,:)
    call diagonalize_matrix(nBas2,Cp,e)
    
!   Back-transform eigenvectors in non-orthogonal basis

    C(:,:) = matmul(X,Cp)

!   Form individual coefficient matrices

    Ca(1:nBas,1:nBas2) = C(     1:nBas ,1:nBas2) 
    Cb(1:nBas,1:nBas2) = C(nBas+1:nBas2,1:nBas2) 

!   Mix guess for UHF solution in singlet states

!   if(nSCF == 1) call mix_guess(nBas,nO,mix,c)

!   Compute individual density matrices
    P(:,:) = matmul(C(:,1:nOcc),transpose(C(:,1:nOcc)))

    Paa(:,:) = P(1:nBas,1:nBas)
    Pab(:,:) = P(1:nBas,nBas+1:nBas2)
    Pba(:,:) = P(nBas+1:nBas2,1:nBas)
    Pbb(:,:) = P(nBas+1:nBas2,nBas+1:nBas2)
 
!------------------------------------------------------------------------
!   Compute UHF energy
!------------------------------------------------------------------------

!  Kinetic energy

    ETaa = trace_matrix(nBas,matmul(Paa,T))
    ETbb = trace_matrix(nBas,matmul(Pbb,T))

    ET = ETaa + ETbb

!  Potential energy

   EVaa = trace_matrix(nBas,matmul(Paa,V))
   EVbb = trace_matrix(nBas,matmul(Pbb,V))

   EV = EVaa + EVbb

!  Hartree energy: 16 terms?

    EJaaaa = 0.5d0*trace_matrix(nBas,matmul(Paa,Jaa))
    EJaabb = 0.5d0*trace_matrix(nBas,matmul(Paa,Jbb))
    EJbbaa = 0.5d0*trace_matrix(nBas,matmul(Pbb,Jaa))
    EJbbbb = 0.5d0*trace_matrix(nBas,matmul(Pbb,Jbb))

    EJ = EJaaaa + EJaabb + EJbbaa + EJbbbb
  
!   Exchange energy

    Exaaaa = 0.5d0*trace_matrix(nBas,matmul(Paa,Kaa))
    Exabba = 0.5d0*trace_matrix(nBas,matmul(Pab,Kba))
    Exbaab = 0.5d0*trace_matrix(nBas,matmul(Pba,Kab))
    Exbbbb = 0.5d0*trace_matrix(nBas,matmul(Pbb,Kbb))

    Ex = Exaaaa + Exabba + Exbaab + Exbbbb

!   Total energy

    EHF = ET + EV + EJ + Ex

!   Dump results

    write(*,'(1X,A1,1X,I3,1X,A1,1X,F16.10,1X,A1,1X,F16.10,1X,A1,1X,F16.10,1X,A1,1X,F10.6,1X,A1,1X)') & 
      '|',nSCF,'|',EHF + ENuc,'|',EJ,'|',Ex,'|',Conv,'|'
 
  end do
  write(*,*)'-----------------------------------------------------------------------------'
!------------------------------------------------------------------------
! End of SCF loop
!------------------------------------------------------------------------

! Did it actually converge?

  if(nSCF == maxSCF) then

    write(*,*)
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,*)'                 Convergence failed                 '
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,*)

    stop

  end if

! Compute final UHF energy

! call dipole_moment(nBas,P(:,:,1)+P(:,:,2),nNuc,ZNuc,rNuc,dipole_int,dipole)
! call print_GHF(nBas,nO,S,e,c,ENuc,ET,EV,EJ,Ex,EHF,dipole)

end subroutine 
