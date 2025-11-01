subroutine scGWitauiw_ao(nBas,nOrb,nO,maxSCF,dolinGW,restart_scGW,no_fock,ENuc,Hc,S,P_in,cHF,eHF, &
                        nfreqs,wcoord,wweight,vMAT,ERI_AO)

! Restricted scGW

  implicit none
  include 'parameters.h'

! Input variables
 
  logical,intent(in)            :: dolinGW
  logical,intent(in)            :: no_fock
  logical,intent(in)            :: restart_scGW

  integer,intent(in)            :: nBas
  integer,intent(in)            :: nOrb
  integer,intent(in)            :: nO
  integer,intent(in)            :: maxSCF

  double precision,intent(in)   :: ENuc
  double precision,intent(in)   :: Hc(nBas,nBas)
  double precision,intent(in)   :: P_in(nBas,nBas)
  double precision,intent(in)   :: S(nBas,nBas)
  double precision,intent(in)   :: vMAT(nBas*nBas,nBas*nBas)
  double precision,intent(in)   :: ERI_AO(nBas,nBas,nBas,nBas)

! Local variables
 
  logical                       :: file_exists

  integer                       :: iunit=312
  integer                       :: verbose
  integer                       :: nneg
  integer                       :: ntimes
  integer                       :: ntimes_twice
  integer                       :: itau,ifreq
  integer                       :: ibas,jbas,kbas,lbas,nBas2
  integer                       :: iter,iter_fock
  integer                       :: imax_error_sigma
  integer                       :: imax_error_gw2gt

  double precision              :: start_scGWitauiw     ,end_scGWitauiw       ,t_scGWitauiw

  double precision              :: alpha_mixing
  double precision              :: Ehfl,EcGM
  double precision              :: trace1,trace2
  double precision              :: eta,diff_Pao
  double precision              :: nElectrons
  double precision              :: trace_1_rdm
  double precision              :: thrs_N,thrs_Pao
  double precision              :: chem_pot,chem_pot_saved
  double precision              :: error_sigma
  double precision              :: max_error_sigma
  double precision              :: error_gw2gt
  double precision              :: max_error_gw2gt
  double precision              :: sum_error_gw2gt
  double precision,allocatable  :: tweight(:),tcoord(:)
  double precision,allocatable  :: sint2w_weight(:,:)
  double precision,allocatable  :: cost2w_weight(:,:)
  double precision,allocatable  :: cosw2t_weight(:,:)
  double precision,allocatable  :: sinw2t_weight(:,:)
  double precision,allocatable  :: eSD(:)
  double precision,allocatable  :: Occ(:)
  double precision,allocatable  :: Wp_ao_iw(:,:)
  double precision,allocatable  :: cHFinv(:,:)
  double precision,allocatable  :: F_ao(:,:)
  double precision,allocatable  :: U_mo(:,:)
  double precision,allocatable  :: P_ao(:,:)
  double precision,allocatable  :: P_ao_hf(:,:)
  double precision,allocatable  :: P_ao_old(:,:)
  double precision,allocatable  :: P_ao_iter(:,:)
  double precision,allocatable  :: P_mo(:,:)
  double precision,allocatable  :: Wp_ao_itau(:,:,:)

  complex*16                    :: product
  complex*16                    :: weval_cpx
  complex*16,allocatable        :: Sigma_c_w_ao(:,:,:)
  complex*16,allocatable        :: DeltaG_ao_iw(:,:,:)
  complex*16,allocatable        :: G_ao_itau(:,:,:)
  complex*16,allocatable        :: G_ao_itau_old(:,:,:)
  complex*16,allocatable        :: G_ao_itau_hf(:,:,:)
  complex*16,allocatable        :: G_ao_iw_hf(:,:,:)
  complex*16,allocatable        :: Sigma_c_c(:,:),Sigma_c_s(:,:)
  complex*16,allocatable        :: Sigma_c_plus(:,:),Sigma_c_minus(:,:)
  complex*16,allocatable        :: G_ao_1(:,:),G_ao_2(:,:)
  complex*16,allocatable        :: G_minus_itau(:,:),G_plus_itau(:,:)
  complex*16,allocatable        :: Chi0_ao_itau(:,:)
  complex*16,allocatable        :: Chi0_ao_iw(:,:,:)
  complex*16,allocatable        :: error_transf_mo(:,:,:)
  complex*16,allocatable        :: Sigma_c_w_mo(:,:)

! Output variables
  integer,intent(inout)         :: nfreqs
  double precision,intent(inout):: eHF(nOrb)
  double precision,intent(inout):: wcoord(nfreqs)
  double precision,intent(inout):: wweight(nfreqs)
  double precision,intent(inout):: cHF(nBas,nOrb)
  
!------------------------------------------------------------------------
! Build G(i tau) in AO basis and use it to build Xo (i tau) -> Xo (i w) !
!------------------------------------------------------------------------
 
 call wall_time(start_scGWitauiw)

 write(*,*)     
 write(*,*)'*******************************************'
 write(*,*)'*     scGW ( using itau and iw grids )    *'
 write(*,*)'*******************************************'
 write(*,*)

 verbose=0
 eta=0d0
 thrs_N=1d-8
 thrs_Pao=1d-6
 nElectrons=2d0*nO
 nBas2=nBas*nBas
 chem_pot_saved = 0.5d0*(eHF(nO)+eHF(nO+1))
 chem_pot = chem_pot_saved
 alpha_mixing=0.6d0
 Ehfl=0d0
 write(*,*)
 write(*,'(A33,1X,F16.10,A3)') ' Initial chemical potential  = ',chem_pot,' au'
 write(*,*)
 eHF(:) = eHF(:)-chem_pot_saved
   
 allocate(U_mo(nOrb,nOrb))
 allocate(Chi0_ao_iw(nfreqs,nBas2,nBas2))
 allocate(P_ao(nBas,nBas),P_ao_old(nBas,nBas),P_ao_iter(nBas,nBas),P_ao_hf(nBas,nBas))
 allocate(F_ao(nBas,nBas),P_mo(nOrb,nOrb),cHFinv(nOrb,nBas),Occ(nOrb),eSD(nOrb))
 allocate(G_minus_itau(nBas,nBas),G_plus_itau(nBas,nBas)) 
 allocate(G_ao_1(nBas,nBas),G_ao_2(nBas,nBas)) 
 allocate(Sigma_c_c(nBas,nBas),Sigma_c_s(nBas,nBas)) 
 allocate(Sigma_c_plus(nBas,nBas),Sigma_c_minus(nBas,nBas)) 
 allocate(Chi0_ao_itau(nBas2,nBas2),Wp_ao_iw(nBas2,nBas2)) 
 cHFinv=matmul(transpose(cHF),S)
 P_ao_hf=P_in
 P_ao=P_in
 P_ao_iter=P_in
 F_ao=Hc
 Ehfl=0d0
 trace_1_rdm=0d0
 do ibas=1,nBas
  do jbas=1,nBas
   Ehfl=Ehfl+P_ao(ibas,jbas)*Hc(ibas,jbas)
   trace_1_rdm=trace_1_rdm+P_ao(ibas,jbas)*S(ibas,jbas)
   do kbas=1,nBas
    do lbas=1,nBas
     F_ao(ibas,jbas)=F_ao(ibas,jbas)+P_ao(kbas,lbas)*vMAT(1+(lbas-1)+(kbas-1)*nBas,1+(jbas-1)+(ibas-1)*nBas) &
                    -0.5d0*P_ao(kbas,lbas)*vMAT(1+(jbas-1)+(kbas-1)*nBas,1+(lbas-1)+(ibas-1)*nBas)
     Ehfl=Ehfl+0.5d0*P_ao(kbas,lbas)*P_ao(ibas,jbas)*vMAT(1+(lbas-1)+(kbas-1)*nBas,1+(jbas-1)+(ibas-1)*nBas) &
         -0.25d0*P_ao(kbas,lbas)*P_ao(ibas,jbas)*vMAT(1+(jbas-1)+(kbas-1)*nBas,1+(lbas-1)+(ibas-1)*nBas)
    enddo
   enddo
  enddo
 enddo

!-----------------!
! Allocate arrays !
!-----------------!

 ntimes=nfreqs
 ntimes_twice=2*ntimes
 allocate(tweight(ntimes),tcoord(ntimes))
 allocate(sint2w_weight(nfreqs,ntimes))
 allocate(cost2w_weight(nfreqs,ntimes))
 allocate(cosw2t_weight(ntimes,nfreqs))
 allocate(sinw2t_weight(ntimes,nfreqs))
 allocate(Sigma_c_w_ao(nfreqs,nBas,nBas),DeltaG_ao_iw(nfreqs,nBas,nBas),G_ao_iw_hf(nfreqs,nBas,nBas))
 allocate(G_ao_itau(ntimes_twice,nBas,nBas),G_ao_itau_hf(ntimes_twice,nBas,nBas))
 allocate(G_ao_itau_old(ntimes_twice,nBas,nBas))
 allocate(Wp_ao_itau(ntimes,nBas2,nBas2))

!---------------!
! Reading grids !
!---------------!

 call read_scGW_grids(ntimes,nfreqs,tcoord,tweight,wcoord,wweight,sint2w_weight,cost2w_weight, &
                      cosw2t_weight,sinw2t_weight)

!-------------------------------------------------------------------------!
! Test the quality of the grid for the Go(i w) -> G(i tau) transformation !
!-------------------------------------------------------------------------!

 ! Build Go(i w)
 write(*,*)
 write(*,'(a)') ' Error test for the Go(iw) -> G(it) transformation'
 write(*,*)
 do ifreq=1,nfreqs
  weval_cpx=im*wcoord(ifreq)
  call G_AO_RHF(nBas,nOrb,nO,eta,cHF,eHF,weval_cpx,G_ao_1)
  DeltaG_ao_iw(ifreq,:,:)=G_ao_1(:,:)
 enddo
 ! Fourier transform Go(i w) -> Go(i tau)
 G_ao_itau=czero
 do itau=1,ntimes
  G_plus_itau(:,:)=czero
  G_minus_itau(:,:)=czero
  do ifreq=1,nfreqs
   G_plus_itau(:,:) = G_plus_itau(:,:)   + im*cosw2t_weight(itau,ifreq)*Real(DeltaG_ao_iw(ifreq,:,:))  &
                                         - im*sinw2t_weight(itau,ifreq)*Aimag(DeltaG_ao_iw(ifreq,:,:)) 
   G_minus_itau(:,:) = G_minus_itau(:,:) + im*cosw2t_weight(itau,ifreq)*Real(DeltaG_ao_iw(ifreq,:,:))  &
                                         + im*sinw2t_weight(itau,ifreq)*Aimag(DeltaG_ao_iw(ifreq,:,:)) 
  enddo
  G_ao_itau(2*itau-1,:,:)=G_plus_itau(:,:) 
  G_ao_itau(2*itau  ,:,:)=G_minus_itau(:,:)
 enddo
 ! Check the error
 max_error_gw2gt=-1d0
 sum_error_gw2gt=0d0
 imax_error_gw2gt=1
 do itau=1,ntimes
  call G0itau_ao_RHF(nBas,nOrb,nO, tcoord(itau),G_plus_itau ,cHF,eHF)
  call G0itau_ao_RHF(nBas,nOrb,nO,-tcoord(itau),G_minus_itau,cHF,eHF)
  if(verbose/=0) then
   write(*,'(a,*(f20.8))') ' Fourier  ',im*tcoord(itau)
   do ibas=1,nBas
    write(*,'(*(f20.8))') G_ao_itau(2*itau-1,ibas,:)
   enddo
   write(*,'(a,*(f20.8))') ' Fourier  ',-im*tcoord(itau)
   do ibas=1,nBas
    write(*,'(*(f20.8))') G_ao_itau(2*itau  ,ibas,:)
   enddo
   write(*,'(a,*(f20.8))') ' Analytic  ',im*tcoord(itau)
   do ibas=1,nBas
    write(*,'(*(f20.8))') G_plus_itau(ibas,:)
   enddo
   write(*,'(a,*(f20.8))') ' Analytic  ',-im*tcoord(itau)
   do ibas=1,nBas
    write(*,'(*(f20.8))') G_minus_itau(ibas,:)
   enddo
  endif
  G_plus_itau(:,:) =abs(G_plus_itau(:,:) -G_ao_itau(2*itau-1,:,:))
  G_minus_itau(:,:)=abs(G_minus_itau(:,:)-G_ao_itau(2*itau  ,:,:))
  error_gw2gt=real(sum(G_plus_itau(:,:)))+real(sum(G_minus_itau(:,:)))
  sum_error_gw2gt=sum_error_gw2gt+error_gw2gt
  if(error_gw2gt>max_error_gw2gt) then
   imax_error_gw2gt=itau
   max_error_gw2gt=error_gw2gt
  endif
 enddo
 write(*,'(a,*(f20.8))') ' Sum error ',sum_error_gw2gt
 write(*,'(a,f20.8,a,2f20.8,a)') ' Max CAE   ',max_error_gw2gt,' is in the time +/-',0d0,tcoord(imax_error_gw2gt),'i'
 write(*,'(a,*(f20.8))') ' MAE       ',sum_error_gw2gt/(nfreqs*nBas*nBas)
 ! Reset to 0.0
 DeltaG_ao_iw=czero
 G_ao_itau=czero

!-----------!
! scGW loop !
!-----------!

 iter=0
 iter_fock=0
 do
  iter=iter+1

  ! For iter=1 we build G_ao_itau as the RHF one or read it from restart files
  ! [ we also initialize G_ao_iw_hf, G_ao_itau_hf, G_ao_itau_old, and (P_ao,P_ao_iter) ]
  if(iter==1) then
   G_ao_itau=czero
   do itau=1,ntimes
    call G0itau_ao_RHF(nBas,nOrb,nO, tcoord(itau),G_plus_itau ,cHF,eHF)
    call G0itau_ao_RHF(nBas,nOrb,nO,-tcoord(itau),G_minus_itau,cHF,eHF)
    G_ao_itau(2*itau-1,:,:)=G_plus_itau(:,:)
    G_ao_itau(2*itau  ,:,:)=G_minus_itau(:,:)
   enddo
   G_ao_itau_old(:,:,:)=G_ao_itau(:,:,:)
   G_ao_itau_hf(:,:,:)=G_ao_itau(:,:,:)
   do ifreq=1,nfreqs
    weval_cpx=im*wcoord(ifreq)
    call G_AO_RHF(nBas,nOrb,nO,eta,cHF,eHF,weval_cpx,G_ao_1)
    G_ao_iw_hf(ifreq,:,:)=G_ao_1(:,:)
   enddo
   ! Initialize DeltaG(i w) [ it will be G(i w) - Go(i w) ]
   DeltaG_ao_iw(:,:,:)=czero
   ! If required, read the restart files
   if(restart_scGW) then
    call read_scGW_restart(nBas,ntimes_twice,chem_pot,P_ao,G_ao_itau)
    P_ao_iter=P_ao
    G_ao_itau_old(:,:,:)=G_ao_itau(:,:,:)
   endif
  endif

  ! Build using the time grid Xo(i tau) = -2i G(i tau) G(-i tau)
  !  then Fourier transform Xo(i tau) -> Xo(i w)
  Chi0_ao_iw(:,:,:)=czero
  do itau=1,ntimes
   ! Xo(i tau) = -2i G(i tau) G(-i tau)
   do ibas=1,nBas
    do jbas=1,nBas
     do kbas=1,nBas
      do lbas=1,nBas                       
                                   ! r1   r2'                    r2   r1'
       product = G_ao_itau(2*itau-1,ibas,jbas)*G_ao_itau(2*itau,kbas,lbas)
       if(abs(product)<1e-12) product=czero
       Chi0_ao_itau(1+(lbas-1)+(ibas-1)*nBas,1+(kbas-1)+(jbas-1)*nBas) = product
      enddo
     enddo
    enddo
   enddo
   Chi0_ao_itau=-2d0*im*Chi0_ao_itau ! The 2 factor is added to account for both spin contributions [ i.e., (up,up,up,up) and (down,down,down,down) ]
   ! Xo(i tau) -> Xo(i w) [ the weight already contains the cos(tau w) and a factor 2 because int_-Infty ^Infty -> 2 int_0 ^Infty ]
   do ifreq=1,nfreqs
    Chi0_ao_iw(ifreq,:,:) = Chi0_ao_iw(ifreq,:,:) - im*cost2w_weight(ifreq,itau)*Chi0_ao_itau(:,:)
   enddo 
  enddo
  ! Complete the Xo(i tau) -> Xo(i w)
  Chi0_ao_iw(:,:,:) = Real(Chi0_ao_iw(:,:,:)) ! The factor 2 is stored in the weight [ and we just retain the real part ]

  ! Build Wp(i w) and compute Ec Galitskii-Migdal 
  !  and Wp(i w) -> Wp(i tau)
  EcGM=0d0
  Wp_ao_itau=0d0
  do ifreq=1,nfreqs
   trace1=0d0; trace2=0d0;
   ! Xo(i w) -> Wp_ao_iw(i w)
   Wp_ao_iw(:,:)=-matmul(Real(Chi0_ao_iw(ifreq,:,:)),vMAT(:,:))  
   do ibas=1,nBas2
    trace1=trace1+Wp_ao_iw(ibas,ibas)
    Wp_ao_iw(ibas,ibas)=Wp_ao_iw(ibas,ibas)+1d0
   enddo
   call inverse_matrix(nBas2,Wp_ao_iw,Wp_ao_iw)
   Wp_ao_iw(:,:)=matmul(Wp_ao_iw(:,:),Real(Chi0_ao_iw(ifreq,:,:)))
   Wp_ao_iw(:,:)=matmul(Wp_ao_iw(:,:),vMAT(:,:))
   do ibas=1,nBas2
    trace2=trace2+Wp_ao_iw(ibas,ibas)
   enddo
   EcGM=EcGM-wweight(ifreq)*(trace2+trace1)/(2d0*pi) ! iw contribution to EcGM
   Wp_ao_iw(:,:)=matmul(vMAT(:,:),Wp_ao_iw(:,:))     ! Now Wp_ao_iw is on the iw grid
   ! Wp(i w) -> Wp(i tau) [ this transformation misses that Fourier[ Wp(i tau) ] is imaginary because of the factor i / 2pi ]
   !                      [ However, the weight contains a 2 /(2 pi) = 1 / pi factor and the cos(tau w).                    ]
   do itau=1,ntimes
    Wp_ao_itau(itau,:,:) = Wp_ao_itau(itau,:,:) + cosw2t_weight(itau,ifreq)*Wp_ao_iw(:,:)
   enddo
  enddo

  ! Build Sigma_c(i w)
  Sigma_c_w_ao=czero
  do itau=1,ntimes
   G_plus_itau(:,:) =G_ao_itau(2*itau-1,:,:)
   G_minus_itau(:,:)=G_ao_itau(2*itau  ,:,:)
   Sigma_c_plus=czero
   Sigma_c_minus=czero
   ! Sigma_c(i tau) = i G(i tau) Wp(i tau)
   do ibas=1,nBas
    do jbas=1,nBas
     do kbas=1,nBas
      do lbas=1,nBas 
       Sigma_c_plus(ibas,jbas) =Sigma_c_plus(ibas,jbas)+im*G_plus_itau(kbas,lbas)    &
                               *im*Wp_ao_itau(itau,1+(kbas-1)+(ibas-1)*nBas,1+(jbas-1)+(lbas-1)*nBas) ! Adding i to Wp that was missing
       Sigma_c_minus(ibas,jbas)=Sigma_c_minus(ibas,jbas)+im*G_minus_itau(kbas,lbas)  &
                               *im*Wp_ao_itau(itau,1+(kbas-1)+(ibas-1)*nBas,1+(jbas-1)+(lbas-1)*nBas) ! Adding i to Wp that was missing
      enddo
     enddo
    enddo
   enddo
   Sigma_c_c= -im*(Sigma_c_plus+Sigma_c_minus)
   Sigma_c_s= -   (Sigma_c_plus-Sigma_c_minus)
   ! Sigma_c(i tau) -> Sigma_c(i w)
   do ifreq=1,nfreqs
    Sigma_c_w_ao(ifreq,:,:) = Sigma_c_w_ao(ifreq,:,:)                        &
                            + 0.5d0*cost2w_weight(ifreq,itau)*Sigma_c_c(:,:) &
                            + 0.5d0*sint2w_weight(ifreq,itau)*Sigma_c_s(:,:)
   enddo 
  enddo

  ! Check the error in Sigma_c(i w) at iter=1 and this is calc. is not with restart
  if(iter==1 .and. .not.restart_scGW) then
   write(*,*)
   write(*,'(a)') ' Error test for the Sigma_c(iw) construction at iter 1 [ compared with the analytic Sigma_c(iw) obtained from HF ] '
   write(*,*)
   max_error_sigma=-1d0;imax_error_sigma=1;
   allocate(error_transf_mo(nfreqs,nOrb,nOrb),Sigma_c_w_mo(nOrb,nOrb))
   ! Build the analytic Sigma_c(iw)
   call build_analityc_rhf_Sigma_c_iw(nBas,nOrb,nO,verbose,cHF,eHF,nfreqs,wcoord,ERI_AO,error_transf_mo) ! error_transf_mo set to Sigma_c_mo(iw)
   do ifreq=1,nfreqs
    Sigma_c_w_mo=matmul(matmul(transpose(cHF(:,:)),Sigma_c_w_ao(ifreq,:,:)),cHF(:,:)) ! Fourier: Sigma_c_ao(iw) -> Sigma_c_mo(iw)
    !Sigma_c_w_ao(ifreq,:,:)=matmul(transpose(cHFinv),matmul(error_transf_mo(ifreq,:,:),cHFinv)) ! Analytic: Sigma_c_mo(iw) -> Sigma_c_ao(iw)
    if(verbose/=0) then
     write(*,'(a,*(f20.8))') ' Fourier  ',im*wcoord(ifreq)
     do ibas=1,nOrb
      write(*,'(*(f20.8))') Sigma_c_w_mo(ibas,:)
     enddo
    endif
    error_transf_mo(ifreq,:,:)=abs(error_transf_mo(ifreq,:,:)-Sigma_c_w_mo(:,:))
    error_sigma=real(sum(error_transf_mo(ifreq,:,:)))
    if(error_sigma>max_error_sigma) then
     imax_error_sigma=ifreq
     max_error_sigma=error_sigma
    endif
   enddo
   write(*,'(a,*(f20.8))') ' Sum error ',sum(error_transf_mo)
   write(*,'(a,f20.8,a,2f20.8,a)') ' Max CAE   ',max_error_sigma,' is in the frequency ',0d0,wcoord(imax_error_sigma),'i'
   write(*,'(a,*(f20.8))') ' MAE       ',sum(error_transf_mo)/(nfreqs*nBas*nBas)
   deallocate(error_transf_mo,Sigma_c_w_mo)
  endif

  ! Converge with respect to the Fock operator (using only good P_ao matrices)
  if(.not.no_fock) then ! Skiiping the opt w.r.t. the Fock operator we will just do linearized approximation on Go -> [ lin-G = Go + Go Sigma Go ]
   iter_fock=0
   do
    ! Build F
    iter_fock=iter_fock+1
    F_ao=Hc
    Ehfl=0d0
    do ibas=1,nBas
     do jbas=1,nBas
      Ehfl=Ehfl+P_ao(ibas,jbas)*Hc(ibas,jbas)
      do kbas=1,nBas
       do lbas=1,nBas
        F_ao(ibas,jbas)=F_ao(ibas,jbas)+P_ao(kbas,lbas)*vMAT(1+(lbas-1)+(kbas-1)*nBas,1+(jbas-1)+(ibas-1)*nBas) &
                       -0.5d0*P_ao(kbas,lbas)*vMAT(1+(jbas-1)+(kbas-1)*nBas,1+(lbas-1)+(ibas-1)*nBas)
        Ehfl=Ehfl+0.5d0*P_ao(kbas,lbas)*P_ao(ibas,jbas)*vMAT(1+(lbas-1)+(kbas-1)*nBas,1+(jbas-1)+(ibas-1)*nBas) &
            -0.25d0*P_ao(kbas,lbas)*P_ao(ibas,jbas)*vMAT(1+(jbas-1)+(kbas-1)*nBas,1+(lbas-1)+(ibas-1)*nBas)
       enddo
      enddo
     enddo
    enddo
    ! Build G(i w) and n(r)
    P_ao_old=P_ao
    call get_1rdm_scGW(nBas,nfreqs,nElectrons,thrs_N,chem_pot,S,F_ao,Sigma_c_w_ao,wcoord,wweight, &
                       G_ao_1,G_ao_iw_hf,DeltaG_ao_iw,P_ao,P_ao_hf,trace_1_rdm) 
    if(abs(trace_1_rdm-nElectrons)>thrs_N) &
     call fix_chem_pot_scGW(nBas,nfreqs,nElectrons,thrs_N,chem_pot,S,F_ao,Sigma_c_w_ao,wcoord,wweight, &
                           G_ao_1,G_ao_iw_hf,DeltaG_ao_iw,P_ao,P_ao_hf,trace_1_rdm)
    ! Check convergence of P_ao for fixed Sigma_c(i w)
    diff_Pao=0d0
    do ibas=1,nBas
     do jbas=1,nBas
      diff_Pao=diff_Pao+abs(P_ao(ibas,jbas)-P_ao_old(ibas,jbas))
     enddo
    enddo

    if(diff_Pao<=thrs_Pao) exit
   
    if(iter_fock==maxSCF) exit
   
   enddo
  endif

  ! Check convergence of P_ao after a scGW iteration
  diff_Pao=0d0
  do ibas=1,nBas
   do jbas=1,nBas
    diff_Pao=diff_Pao+abs(P_ao(ibas,jbas)-P_ao_iter(ibas,jbas))
   enddo
  enddo
  P_ao_iter=P_ao

  ! Print iter info
  P_mo=-matmul(matmul(cHFinv,P_ao),transpose(cHFinv)) ! Minus to order occ numbers
  call diagonalize_matrix(nOrb,P_mo,Occ)
  write(*,*)
  write(*,'(a,f15.8,a,i5,a,i5)') ' Trace scGW  ',trace_1_rdm,' after ',iter_fock,' Fock iterations at global iter ',iter
  write(*,'(a,f15.8)')        ' Change of P ',diff_Pao
  write(*,'(a,f15.8)')        ' Chem. Pot.  ',chem_pot
  write(*,'(a,f15.8)')        ' EcGM        ',EcGM
  write(*,'(a,f15.8)')        ' Eelec       ',Ehfl+EcGM
  write(*,'(a,f15.8)')        ' Etot        ',Ehfl+EcGM+ENuc
  write(*,*)
  write(*,*) ' Occupation numbers'
  Occ=-Occ
  do ibas=1,nOrb
   write(*,'(I7,F15.8)') ibas,Occ(ibas)
  enddo

  if(diff_Pao<=thrs_Pao) exit

  if(iter==maxSCF) exit
  
  ! Build the new G_ao_iw_hf, G_ao_itau_hf, and P_ao_hf
  U_mo=matmul(transpose(cHF),matmul(F_ao,cHF))
  call diagonalize_matrix(nOrb,U_mo,eSD)
  eSD(:)=eSD(:)-chem_pot
  nneg=0
  do ibas=1,nOrb
   if(eSD(ibas)<0d0) nneg=nneg+1
  enddo
  write(*,*) ' SD energies [ from Go(iw) ] (a.u.)'
  do ibas=1,nOrb
   write(*,'(I7,F15.8)') ibas,eSD(ibas)
  enddo
  if(nneg==nO .and. .false.) then
   write(*,*)
   write(*,'(a,i5)') ' Computing new Go(iw), Go(it), and P_HF matrices at global iter ',iter
   write(*,*)
   ! Compute new MO coefs
   cHF=matmul(cHF,U_mo)
   cHFinv=matmul(transpose(cHF),S)
   ! New P_ao_hf
   P_ao_hf(:,:) = 2d0*matmul(cHF(:,1:nO),transpose(cHF(:,1:nO)))
   ! New G_ao_itau_hf
   G_ao_itau_hf=czero
   do itau=1,ntimes
    call G0itau_ao_RHF(nBas,nOrb,nO, tcoord(itau),G_plus_itau ,cHF,eSD)
    call G0itau_ao_RHF(nBas,nOrb,nO,-tcoord(itau),G_minus_itau,cHF,eSD)
    G_ao_itau_hf(2*itau-1,:,:)=G_plus_itau(:,:)
    G_ao_itau_hf(2*itau  ,:,:)=G_minus_itau(:,:)
   enddo
   ! New G_ao_iw_hf [ Go_new(iw) ]
   DeltaG_ao_iw(:,:,:)=G_ao_iw_hf(:,:,:)+DeltaG_ao_iw(:,:,:) ! Saving G(iw) in DeltaG_ao_iw
   do ifreq=1,nfreqs
    weval_cpx=im*wcoord(ifreq)
    call G_AO_RHF(nBas,nOrb,nO,eta,cHF,eSD,weval_cpx,G_ao_1)
    G_ao_iw_hf(ifreq,:,:)=G_ao_1(:,:)
   enddo
   DeltaG_ao_iw(:,:,:)=DeltaG_ao_iw(:,:,:)-G_ao_iw_hf(:,:,:) ! Setting DeltaG(iw) = G(iw) - Go_new(iw)
  endif

  ! Transform DeltaG(i w) -> DeltaG(i tau) [ i tau and -i tau ]
  !      [ the weights contain the 2 /(2 pi) = 1 / pi factor and the cos(tau w) or sin(tau w) ]
  G_ao_itau=czero
  do itau=1,ntimes
   G_plus_itau(:,:)=czero
   G_minus_itau(:,:)=czero
   do ifreq=1,nfreqs
    G_plus_itau(:,:) = G_plus_itau(:,:)   + im*cosw2t_weight(itau,ifreq)*Real(DeltaG_ao_iw(ifreq,:,:))  &
                                          - im*sinw2t_weight(itau,ifreq)*Aimag(DeltaG_ao_iw(ifreq,:,:)) 
    G_minus_itau(:,:) = G_minus_itau(:,:) + im*cosw2t_weight(itau,ifreq)*Real(DeltaG_ao_iw(ifreq,:,:))  &
                                          + im*sinw2t_weight(itau,ifreq)*Aimag(DeltaG_ao_iw(ifreq,:,:)) 
   enddo
   ! Build G(i tau) = DeltaG(i tau) + Go(i tau)
   G_ao_itau(2*itau-1,:,:)=G_plus_itau(:,:) +G_ao_itau_hf(2*itau-1,:,:)
   G_ao_itau(2*itau  ,:,:)=G_minus_itau(:,:)+G_ao_itau_hf(2*itau  ,:,:)
  enddo
 
  ! Do mixing with previous G(i tau) to facilitate convergence
  G_ao_itau(:,:,:)=alpha_mixing*G_ao_itau(:,:,:)+(1d0-alpha_mixing)*G_ao_itau_old(:,:,:)
  G_ao_itau_old(:,:,:)=G_ao_itau(:,:,:)

 enddo
 write(*,*)
 write(*,'(A50)') '---------------------------------------'
 write(*,'(A50)') '      scGW calculation completed       '
 write(*,'(A50)') '---------------------------------------'
 write(*,*)
 write(*,'(a,f15.8,a,i5,a)') ' Trace scGW  ',trace_1_rdm,' after ',iter,' global iterations '
 write(*,'(a,f15.8)')        ' Change of P ',diff_Pao
 write(*,'(a,f15.8)')        ' Chem. Pot.  ',chem_pot
 write(*,'(a,f15.8)')        ' Hcore+Hx    ',Ehfl
 write(*,'(a,f15.8)')        ' EcGM        ',EcGM
 write(*,'(a,f15.8)')        ' Eelec       ',Ehfl+EcGM
 write(*,'(a,f15.8)')        ' scGW Energy ',Ehfl+EcGM+ENuc
 write(*,*)
 write(*,*) ' Final occupation numbers'
 do ibas=1,nOrb
  write(*,'(I7,F15.8)') ibas,Occ(ibas)
 enddo

 ! Write restart files
 call write_scGW_restart(nBas,ntimes,ntimes_twice,nfreqs,chem_pot,P_ao,G_ao_itau,G_ao_iw_hf,DeltaG_ao_iw)
 
 ! Using the correlated G and Sigma_c to test the linearized density matrix approximation
 if(dolinGW) then
  write(*,*)
  write(*,*) ' -------------------------------------------'
  write(*,*) ' Testing the linearized approximation with G'
  write(*,*) '         G^lin = G + G Sigma_c G'
  write(*,*) ' -------------------------------------------'
  P_ao_old=0d0
  G_ao_1(:,:)=czero
  do ifreq=1,nfreqs
   G_ao_1(:,:)=G_ao_iw_hf(ifreq,:,:)+DeltaG_ao_iw(ifreq,:,:)
   G_ao_1(:,:)=matmul(matmul(G_ao_1(:,:),Sigma_c_w_ao(ifreq,:,:)),G_ao_1(:,:))
   P_ao_old(:,:) = P_ao_old(:,:) + wweight(ifreq)*real(G_ao_1(:,:)+conjg(G_ao_1(:,:))) ! Integrate along iw
  enddo
  P_ao_old=P_ao_old/pi
  P_ao_old=P_ao+P_ao_old
  trace_1_rdm=0d0
  do ibas=1,nBas
   do jbas=1,nBas
    trace_1_rdm=trace_1_rdm+P_ao_old(ibas,jbas)*S(ibas,jbas)
   enddo
  enddo
  Ehfl=0d0
  do ibas=1,nBas
   do jbas=1,nBas
    Ehfl=Ehfl+P_ao_old(ibas,jbas)*Hc(ibas,jbas)
    do kbas=1,nBas
     do lbas=1,nBas
      Ehfl=Ehfl+0.5d0*P_ao_old(kbas,lbas)*P_ao_old(ibas,jbas)*vMAT(1+(lbas-1)+(kbas-1)*nBas,1+(jbas-1)+(ibas-1)*nBas) &
          -0.25d0*P_ao_old(kbas,lbas)*P_ao_old(ibas,jbas)*vMAT(1+(jbas-1)+(kbas-1)*nBas,1+(lbas-1)+(ibas-1)*nBas)
     enddo
    enddo
   enddo
  enddo
  P_mo=-matmul(matmul(cHFinv,P_ao_old),transpose(cHFinv)) ! Minus to order occ numbers
  call diagonalize_matrix(nOrb,P_mo,Occ)
  write(*,'(a,f15.8)')        ' Hcore+Hx    ',Ehfl
  write(*,'(a,f15.8)')        ' EcGM        ',EcGM
  write(*,'(a,f15.8)')        ' Eelec       ',Ehfl+EcGM
  write(*,'(a,f15.8)')        ' lin-G Energy',Ehfl+EcGM+ENuc
  write(*,*)
  write(*,'(a,f15.8,a,i5,a)') ' Trace lin-scGW  ',trace_1_rdm
  write(*,*)
  write(*,*) ' Lin-G occupation numbers'
  Occ=-Occ
  do ibas=1,nOrb
   write(*,'(I7,F15.8)') ibas,Occ(ibas)
  enddo
 endif

 call wall_time(end_scGWitauiw)
 
 t_scGWitauiw = end_scGWitauiw - start_scGWitauiw
 write(*,'(A65,1X,F9.3,A8)') 'Total wall time for scGW = ',t_scGWitauiw,' seconds'
 write(*,*)

 ! Restore values and deallocate dyn arrays
 eHF(:) = eHF(:)+chem_pot_saved
 deallocate(Wp_ao_itau)
 deallocate(Chi0_ao_iw,Wp_ao_iw)
 deallocate(tcoord,tweight) 
 deallocate(sint2w_weight)
 deallocate(cost2w_weight)
 deallocate(cosw2t_weight)
 deallocate(sinw2t_weight)
 deallocate(G_ao_itau_old)
 deallocate(G_ao_itau,G_ao_itau_hf)
 deallocate(Sigma_c_w_ao,DeltaG_ao_iw,G_ao_iw_hf)
 deallocate(P_ao,P_ao_old,P_ao_iter,P_ao_hf,F_ao,P_mo,cHFinv,U_mo,Occ,eSD) 
 deallocate(Sigma_c_plus,Sigma_c_minus) 
 deallocate(Sigma_c_c,Sigma_c_s) 
 deallocate(G_minus_itau,G_plus_itau) 
 deallocate(G_ao_1,G_ao_2) 
 deallocate(Chi0_ao_itau) 

end subroutine 
