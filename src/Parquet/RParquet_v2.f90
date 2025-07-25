subroutine RParquet_v2(TDAeh,TDApp,max_diis_1b,max_diis_2b,linearize,eta_1b,eta_2b,ENuc,max_it_1b,conv_1b,max_it_2b,conv_2b, & 
                       nOrb,nC,nO,nV,nR,nS,ERHF,eHF,ERI)

! Parquet approximation based on restricted orbitals

  implicit none
  include 'parameters.h'

! Hard-coded parameters

  logical                       :: print_phLR = .false.
  logical                       :: print_ppLR = .false.
  
! Input variables

  logical,intent(in)            :: TDAeh     
  logical,intent(in)            :: TDApp     
  integer,intent(in)            :: max_diis_1b
  integer,intent(in)            :: max_diis_2b
  logical,intent(in)            :: linearize 
  double precision,intent(in)   :: eta_1b,eta_2b
  double precision,intent(in)   :: ENuc
  double precision,intent(in)   :: ERHF
  integer,intent(in)            :: max_it_1b,max_it_2b
  double precision,intent(in)   :: conv_1b,conv_2b
  integer,intent(in)            :: nOrb,nC,nO,nV,nR,nS
  double precision,intent(in)   :: eHF(nOrb)
  double precision,intent(in)   :: ERI(nOrb,nOrb,nOrb,nOrb)
  
! Local variables

  integer                       :: ispin
  double precision              :: alpha

  integer                       :: n_it_1b,n_it_2b
  double precision              :: err_1b,err_2b
  double precision              :: err_eig_eh_sing,err_eig_eh_trip
  double precision              :: err_eig_hh_sing,err_eig_hh_trip
  double precision              :: err_eig_ee_sing,err_eig_ee_trip
  double precision              :: err_eh_sing, err_eh_trip
  double precision              :: err_ee_sing, err_ee_trip
  double precision              :: err_hh_sing, err_hh_trip
  double precision              :: start_t, end_t, t
  double precision              :: start_1b, end_1b, t_1b
  double precision              :: start_2b, end_2b, t_2b

  integer                       :: nOOs,nOOt
  integer                       :: nVVs,nVVt

  ! eh BSE
  double precision              :: Ec_eh(nspin)
  double precision,allocatable  :: Aph(:,:), Bph(:,:)
  double precision,allocatable  :: sing_XpY(:,:),trip_XpY(:,:)
  double precision,allocatable  :: sing_XmY(:,:),trip_XmY(:,:)
  double precision,allocatable  :: eh_sing_Om(:), old_eh_sing_Om(:)
  double precision,allocatable  :: eh_trip_Om(:), old_eh_trip_Om(:)
  double precision,allocatable  :: eh_sing_Gam_A(:,:),eh_sing_Gam_B(:,:)
  double precision,allocatable  :: eh_trip_Gam_A(:,:),eh_trip_Gam_B(:,:)

  ! pp BSE
  double precision              :: Ec_pp(nspin)
  double precision,allocatable  :: Bpp(:,:),Cpp(:,:),Dpp(:,:)
  double precision,allocatable  :: X1s(:,:),X1t(:,:)
  double precision,allocatable  :: Y1s(:,:),Y1t(:,:)
  double precision,allocatable  :: ee_sing_Om(:),old_ee_sing_Om(:)
  double precision,allocatable  :: ee_trip_Om(:),old_ee_trip_Om(:)
  double precision,allocatable  :: X2s(:,:),X2t(:,:)
  double precision,allocatable  :: Y2s(:,:),Y2t(:,:)
  double precision,allocatable  :: hh_sing_Om(:), old_hh_sing_Om(:)
  double precision,allocatable  :: hh_trip_Om(:), old_hh_trip_Om(:)
  double precision,allocatable  :: pp_sing_Gam_B(:,:),pp_sing_Gam_C(:,:),pp_sing_Gam_D(:,:)
  double precision,allocatable  :: pp_trip_Gam_B(:,:),pp_trip_Gam_C(:,:),pp_trip_Gam_D(:,:)
  ! Effective integrals
  double precision,allocatable  :: eh_sing_rho(:,:,:),eh_trip_rho(:,:,:)
  double precision,allocatable  :: ee_sing_rho(:,:,:),hh_sing_rho(:,:,:)
  double precision,allocatable  :: ee_trip_rho(:,:,:),hh_trip_rho(:,:,:)
  double precision,allocatable  :: old_eh_sing_rho(:,:,:),old_eh_trip_rho(:,:,:)
  double precision,allocatable  :: old_ee_sing_rho(:,:,:),old_hh_sing_rho(:,:,:)
  double precision,allocatable  :: old_ee_trip_rho(:,:,:),old_hh_trip_rho(:,:,:)
  ! Reducible kernels
  double precision,allocatable  :: eh_sing_Phi(:,:,:,:), eh_trip_Phi(:,:,:,:)
  double precision,allocatable  :: old_eh_sing_Phi(:,:,:,:), old_eh_trip_Phi(:,:,:,:)
  double precision,allocatable  :: pp_sing_Phi(:,:,:,:), pp_trip_Phi(:,:,:,:)
  double precision,allocatable  :: old_pp_sing_Phi(:,:,:,:), old_pp_trip_Phi(:,:,:,:)
  ! One-body quantities
  double precision,allocatable  :: eQPlin(:),eQP(:),eOld(:)
  double precision,allocatable  :: SigC(:)
  double precision,allocatable  :: Z(:)
  double precision              :: EcGM

  double precision              :: mem = 0d0
  double precision              :: dp_in_GB = 8d0/(1024d0**3)

! DIIS
  integer                       :: n_diis_1b,n_diis_2b
  double precision              :: rcond_1b,rcond_2b
  double precision,allocatable  :: err_diis_1b(:,:)
  double precision,allocatable  :: err_diis_2b(:,:)
  double precision,allocatable  :: eQP_diis(:,:)
  double precision,allocatable  :: err(:)

  double precision,allocatable  :: rho_diis(:,:)
  double precision,allocatable  :: rho(:)

  integer                       :: p,q,m,pqm
  
! Output variables
! None
    
! Useful parameters

  nOOs = nO*(nO + 1)/2
  nVVs = nV*(nV + 1)/2
  nOOt = nO*(nO - 1)/2
  nVVt = nV*(nV - 1)/2

  allocate(eQP(nOrb),eOld(nOrb))

  mem = mem + size(eQP) + size(eOld)
  write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet = ',mem*dp_in_GB,' GB'
 
! DIIS parameters

  allocate(err_diis_2b(nOrb**4,max_diis_2b),rho_diis(nOrb**4,max_diis_2b))
  allocate(err(nOrb**4),rho(nOrb**4))

  mem = mem + size(err_diis_2b) + size(rho_diis) + size(err) + size(rho)
  write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet =',mem*dp_in_GB,' GB'

  rcond_2b  = 1d0
  n_diis_2b = 0
  err_diis_2b(:,:) = 0d0
  rho_diis(:,:)    = 0d0
 
! Start

  write(*,*)
  write(*,*)'**********************************'
  write(*,*)'* Restricted Parquet Calculation *'
  write(*,*)'**********************************'
  write(*,*)

! Print parameters

  write(*,*)'---------------------------------------------------------------'
  write(*,*)' Parquet parameters for one-body and two-body self-consistency '
  write(*,*)'---------------------------------------------------------------'
  write(*,'(1X,A50,1X,I5)')    'Maximum number of one-body iteration:',max_it_1b
  write(*,'(1X,A50,1X,E10.5)') 'Convergence threshold for one-body energies:',conv_1b
  write(*,'(1X,A50,1X,L5)')    'Linearization of quasiparticle equation?',conv_1b
  write(*,'(1X,A50,1X,E10.5)') 'Strenght of SRG one-body regularization:',eta_1b
  write(*,'(1X,A50,1X,E10.5)') 'Strenght of SRG two-body regularization:',eta_2b
  write(*,'(1X,A50,1X,I5)')    'Maximum length of DIIS expansion:',max_diis_1b
  write(*,*)'---------------------------------------------------------------'
  write(*,'(1X,A50,1X,I5)')    'Maximum number of two-body iteration:',max_it_2b
  write(*,'(1X,A50,1X,E10.5)') 'Convergence threshold for two-body energies:',conv_2b
  write(*,'(1X,A50,1X,L5)')    'TDA for eh excitation energies?',TDAeh
  write(*,'(1X,A50,1X,L5)')    'TDA for pp excitation energies?',TDApp
  write(*,'(1X,A50,1X,I5)')    'Maximum length of DIIS expansion:',max_diis_2b
  write(*,*)'---------------------------------------------------------------'
  write(*,*)
  
! Memory allocation 

  allocate(old_eh_sing_Om(nS),old_eh_trip_Om(nS))
  allocate(old_ee_sing_Om(nVVs),old_hh_sing_Om(nOOs))
  allocate(old_ee_trip_Om(nVVt),old_hh_trip_Om(nOOt))

  allocate(old_eh_sing_rho(nOrb,nOrb,nS),old_eh_trip_rho(nOrb,nOrb,nS))
  allocate(old_ee_sing_rho(nOrb,nOrb,nVVs),old_ee_trip_rho(nOrb,nOrb,nVVt))
  allocate(old_hh_sing_rho(nOrb,nOrb,nOOs),old_hh_trip_rho(nOrb,nOrb,nOOt))

  allocate(old_eh_sing_Phi(nOrb,nOrb,nOrb,nOrb),old_eh_trip_Phi(nOrb,nOrb,nOrb,nOrb))
  allocate(old_pp_sing_Phi(nOrb,nOrb,nOrb,nOrb),old_pp_trip_Phi(nOrb,nOrb,nOrb,nOrb))

! Memory usage

  mem = mem + size(old_eh_sing_Om)  + size(old_eh_trip_Om)  &
            + size(old_ee_sing_Om)  + size(old_hh_sing_Om)  &
            + size(old_ee_trip_Om)  + size(old_hh_trip_Om)  &
            + size(old_eh_sing_rho) + size(old_eh_trip_rho) &
            + size(old_ee_sing_rho) + size(old_hh_sing_rho) &
            + size(old_ee_trip_rho) + size(old_hh_trip_rho) &
            + size(old_eh_sing_Phi) + size(old_eh_trip_Phi) &
            + size(old_pp_sing_Phi) + size(old_pp_trip_Phi)

  write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet = ',mem*dp_in_GB,' GB'

! DIIS for one-body part

  allocate(err_diis_1b(nOrb,max_diis_1b),eQP_diis(nOrb,max_diis_1b))

  mem = mem + size(err_diis_1b) + size(eQP_diis)
  write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet = ',mem*dp_in_GB,' GB'

  rcond_1b  = 1d0
  n_diis_1b = 0
  err_diis_1b(:,:) = 0d0
  eQP_diis(:,:)    = 0d0

! Initialization

  n_it_1b = 0
  err_1b  = 1d0

  eQP(:)  = eHF(:)
  eOld(:) = eHF(:)

  old_eh_sing_rho(:,:,:) = 0d0
  old_eh_trip_rho(:,:,:) = 0d0
  old_ee_sing_rho(:,:,:) = 0d0
  old_ee_trip_rho(:,:,:) = 0d0
  old_hh_sing_rho(:,:,:) = 0d0
  old_hh_trip_rho(:,:,:) = 0d0

  old_eh_sing_Om(:) = 0d0
  old_eh_trip_Om(:) = 0d0
  old_ee_sing_Om(:) = 0d0
  old_ee_trip_Om(:) = 0d0
  old_hh_sing_Om(:) = 0d0
  old_hh_trip_Om(:) = 0d0
  
  old_eh_sing_Phi(:,:,:,:) = 0d0
  old_eh_trip_Phi(:,:,:,:) = 0d0
  old_pp_sing_Phi(:,:,:,:) = 0d0
  old_pp_trip_Phi(:,:,:,:) = 0d0

  !-----------------------------------------!
  ! Main loop for one-body self-consistency !
  !-----------------------------------------!

  do while(err_1b > conv_1b .and. n_it_1b < max_it_1b)

    n_it_1b = n_it_1b + 1
    call wall_time(start_1b)

    write(*,*)
    write(*,*)'====================================='
    write(*,'(1X,A30,1X,I4)') 'One-body iteration #',n_it_1b
    write(*,*)'====================================='
    write(*,*)

    ! DIIS for two-body part

    rcond_2b  = 1d0
    n_diis_2b = 0

    ! Initialization
    
    n_it_2b = 0 
    err_2b  = 1d0
    
    !-----------------------------------------!
    ! Main loop for two-body self-consistency !
    !-----------------------------------------!
    
    do while(err_2b > conv_2b .and. n_it_2b < max_it_2b)

      n_it_2b = n_it_2b + 1
      call wall_time(start_2b)

      write(*,*)' ***********************************'
      write(*,'(1X,A30,1X,I4)') 'Two-body iteration #',n_it_2b
      write(*,*)' ***********************************'
      write(*,*)

      !-----------------!
      ! Density channel !
      !-----------------!

      write(*,*) 'Diagonalizing singlet ehBSE problem (density channel)...'

      allocate(Aph(nS,nS),Bph(nS,nS),eh_sing_Om(nS),sing_XpY(nS,nS),sing_XmY(nS,nS),eh_sing_Gam_A(nS,nS),eh_sing_Gam_B(nS,nS))

      mem = mem + size(Aph) + size(Bph) & 
                + size(eh_sing_Om) + size(sing_XpY) & 
                + size(sing_XmY) + size(eh_sing_Gam_A) + size(eh_sing_Gam_B)
      write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet =',mem*dp_in_GB,' GB'

      ispin = 1
      Aph(:,:) = 0d0
      Bph(:,:) = 0d0

      call wall_time(start_t)

                     call phRLR_A(ispin,.false.,nOrb,nC,nO,nV,nR,nS,1d0,eOld,ERI,Aph)
      if(.not.TDAeh) call phRLR_B(ispin,.false.,nOrb,nC,nO,nV,nR,nS,1d0,ERI,Bph)

      if(n_it_1b == 1 .and. n_it_2b == 1) then

        eh_sing_Gam_A(:,:) = 0d0
        eh_sing_Gam_B(:,:) = 0d0

      else

        call R_eh_singlet_Gamma_A(nOrb,nC,nO,nR,nS,                        &
             old_eh_sing_Phi,old_eh_trip_Phi,old_pp_sing_Phi,old_pp_trip_Phi, &
             eh_sing_Gam_A)
       
        if(.not.TDAeh) call R_eh_singlet_Gamma_B(nOrb,nC,nO,nR,nS,                        &
                            old_eh_sing_Phi,old_eh_trip_Phi,old_pp_sing_Phi,old_pp_trip_Phi, & 
                            eh_sing_Gam_B)

      end if
     
      Aph(:,:) = Aph(:,:) + eh_sing_Gam_A(:,:)
      Bph(:,:) = Bph(:,:) + eh_sing_Gam_B(:,:)  
      

      call phRLR(TDAeh,nS,Aph,Bph,Ec_eh(ispin),eh_sing_Om,sing_XpY,sing_XmY)

      call wall_time(end_t)

      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for singlet phBSE problem =',t,' seconds'
      write(*,*)

      if(print_phLR) call print_excitation_energies('phBSE@Parquet','singlet',nS,eh_sing_Om)

      err_eig_eh_sing = maxval(abs(old_eh_sing_Om - eh_sing_Om))

      mem = mem - size(Aph) - size(Bph) - size(eh_sing_Gam_A) - size(eh_sing_Gam_B)
      deallocate(Aph,Bph,eh_sing_Gam_A,eh_sing_Gam_B)

      !------------------!
      ! Magnetic channel !
      !------------------!

      write(*,*) 'Diagonalizing triplet ehBSE problem (magnetic channel)...'

      allocate(Aph(nS,nS),Bph(nS,nS),eh_trip_Om(nS),trip_XpY(nS,nS),trip_XmY(nS,nS),eh_trip_Gam_A(nS,nS),eh_trip_Gam_B(nS,nS))

      mem = mem + size(Aph) + size(Bph) & 
                + size(eh_trip_Om) + size(trip_XpY) + size(trip_XmY) & 
                + size(eh_trip_Gam_A) + size(eh_trip_Gam_B)
      write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet =',mem*dp_in_GB,' GB'

      ispin = 2
      Aph(:,:) = 0d0
      Bph(:,:) = 0d0

      call wall_time(start_t)

                     call phRLR_A(ispin,.false.,nOrb,nC,nO,nV,nR,nS,1d0,eOld,ERI,Aph)
      if(.not.TDAeh) call phRLR_B(ispin,.false.,nOrb,nC,nO,nV,nR,nS,1d0,ERI,Bph)

      if(n_it_1b == 1 .and. n_it_2b == 1) then

        eh_trip_Gam_A(:,:) = 0d0
        eh_trip_Gam_B(:,:) = 0d0

      else

        call R_eh_triplet_Gamma_A(nOrb,nC,nO,nR,nS,                        &
             old_eh_sing_Phi,old_eh_trip_Phi,old_pp_sing_Phi,old_pp_trip_Phi, &
             eh_trip_Gam_A)
       
        if(.not.TDAeh) call R_eh_triplet_Gamma_B(nOrb,nC,nO,nR,nS,                        &
                            old_eh_sing_Phi,old_eh_trip_Phi,old_pp_sing_Phi,old_pp_trip_Phi, & 
                            eh_trip_Gam_B)

      end if
      
      Aph(:,:) = Aph(:,:) + eh_trip_Gam_A(:,:)
      Bph(:,:) = Bph(:,:) + eh_trip_Gam_B(:,:)

      call phRLR(TDAeh,nS,Aph,Bph,Ec_eh(ispin),eh_trip_Om,trip_XpY,trip_XmY)

      call wall_time(end_t)
      t = end_t - start_t

      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for triplet phBSE problem =',t,' seconds'
      write(*,*)

      if(print_phLR) call print_excitation_energies('phBSE@Parquet','triplet',nS,eh_trip_Om)

      err_eig_eh_trip = maxval(abs(old_eh_trip_Om - eh_trip_Om))

      mem = mem - size(Aph) - size(Bph) - size(eh_trip_Gam_A) - size(eh_trip_Gam_B)
      deallocate(Aph,Bph,eh_trip_Gam_A,eh_trip_Gam_B)

      !-----------------!
      ! Singlet channel !
      !-----------------!

      write(*,*) 'Diagonalizing singlet ppBSE problem (singlet channel)...'

      allocate(Bpp(nVVs,nOOs),Cpp(nVVs,nVVs),Dpp(nOOs,nOOs),   &
               ee_sing_Om(nVVs),X1s(nVVs,nVVs),Y1s(nOOs,nVVs), & 
               hh_sing_Om(nOOs),X2s(nVVs,nOOs),Y2s(nOOs,nOOs), &
               pp_sing_Gam_B(nVVs,nOOs),pp_sing_Gam_C(nVVs,nVVs),pp_sing_Gam_D(nOOs,nOOs))

      mem = mem + size(Bpp) + size(Cpp) + size(Dpp)        &
                + size(ee_sing_Om) + size(X1s) + size(Y1s) &
                + size(hh_sing_Om) + size(X2s) + size(Y2s) &
                + size(pp_sing_Gam_B) + size(pp_sing_Gam_C) + size(pp_sing_Gam_D)
      write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet =',mem*dp_in_GB,' GB'


      ispin = 1
      Bpp(:,:) = 0d0
      Cpp(:,:) = 0d0
      Dpp(:,:) = 0d0

      call wall_time(start_t)
      if(.not.TDApp) call ppRLR_B(ispin,nOrb,nC,nO,nV,nR,nOOs,nVVs,1d0,ERI,Bpp)
                     call ppRLR_C(ispin,nOrb,nC,nO,nV,nR,nVVs,1d0,eOld,ERI,Cpp)
                     call ppRLR_D(ispin,nOrb,nC,nO,nV,nR,nOOs,1d0,eOld,ERI,Dpp)

      if(n_it_1b == 1 .and. n_it_2b == 1) then

        pp_sing_Gam_B(:,:) = 0d0
        pp_sing_Gam_C(:,:) = 0d0
        pp_sing_Gam_D(:,:) = 0d0

      else

        if(.not.TDApp) call R_pp_singlet_Gamma_B(nOrb,nC,nO,nR,nOOs,nVVs,old_eh_sing_Phi,old_eh_trip_Phi,pp_sing_Gam_B)
                       call R_pp_singlet_Gamma_C(nOrb,nO,nR,nVVs,old_eh_sing_Phi,old_eh_trip_Phi,pp_sing_Gam_C)
                       call R_pp_singlet_Gamma_D(nOrb,nC,nO,nOOs,old_eh_sing_Phi,old_eh_trip_Phi,pp_sing_Gam_D)

      end if
                   
      Bpp(:,:) = Bpp(:,:) + pp_sing_Gam_B(:,:)
      Cpp(:,:) = Cpp(:,:) + pp_sing_Gam_C(:,:)
      Dpp(:,:) = Dpp(:,:) + pp_sing_Gam_D(:,:)
      
      
      call ppRLR(TDApp,nOOs,nVVs,Bpp,Cpp,Dpp,ee_sing_Om,X1s,Y1s,hh_sing_Om,X2s,Y2s,Ec_pp(ispin))
      call wall_time(end_t)
      t = end_t - start_t

      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for singlet ppBSE =',t,' seconds'
      write(*,*)

      call wall_time(start_t)

      if(print_ppLR) call print_excitation_energies('ppBSE@Parquet','2p (singlets)',nVVs,ee_sing_Om)
      if(print_ppLR) call print_excitation_energies('ppBSE@Parquet','2h (singlets)',nOOs,hh_sing_Om)

      err_eig_ee_sing = maxval(abs(old_ee_sing_Om - ee_sing_Om))
      err_eig_hh_sing = maxval(abs(old_hh_sing_Om - hh_sing_Om))

      mem = mem - size(Bpp) - size(Cpp) - size(Dpp)        &
                - size(pp_sing_Gam_B) - size(pp_sing_Gam_C) - size(pp_sing_Gam_D)
      deallocate(Bpp,Cpp,Dpp,pp_sing_Gam_B,pp_sing_Gam_C,pp_sing_Gam_D)

      !-----------------!
      ! Triplet channel !
      !-----------------!

      write(*,*) 'Diagonalizing triplet ppBSE problem (triplet channel)...'

      allocate(Bpp(nVVt,nOOt),Cpp(nVVt,nVVt),Dpp(nOOt,nOOt),   &
               ee_trip_Om(nVVt),X1t(nVVt,nVVt),Y1t(nOOt,nVVt), & 
               hh_trip_Om(nOOt),X2t(nVVt,nOOt),Y2t(nOOt,nOOt), &
               pp_trip_Gam_B(nVVt,nOOt),pp_trip_Gam_C(nVVt,nVVt),pp_trip_Gam_D(nOOt,nOOt))

      mem = mem + size(Bpp) + size(Cpp) + size(Dpp)        &
                + size(ee_trip_Om) + size(X1t) + size(Y1t) &
                + size(hh_trip_Om) + size(X2t) + size(Y2t) &
                + size(pp_trip_Gam_B) + size(pp_trip_Gam_C) + size(pp_trip_Gam_D)
      write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet =',mem*dp_in_GB,' GB'

      ispin = 2
      Bpp(:,:) = 0d0
      Cpp(:,:) = 0d0
      Dpp(:,:) = 0d0

      call wall_time(start_t)
      if(.not.TDApp) call ppRLR_B(ispin,nOrb,nC,nO,nV,nR,nOOt,nVVt,1d0,ERI,Bpp)
                     call ppRLR_C(ispin,nOrb,nC,nO,nV,nR,nVVt,1d0,eOld,ERI,Cpp)
                     call ppRLR_D(ispin,nOrb,nC,nO,nV,nR,nOOt,1d0,eOld,ERI,Dpp)

      if(n_it_1b == 1 .and. n_it_2b == 1) then

        pp_trip_Gam_B(:,:) = 0d0
        pp_trip_Gam_C(:,:) = 0d0
        pp_trip_Gam_D(:,:) = 0d0

      else

        if(.not.TDApp) call R_pp_triplet_Gamma_B(nOrb,nC,nO,nR,nOOt,nVVt,old_eh_sing_Phi,old_eh_trip_Phi,pp_trip_Gam_B)
                       call R_pp_triplet_Gamma_C(nOrb,nO,nR,nVVt,old_eh_sing_Phi,old_eh_trip_Phi,pp_trip_Gam_C)
                       call R_pp_triplet_Gamma_D(nOrb,nC,nO,nOOt,old_eh_sing_Phi,old_eh_trip_Phi,pp_trip_Gam_D)

      end if
                   
      Bpp(:,:) = Bpp(:,:) + pp_trip_Gam_B(:,:)
      Cpp(:,:) = Cpp(:,:) + pp_trip_Gam_C(:,:)
      Dpp(:,:) = Dpp(:,:) + pp_trip_Gam_D(:,:)
      
      call ppRLR(TDApp,nOOt,nVVt,Bpp,Cpp,Dpp,ee_trip_Om,X1t,Y1t,hh_trip_Om,X2t,Y2t,Ec_pp(ispin))

      call wall_time(end_t)
      t = end_t - start_t

      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for triplet ppBSE problem =',t,' seconds'
      write(*,*)

      if(print_ppLR) call print_excitation_energies('ppBSE@Parquet','2p (triplets)',nVVt,ee_trip_Om)
      if(print_ppLR) call print_excitation_energies('ppBSE@Parquet','2h (triplets)',nOOt,hh_trip_Om)

      err_eig_ee_trip = maxval(abs(old_ee_trip_Om - ee_trip_Om))
      err_eig_hh_trip = maxval(abs(old_hh_trip_Om - hh_trip_Om))

      mem = mem - size(Bpp) - size(Cpp) - size(Dpp)        &
                - size(pp_trip_Gam_B) - size(pp_trip_Gam_C) - size(pp_trip_Gam_D)
      deallocate(Bpp,Cpp,Dpp,pp_trip_Gam_B,pp_trip_Gam_C,pp_trip_Gam_D)

      !----------!
      ! Updating !
      !----------!

      old_eh_sing_Om(:) = eh_sing_Om(:)
      old_eh_trip_Om(:) = eh_trip_Om(:)
      old_ee_sing_Om(:) = ee_sing_Om(:)
      old_ee_trip_Om(:) = ee_trip_Om(:)
      old_hh_sing_Om(:) = hh_sing_Om(:)
      old_hh_trip_Om(:) = hh_trip_Om(:)

      mem = mem - size(eh_sing_Om) - size(eh_trip_Om) & 
                - size(ee_sing_Om) - size(hh_sing_Om) & 
                - size(ee_trip_Om) - size(hh_trip_Om)
      deallocate(eh_sing_Om,eh_trip_Om,ee_sing_Om,hh_sing_Om,ee_trip_Om,hh_trip_Om)

      !----------------------------!
      ! Compute screened integrals !
      !----------------------------!

      ! Memory allocation
      allocate(eh_sing_rho(nOrb,nOrb,nS),eh_trip_rho(nOrb,nOrb,nS))
      allocate(ee_sing_rho(nOrb,nOrb,nVVs),ee_trip_rho(nOrb,nOrb,nVVt))
      allocate(hh_sing_rho(nOrb,nOrb,nOOs),hh_trip_rho(nOrb,nOrb,nOOt))
      
      
      ! Build singlet eh screened integrals
      write(*,*) 'Computing singlet eh screened integrals...'

      call wall_time(start_t)
      call R_eh_singlet_screened_integral(nOrb,nC,nO,nR,nS,ERI,old_eh_sing_Phi,old_eh_trip_Phi,old_pp_sing_Phi,old_pp_trip_Phi, &
                                          sing_XpY,sing_XmY,eh_sing_rho)
      call wall_time(end_t)
      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for singlet eh integrals =',t,' seconds'
      write(*,*)

      ! Done with eigenvectors and kernel
      mem = mem - size(sing_XpY) - size(sing_XmY)
      deallocate(sing_XpY,sing_XmY)
  
      ! Build triplet eh screened integrals
      write(*,*) 'Computing triplet eh screened integrals...'

      call wall_time(start_t)
      call R_eh_triplet_screened_integral(nOrb,nC,nO,nR,nS,ERI,old_eh_sing_Phi,old_eh_trip_Phi,old_pp_sing_Phi,old_pp_trip_Phi, &
                                          trip_XpY,trip_XmY,eh_trip_rho)
      call wall_time(end_t)
      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for triplet eh integrals =',t,' seconds'
      write(*,*)

      ! Done with eigenvectors and kernel
      mem = mem - size(trip_XpY) - size(trip_XmY)
      deallocate(trip_XpY,trip_XmY)
      
      ! Build singlet pp screened integrals
      write(*,*) 'Computing singlet pp screened integrals...'

      call wall_time(start_t)
      call R_pp_singlet_screened_integral(nOrb,nC,nO,nR,nOOs,nVVs,ERI,old_eh_sing_Phi,old_eh_trip_Phi, &
                                          X1s,Y1s,ee_sing_rho,X2s,Y2s,hh_sing_rho)
      call wall_time(end_t)
      t = end_t - start_t
      ! Done with eigenvectors and kernel
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for singlet pp integrals =',t,' seconds'
      write(*,*)

      mem = mem - size(X1s) - size(Y1s) - size(X2s) - size(Y2s)
      deallocate(X1s,Y1s,X2s,Y2s)

      ! Build triplet pp screened integrals
      write(*,*) 'Computing triplet pp screened integrals...'

      call wall_time(start_t)
      call R_pp_triplet_screened_integral(nOrb,nC,nO,nR,nOOt,nVVt,ERI,old_eh_sing_Phi,old_eh_trip_Phi, &
                                          X1t,Y1t,ee_trip_rho,X2t,Y2t,hh_trip_rho)
      call wall_time(end_t)
      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for triplet pp integrals =',t,' seconds'
      write(*,*)

      ! Done with eigenvectors and kernel
      mem = mem - size(X1t) - size(Y1t) - size(X2t) - size(Y2t)
      deallocate(X1t,Y1t,X2t,Y2t)

      !--------------------!
      ! DIIS extrapolation !
      !--------------------!
      
      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nS
            pqm = pqm + 1
            err(pqm) = eh_sing_rho(p,q,m) - old_eh_sing_rho(p,q,m)
            rho(pqm) = eh_sing_rho(p,q,m)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nS
            pqm = pqm + 1
            err(nOrb**2*nS + pqm) = eh_trip_rho(p,q,m) - old_eh_trip_rho(p,q,m)
            rho(nOrb**2*nS + pqm) = eh_trip_rho(p,q,m)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nVVs
            pqm = pqm + 1
            err(nOrb**2*(nS+nS) + pqm) = ee_sing_rho(p,q,m) - old_ee_sing_rho(p,q,m)
            rho(nOrb**2*(nS+nS) + pqm) = ee_sing_rho(p,q,m)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nVVt
            pqm = pqm + 1
            err(nOrb**2*(nS+nS+nVVs) + pqm) = ee_trip_rho(p,q,m) - old_ee_trip_rho(p,q,m)
            rho(nOrb**2*(nS+nS+nVVs) + pqm) = ee_trip_rho(p,q,m)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nOOs
            pqm = pqm + 1
            err(nOrb**2*(nS+nS+nVVs+nVVt) + pqm) = hh_sing_rho(p,q,m) - old_hh_sing_rho(p,q,m)
            rho(nOrb**2*(nS+nS+nVVs+nVVt) + pqm) = hh_sing_rho(p,q,m)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nOOt
            pqm = pqm + 1
            err(nOrb**2*(nS+nS+nVVs+nVVt+nOOs) + pqm) = hh_trip_rho(p,q,m) - old_hh_trip_rho(p,q,m)
            rho(nOrb**2*(nS+nS+nVVs+nVVt+nOOs) + pqm) = hh_trip_rho(p,q,m)
          end do
        end do
      end do
  
      if(max_diis_2b > 1) then 
     
        n_diis_2b = min(n_diis_2b+1,max_diis_2b)
        call DIIS_extrapolation(rcond_2b,nOrb**4,nOrb**4,n_diis_2b,err_diis_2b,rho_diis,err,rho)
     
      end if
  
      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nS  
            pqm = pqm + 1
            eh_sing_rho(p,q,m) = rho(pqm)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nS  
            pqm = pqm + 1
            eh_trip_rho(p,q,m) = rho(nOrb**2*nS + pqm)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nVVs
            pqm = pqm + 1
            ee_sing_rho(p,q,m) = rho(nOrb**2*(nS+nS) + pqm)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nVVt
            pqm = pqm + 1
            ee_trip_rho(p,q,m) = rho(nOrb**2*(nS+nS+nVVs) + pqm)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nOOs
            pqm = pqm + 1
            hh_sing_rho(p,q,m) = rho(nOrb**2*(nS+nS+nVVs+nVVt) + pqm)
          end do
        end do
      end do

      pqm = 0
      do p=1,nOrb
        do q=1,nOrb
          do m=1,nOOt
            pqm = pqm + 1
            hh_trip_rho(p,q,m) = rho(nOrb**2*(nS+nS+nVVs+nVVt+nOOs) + pqm)
          end do
        end do
      end do

!     alpha = 0.25d0
!     eh_sing_rho(:,:,:) = alpha * eh_sing_rho(:,:,:) + (1d0 - alpha) * old_eh_sing_rho(:,:,:)
!     eh_trip_rho(:,:,:) = alpha * eh_trip_rho(:,:,:) + (1d0 - alpha) * old_eh_trip_rho(:,:,:)
!     ee_sing_rho(:,:,:) = alpha * ee_sing_rho(:,:,:) + (1d0 - alpha) * old_ee_sing_rho(:,:,:)
!     ee_trip_rho(:,:,:) = alpha * ee_trip_rho(:,:,:) + (1d0 - alpha) * old_ee_trip_rho(:,:,:)
!     hh_sing_rho(:,:,:) = alpha * hh_sing_rho(:,:,:) + (1d0 - alpha) * old_hh_sing_rho(:,:,:)
!     hh_trip_rho(:,:,:) = alpha * hh_trip_rho(:,:,:) + (1d0 - alpha) * old_hh_trip_rho(:,:,:)

      err_eh_sing = maxval(abs(old_eh_sing_rho - eh_sing_rho))
      err_eh_trip = maxval(abs(old_eh_trip_rho - eh_trip_rho))
      err_ee_sing = maxval(abs(old_ee_sing_rho - ee_sing_rho))
      err_ee_trip = maxval(abs(old_ee_trip_rho - ee_trip_rho))
      err_hh_sing = maxval(abs(old_hh_sing_rho - hh_sing_rho))
      err_hh_trip = maxval(abs(old_hh_trip_rho - hh_trip_rho))

      old_eh_sing_rho(:,:,:) = eh_sing_rho(:,:,:)
      old_eh_trip_rho(:,:,:) = eh_trip_rho(:,:,:)
      old_ee_sing_rho(:,:,:) = ee_sing_rho(:,:,:)
      old_ee_trip_rho(:,:,:) = ee_trip_rho(:,:,:)
      old_hh_sing_rho(:,:,:) = hh_sing_rho(:,:,:)
      old_hh_trip_rho(:,:,:) = hh_trip_rho(:,:,:)

      mem = mem - size(eh_sing_rho) - size(eh_trip_rho) - size(ee_sing_rho) - size(ee_trip_rho) - size(hh_sing_rho) - size(hh_trip_rho)
      deallocate(eh_sing_rho,eh_trip_rho,ee_sing_rho,ee_trip_rho,hh_sing_rho,hh_trip_rho)

      !----------------------------!
      ! Compute reducible kernels  !
      !----------------------------!

      ! Memory allocation
      allocate(eh_sing_Phi(nOrb,nOrb,nOrb,nOrb))
      allocate(eh_trip_Phi(nOrb,nOrb,nOrb,nOrb))
      allocate(pp_sing_Phi(nOrb,nOrb,nOrb,nOrb))
      allocate(pp_trip_Phi(nOrb,nOrb,nOrb,nOrb))

      mem = mem + size(eh_sing_Phi) + size(eh_trip_Phi) + size(pp_sing_Phi) + size(pp_trip_Phi)
      write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet =',mem*dp_in_GB,' GB'

      ! Build singlet eh reducible kernels
      write(*,*) 'Computing singlet eh reducible kernel...'

      call wall_time(start_t)
      call R_eh_singlet_Phi(eta_2b,nOrb,nC,nR,nS,old_eh_sing_Om,old_eh_sing_rho,eh_sing_Phi)
      call wall_time(end_t)
      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for singlet eh reducible kernel =',t,' seconds'
      write(*,*)
      
      ! Build triplet eh reducible kernels
      write(*,*) 'Computing triplet eh reducible kernel...'

      call wall_time(start_t)
      call R_eh_triplet_Phi(eta_2b,nOrb,nC,nR,nS,old_eh_trip_Om,old_eh_trip_rho,eh_trip_Phi)
      call wall_time(end_t)
      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for triplet eh reducible kernel =',t,' seconds'
      write(*,*)
      
      ! Build singlet pp reducible kernels
      write(*,*) 'Computing singlet pp reducible kernel...'

      call wall_time(start_t)
      call R_pp_singlet_Phi(eta_2b,nOrb,nC,nR,nOOs,nVVs,old_ee_sing_Om,old_ee_sing_rho,old_hh_sing_Om,old_hh_sing_rho,pp_sing_Phi)
      call wall_time(end_t)
      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for singlet pp reducible kernel =',t,' seconds'
      write(*,*)
      
      ! Build triplet pp reducible kernels
      write(*,*) 'Computing triplet pp reducible kernel...'
      
      call wall_time(start_t)
      call R_pp_triplet_Phi(eta_2b,nOrb,nC,nR,nOOt,nVVt,old_ee_trip_Om,old_ee_trip_rho,old_hh_trip_Om,old_hh_trip_rho,pp_trip_Phi)
      call wall_time(end_t)
      t = end_t - start_t
      write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for triplet pp reducible kernel =',t,' seconds'
      write(*,*)

!     alpha = 0.25d0
!     eh_sing_Phi(:,:,:,:) = alpha * eh_sing_Phi(:,:,:,:) + (1d0 - alpha) * old_eh_sing_Phi(:,:,:,:)
!     eh_trip_Phi(:,:,:,:) = alpha * eh_trip_Phi(:,:,:,:) + (1d0 - alpha) * old_eh_trip_Phi(:,:,:,:)
!     pp_sing_Phi(:,:,:,:) = alpha * pp_sing_Phi(:,:,:,:) + (1d0 - alpha) * old_pp_sing_Phi(:,:,:,:)
!     pp_trip_Phi(:,:,:,:) = alpha * pp_trip_Phi(:,:,:,:) + (1d0 - alpha) * old_pp_trip_Phi(:,:,:,:)

      old_eh_sing_Phi(:,:,:,:) = eh_sing_Phi(:,:,:,:)
      old_eh_trip_Phi(:,:,:,:) = eh_trip_Phi(:,:,:,:)
      old_pp_sing_Phi(:,:,:,:) = pp_sing_Phi(:,:,:,:)
      old_pp_trip_Phi(:,:,:,:) = pp_trip_Phi(:,:,:,:)

      ! Free memory

      mem = mem - size(eh_sing_Phi) - size(eh_trip_Phi) - size(pp_sing_Phi) - size(pp_trip_Phi)
      deallocate(eh_sing_Phi,eh_trip_Phi,pp_sing_Phi,pp_trip_Phi)

      !--------------------!
      ! DIIS extrapolation !
      !--------------------!

      write(*,*) '------------------------------------------------------'
      write(*,*) '       Two-body (frequency/kernel) convergence        '
      write(*,*) '------------------------------------------------------'
      write(*,'(1X,A30,F10.6,1X,A1,1X,F10.6)')'Error for density  channel = ',err_eig_eh_sing,'/',err_eh_sing
      write(*,'(1X,A30,F10.6,1X,A1,1X,F10.6)')'Error for magnetic channel = ',err_eig_eh_trip,'/',err_eh_trip
      write(*,'(1X,A30,F10.6,1X,A1,1X,F10.6)')'Error for singlet  channel = ',max(err_eig_ee_sing,err_eig_hh_sing),'/',max(err_ee_sing,err_hh_sing)
      write(*,'(1X,A30,F10.6,1X,A1,1X,F10.6)')'Error for triplet  channel = ',max(err_eig_ee_trip,err_eig_hh_trip),'/',max(err_ee_trip,err_hh_trip)
      write(*,*) '------------------------------------------------------'
      write(*,*)

      ! Convergence criteria
      err_2b = max(err_eh_sing,err_eh_trip,err_ee_sing,err_ee_trip,err_hh_sing,err_hh_trip)
       
      call wall_time(end_2b)
      t_2b = end_2b - start_2b
      write(*,'(1X,A44,1X,I4,A2,F9.3,A8)') 'Wall time for two-body iteration #',n_it_2b,' =',t_2b,' seconds'
      write(*,*)

    end do
    !---------------------------------------------!
    ! End main loop for two-body self-consistency !
    !---------------------------------------------!

    ! Did it actually converge?

    if(n_it_2b == max_it_2b) then

      write(*,*)
      write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
      write(*,'(A37,1X,I3,1X,A10)')' Two-body convergence failed  after ',n_it_2b,'iterations'
      write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
      write(*,*)
      !stop

    else

      write(*,*)
      write(*,*)'****************************************************'
      write(*,'(A37,1X,I3,1X,A10)')' Two-body convergence success after ',n_it_2b,'iterations'
      write(*,*)'****************************************************'
      write(*,*)

!     call print_excitation_energies('phBSE@Parquet','singlet',nS,old_eh_sing_Om)
!     call print_excitation_energies('phBSE@Parquet','triplet',nS,old_eh_trip_Om)
!     call print_excitation_energies('ppBSE@Parquet','2p (singlets)',nVVs,old_ee_sing_Om)
!     call print_excitation_energies('ppBSE@Parquet','2h (singlets)',nOOs,old_hh_sing_Om)
!     call print_excitation_energies('ppBSE@Parquet','2p (triplets)',nVVt,old_ee_trip_Om)
!     call print_excitation_energies('ppBSE@Parquet','2h (triplets)',nOOt,old_hh_trip_Om)

    end if

    allocate(eQPlin(nOrb),Z(nOrb),SigC(nOrb)) 

    mem = mem + size(eQPlin) + size(Z) + size(SigC)
    write(*,'(1X,A50,4X,F6.3,A3)') 'Memory usage in RParquet =',mem*dp_in_GB,' GB'

    write(*,*) 'Computing self-energy...'
    write(*,*)

    call wall_time(start_t)
    call R_Parquet_self_energy(eta_1b,nOrb,nC,nO,nV,nR,nS,nOOs,nVVs,nOOt,nVVt,eOld,ERI,  &
                               old_eh_sing_rho,old_eh_sing_Om,old_eh_trip_rho,old_eh_trip_Om, &
                               old_ee_sing_rho,old_ee_sing_Om,old_ee_trip_rho,old_ee_trip_Om, &
                               old_hh_sing_rho,old_hh_sing_Om,old_hh_trip_rho,old_hh_trip_Om, &
                               EcGM,SigC,Z)
    call wall_time(end_t)
    t = end_t - start_t
    write(*,'(1X,A50,1X,F9.3,A8)') 'Wall time for self energy =',t,' seconds'
    write(*,*)

    eQPlin(:) = eHF(:) + Z(:)*SigC(:)

    ! Solve the quasi-particle equation

    if(linearize) then

       write(*,*) ' *** Quasiparticle energies obtained by linearization *** '
       write(*,*)

       eQP(:) = eQPlin(:)

    else

      write(*,*) ' *** Quasiparticle energies obtained by root search *** '
      write(*,*)

      call R_Parquet_QP_graph(eta_1b,nOrb,nC,nO,nV,nR,nS,nOOs,nVVs,nOOt,nVVt,ERI,    &
                              old_eh_sing_rho,old_eh_sing_Om,old_eh_trip_rho,old_eh_trip_Om, &
                              old_ee_sing_rho,old_ee_sing_Om,old_ee_trip_rho,old_ee_trip_Om, &
                              old_hh_sing_rho,old_hh_sing_Om,old_hh_trip_rho,old_hh_trip_Om, &
                              eHF,eQPlin,eOld,eQP,Z)
    end if
   
    ! DIIS for one-body part
   
    if(max_diis_1b > 1) then

      n_diis_1b = min(n_diis_1b+1,max_diis_1b)
      call DIIS_extrapolation(rcond_1b,nOrb,nOrb,n_diis_1b,err_diis_1b,eQP_diis,eQP-eOld,eQP)
  
    end if 

    ! Check one-body converge

    err_1b =  maxval(abs(eOld - eQP))
    eOld(:) = eQP(:)

    ! Print for one-body part

    call R_print_parquet_1b(nOrb,nC,nO,nV,nR,eHF,SigC,eQP,Z,n_it_1b,err_1b,ENuc,ERHF,EcGM,Ec_eh,Ec_pp)

    mem = mem - size(eQPlin) - size(Z) - size(SigC)
    deallocate(eQPlin,Z,SigC)
    
    call wall_time(end_1b)
    t_1b = end_1b - start_1b
    write(*,'(1X,A44,1X,I4,A2,F9.3,A8)') 'Wall time for one-body iteration #',n_it_1b,' =',t_1b,' seconds'
    
  end do 
  !---------------------------------------------!
  ! End main loop for one-body self-consistency !
  !---------------------------------------------!

  ! Did it actually converge?
  if(n_it_1b == max_it_1b) then

    write(*,*)
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,'(A37,1X,I3,1X,A10)')' One-body convergence failed  after ',n_it_1b,'iterations'
    write(*,*)'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    write(*,*)
    stop

  else

    write(*,*)
    write(*,*)'****************************************************'
    write(*,'(A37,1X,I3,1X,A10)')' One-body convergence success after ',n_it_1b,'iterations'
    write(*,*)'****************************************************'
    write(*,*)

  end if
     
end subroutine 
