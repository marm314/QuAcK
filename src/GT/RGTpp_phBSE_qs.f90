subroutine RGTpp_phBSE_qs(exchange_kernel,TDA_T,TDA,dBSE,dTDA,singlet,triplet,eta,nOrb,nC,nO,nV,nR,nS,nOOs,nVVs,nOOt,nVVt, &
                       Om1s,X1s,Y1s,Om2s,X2s,Y2s,rho1s,rho2s,Om1t,X1t,Y1t,Om2t,X2t,Y2t,rho1t,rho2t,ERI,dipole_int,eT,eGT,EcBSE)

! Compute the Bethe-Salpeter excitation energies with the T-matrix kernel

  implicit none
  include 'parameters.h'

! Input variables

  logical,intent(in)            :: exchange_kernel
  logical,intent(in)            :: TDA_T
  logical,intent(in)            :: TDA
  logical,intent(in)            :: dBSE
  logical,intent(in)            :: dTDA
  logical,intent(in)            :: singlet
  logical,intent(in)            :: triplet

  double precision,intent(in)   :: eta
  integer,intent(in)            :: nOrb
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nS

  integer,intent(in)            :: nOOs
  integer,intent(in)            :: nOOt
  integer,intent(in)            :: nVVs
  integer,intent(in)            :: nVVt

  double precision,intent(in)   :: eT(nOrb)
  double precision,intent(in)   :: eGT(nOrb)
  double precision,intent(in)   :: ERI(nOrb,nOrb,nOrb,nOrb)
  double precision,intent(in)   :: dipole_int(nOrb,nOrb,ncart)

  double precision,intent(in)   :: Om1s(nVVs)
  double precision,intent(in)   :: X1s(nVVs,nVVs)
  double precision,intent(in)   :: Y1s(nOOs,nVVs)
  double precision,intent(in)   :: Om2s(nOOs)
  double precision,intent(in)   :: X2s(nVVs,nOOs)
  double precision,intent(in)   :: Y2s(nOOs,nOOs)
  double precision,intent(in)   :: rho1s(nOrb,nOrb,nVVs)
  double precision,intent(in)   :: rho2s(nOrb,nOrb,nOOs)
  double precision,intent(in)   :: Om1t(nVVt)
  double precision,intent(in)   :: X1t(nVVt,nVVt)
  double precision,intent(in)   :: Y1t(nOOt,nVVt)
  double precision,intent(in)   :: Om2t(nOOt)
  double precision,intent(in)   :: X2t(nVVt,nOOt)
  double precision,intent(in)   :: Y2t(nOOt,nOOt) 
  double precision,intent(in)   :: rho1t(nOrb,nOrb,nVVt)
  double precision,intent(in)   :: rho2t(nOrb,nOrb,nOOt)

! Local variables

  logical                       :: dRPA = .false.

  integer                       :: ispin

  double precision,allocatable  :: Bpp(:,:)
  double precision,allocatable  :: Cpp(:,:)
  double precision,allocatable  :: Dpp(:,:)

  double precision,allocatable  :: Aph(:,:)
  double precision,allocatable  :: Bph(:,:)

  double precision              :: EcRPA(nspin)
  double precision,allocatable  :: TAs(:,:),TBs(:,:)
  double precision,allocatable  :: TAt(:,:),TBt(:,:)
  double precision,allocatable  :: OmBSE(:)
  double precision,allocatable  :: XpY_BSE(:,:)
  double precision,allocatable  :: XmY_BSE(:,:)

! Output variables

  double precision,intent(out)  :: EcBSE(nspin)

! Memory allocation

  allocate(Aph(nS,nS),Bph(nS,nS),TAs(nS,nS),TBs(nS,nS),TAt(nS,nS),TBt(nS,nS), & 
           OmBSE(nS),XpY_BSE(nS,nS),XmY_BSE(nS,nS))

!-----!
! TDA !
!-----!

  if(TDA) then
    write(*,*) 'Tamm-Dancoff approximation activated in phBSE!'
    write(*,*)
  end if

!------------------------------------!
! Compute T-matrix for singlet block !
!------------------------------------!

  ispin  = 1

  allocate(Bpp(nVVs,nOOs),Cpp(nVVs,nVVs),Dpp(nOOs,nOOs))

  if(.not.TDA_T) call ppRLR_B(ispin,nOrb,nC,nO,nV,nR,nOOs,nVVs,1d0,ERI,Bpp)
                 call ppRLR_C(ispin,nOrb,nC,nO,nV,nR,nVVs,1d0,eT,ERI,Cpp)
                 call ppRLR_D(ispin,nOrb,nC,nO,nV,nR,nOOs,1d0,eT,ERI,Dpp)

  call ppRLR(TDA_T,nOOs,nVVs,Bpp,Cpp,Dpp,Om1s,X1s,Y1s,Om2s,X2s,Y2s,EcRPA(ispin))

  deallocate(Bpp,Cpp,Dpp)

               call RGTpp_phBSE_static_kernel_A_qs(eta,nOrb,nC,nO,nV,nR,nS,nOOs,nVVs,1d0,eGT,Om1s,rho1s,Om2s,rho2s,TAs)
  if(.not.TDA) call RGTpp_phBSE_static_kernel_B(eta,nOrb,nC,nO,nV,nR,nS,nOOs,nVVs,1d0,Om1s,rho1s,Om2s,rho2s,TBs)

!------------------------------------!
! Compute T-matrix for triplet block !
!------------------------------------!

  ispin  = 2

  allocate(Bpp(nVVt,nOOt),Cpp(nVVt,nVVt),Dpp(nOOt,nOOt))

  if(.not.TDA_T) call ppRLR_B(ispin,nOrb,nC,nO,nV,nR,nOOt,nVVt,1d0,ERI,Bpp)
                 call ppRLR_C(ispin,nOrb,nC,nO,nV,nR,nVVt,1d0,eT,ERI,Cpp)
                 call ppRLR_D(ispin,nOrb,nC,nO,nV,nR,nOOt,1d0,eT,ERI,Dpp)

  call ppRLR(TDA_T,nOOt,nVVt,Bpp,Cpp,Dpp,Om1t,X1t,Y1t,Om2t,X2t,Y2t,EcRPA(ispin))

  deallocate(Bpp,Cpp,Dpp)

               call RGTpp_phBSE_static_kernel_A_qs(eta,nOrb,nC,nO,nV,nR,nS,nOOt,nVVt,1d0,eGT,Om1t,rho1t,Om2t,rho2t,TAt)
  if(.not.TDA) call RGTpp_phBSE_static_kernel_B(eta,nOrb,nC,nO,nV,nR,nS,nOOt,nVVt,1d0,Om1t,rho1t,Om2t,rho2t,TBt)

!------------------!
! Singlet manifold !
!------------------!

 if(singlet) then

    ispin = 1

    ! Compute BSE singlet excitation energies

                 call phRLR_A(ispin,dRPA,nOrb,nC,nO,nV,nR,nS,1d0,eGT,ERI,Aph)
    if(.not.TDA) call phRLR_B(ispin,dRPA,nOrb,nC,nO,nV,nR,nS,1d0,ERI,Bph)

                 Aph(:,:) = Aph(:,:) + TAt(:,:) ! TAt(:,:)
    if(.not.TDA) Bph(:,:) = Bph(:,:) + TBt(:,:) ! TBt(:,:)

    call phRLR(TDA,nS,Aph,Bph,EcBSE(ispin),OmBSE,XpY_BSE,XmY_BSE)

    call print_excitation_energies('phBSE@GTpp','singlet',nS,OmBSE)
    call phLR_transition_vectors(.true.,nOrb,nC,nO,nV,nR,nS,dipole_int,OmBSE,XpY_BSE,XmY_BSE)

  end if

!------------------!
! Triplet manifold !
!------------------!

 if(triplet) then

    ispin = 2

    ! Compute BSE triplet excitation energies

                 call phRLR_A(ispin,dRPA,nOrb,nC,nO,nV,nR,nS,1d0,eGT,ERI,Aph)
    if(.not.TDA) call phRLR_B(ispin,dRPA,nOrb,nC,nO,nV,nR,nS,1d0,ERI,Bph)

                 Aph(:,:) = Aph(:,:) + 1d0*TAt(:,:) - TAs(:,:)
    if(.not.TDA) Bph(:,:) = Bph(:,:) + 1d0*TBt(:,:) - TBs(:,:)

    call phRLR(TDA,nS,Aph,Bph,EcBSE(ispin),OmBSE,XpY_BSE,XmY_BSE)

    call print_excitation_energies('phBSE@GTpp','triplet',nS,OmBSE)
    call phLR_transition_vectors(.false.,nOrb,nC,nO,nV,nR,nS,dipole_int,OmBSE,XpY_BSE,XmY_BSE)

  end if

  if(exchange_kernel) then

    EcBSE(1) = 0.5d0*EcBSE(1)
    EcBSE(2) = 1.5d0*EcBSE(1)

  end if

end subroutine RGTpp_phBSE_qs

subroutine RGTpp_phBSE_static_kernel_A_qs(eta,nBas,nC,nO,nV,nR,nS,nOO,nVV,lambda,eGT,Omega1,rho1,Omega2,rho2,KA)

! Compute the OOVV block of the static T-matrix

  implicit none
  include 'parameters.h'

! Input variables

  double precision,intent(in)   :: eta
  integer,intent(in)            :: nBas
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nS
  integer,intent(in)            :: nOO
  integer,intent(in)            :: nVV
  double precision,intent(in)   :: lambda
  double precision,intent(in)   :: eGT(nBas)
  double precision,intent(in)   :: Omega1(nVV)
  double precision,intent(in)   :: rho1(nBas,nBas,nVV)
  double precision,intent(in)   :: Omega2(nOO)
  double precision,intent(in)   :: rho2(nBas,nBas,nOO)

! Local variables

  double precision              :: dem
  double precision              :: num
  integer                       :: i,j,a,b,ia,jb,kl,cd,c,d

! Output variables

  double precision,intent(out)  :: KA(nS,nS)

  KA(:,:) = 0d0

  jb = 0
!$omp parallel do default(private) shared(KA,Omega1,Omega2,rho1,rho2,eGT,nO,nBas,nVV,nOO,dem,num,eta,nC,nR,lambda)
  do j=nC+1,nO
    do b=nO+1,nBas-nR
      jb = (b-nO) + (j-1)*(nBas-nO) 

      ia = 0
      do i=nC+1,nO
        do a=nO+1,nBas-nR
          ia = (a-nO) + (i-1)*(nBas-nO) 

          do cd=1,nVV
            num = rho1(i,b,cd)*rho1(a,j,cd)
             
            dem = eGT(a) + eGT(j) - Omega1(cd)
            KA(ia,jb) = KA(ia,jb) + num*dem/(dem**2 + eta**2)
             
            dem = eGT(b) + eGT(i) - Omega1(cd)
            KA(ia,jb) = KA(ia,jb) + num*dem/(dem**2 + eta**2)

          end do

          do kl=1,nOO
            num = rho2(i,b,kl)*rho2(a,j,kl)
             
            dem = - eGT(a) - eGT(j) + Omega2(kl)
            KA(ia,jb) = KA(ia,jb) + num*dem/(dem**2 + eta**2)
             
            dem = - eGT(i) - eGT(b) + Omega2(kl)
            KA(ia,jb) = KA(ia,jb) + num*dem/(dem**2 + eta**2)
            
         end do
         
        end do
      end do
    end do
  end do

!$omp end parallel do

end subroutine 
