subroutine set_Eeval_cluster(nOrb,nOrb2,nE_in,shift,eqsGWB_state,nE_eval_global, &
                             E_eval_global_cpx,chem_pot)

! Compute set Eeval using clusters

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: nE_in
  integer,intent(in)            :: nOrb
  integer,intent(in)            :: nOrb2

  double precision,intent(in)            :: shift
  double precision,intent(in)            :: chem_pot
  double precision,intent(in)            :: eqsGWB_state(nOrb2)

! Local variables

  integer                       :: icluster
  integer                       :: iorb
  integer                       :: iE
  integer                       :: iE_
  integer                       :: ncluster
  integer,allocatable           :: nE_per_cluster(:)

  double precision              :: step_E=2.5d-2
  double precision,allocatable  :: E_eval_global(:)


  type                          :: t_cluster
   integer                      :: nE
   integer                      :: nE_eval
   double precision,allocatable :: E_QP(:)
   double precision,allocatable :: E_eval(:)
  end type
  type(t_cluster),allocatable   :: clusters(:)

! Output variables

  integer,intent(inout)         :: nE_eval_global

  complex *16,intent(out)       :: E_eval_global_cpx(nE_in)

!

! Set the number of clusters [i.e., energies separated more than (or equal to) 0.1 a.u.]
  ncluster=1
  do iorb=2,nOrb
   if(abs(eqsGWB_state(iorb)-eqsGWB_state(iorb-1))>=0.1d0) ncluster=ncluster+1
  enddo
  allocate(clusters(ncluster))

! For each cluster find the number of QP energies associated
  allocate(nE_per_cluster(ncluster))
  icluster=1; nE_per_cluster(:)=1;
  do iorb=2,nOrb
   if(abs(eqsGWB_state(iorb)-eqsGWB_state(iorb-1))>=0.1d0) then
    icluster=icluster+1
   else
    nE_per_cluster(icluster)=nE_per_cluster(icluster)+1
   endif
  enddo
  do icluster=1,ncluster
   clusters(icluster)%nE=nE_per_cluster(icluster)
  enddo
  deallocate(nE_per_cluster)

! For each cluster store the QP energies associated
  iorb=1
  do icluster=1,ncluster
   allocate(clusters(icluster)%E_QP(clusters(icluster)%nE))
   do iE=1,clusters(icluster)%nE
    clusters(icluster)%E_QP(iE)=eqsGWB_state(iorb)
    iorb=iorb+1
   enddo
  enddo

! For each cluster find the number of energies (e_EVAL) to be used in Sigma_c [i.e., Sigma_c(e_EVAl)]
! and allocate the cluster arrays to store the energies to be evaluated
  do icluster=1,ncluster
   clusters(icluster)%nE_eval=2
   do iE=2,clusters(icluster)%nE
     if( abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) >= 7.5d-2 ) then
      clusters(icluster)%nE_eval=clusters(icluster)%nE_eval+2
     else if( abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) < 7.5d-2 .and. &
              abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) >= 5d-2 ) then
      clusters(icluster)%nE_eval=clusters(icluster)%nE_eval+1
     else ! abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) < 0.05
      clusters(icluster)%nE_eval=clusters(icluster)%nE_eval
     endif   
   enddo
   clusters(icluster)%nE_eval=clusters(icluster)%nE_eval+2
   clusters(icluster)%nE_eval=clusters(icluster)%nE_eval+2*clusters(icluster)%nE
   allocate(clusters(icluster)%E_eval(clusters(icluster)%nE_eval))
  enddo

! For each cluster set the evaluation energies (e_EVAL) to be used in Sigma_c [i.e., Sigma_c(e_EVAl)]
  do icluster=1,ncluster
   clusters(icluster)%E_eval(:)=czero
   clusters(icluster)%E_eval(1)=clusters(icluster)%E_QP(1)-2d0*step_E
   clusters(icluster)%E_eval(2)=clusters(icluster)%E_QP(1)-step_E
   iE_=3
   do iE=2,clusters(icluster)%nE
     if( abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) >= 7.5d-2 ) then
       clusters(icluster)%E_eval(iE_)=clusters(icluster)%E_QP(iE-1)+step_E
       iE_=iE_+1
       clusters(icluster)%E_eval(iE_)=clusters(icluster)%E_QP(iE-1)+2d0*step_E
       iE_=iE_+1
     else if( abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) < 7.5d-2 .and. &
              abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) >= 5d-2 ) then
       clusters(icluster)%E_eval(iE_)=0.5d0*(clusters(icluster)%E_QP(iE)+clusters(icluster)%E_QP(iE-1))
       iE_=iE_+1
     else ! abs(clusters(icluster)%E_QP(iE)-clusters(icluster)%E_QP(iE-1)) < 0.05
       ! Nth
     endif   
   enddo
   clusters(icluster)%E_eval(iE_)=clusters(icluster)%E_QP(clusters(icluster)%nE)+step_E
   iE_=iE_+1
   clusters(icluster)%E_eval(iE_)=clusters(icluster)%E_QP(clusters(icluster)%nE)+2d0*step_E
   iE_=iE_+1
   ! Add the points where we want the self-energy [Sigma_c(E_QP)] with small +-shifts
   do iE=1,clusters(icluster)%nE
    clusters(icluster)%E_eval(iE_)=clusters(icluster)%E_QP(iE)-shift
    iE_=iE_+1
    clusters(icluster)%E_eval(iE_)=clusters(icluster)%E_QP(iE)+shift
    iE_=iE_+1
   enddo
  enddo

  ! Select unique points
  do icluster=1,ncluster
   do iE=1,clusters(icluster)%nE_eval
    if(abs(clusters(icluster)%E_eval(iE)) > 1e-8) then
     do iE_=iE+1,clusters(icluster)%nE_eval
      if( abs(clusters(icluster)%E_eval(iE)-clusters(icluster)%E_eval(iE_) ) < 1e-8) then
       clusters(icluster)%E_eval(iE_)=0d0
      endif
     enddo
    endif
   enddo
  enddo
  nE_eval_global=0
  do icluster=1,ncluster
   do iE=1,clusters(icluster)%nE_eval
    if(abs(clusters(icluster)%E_eval(iE)) > 1e-8) nE_eval_global = nE_eval_global +1
   enddo
  enddo

  ! Store unique energies
  allocate(E_eval_global(nE_eval_global))
  iE_=1
  do icluster=1,ncluster
   do iE=1,clusters(icluster)%nE_eval
    if(abs(clusters(icluster)%E_eval(iE)) > 1e-8) then
     E_eval_global(iE_)=clusters(icluster)%E_eval(iE)
     iE_=iE_+1
    endif
   enddo
  enddo
   
  ! Sort and transform to complex unique energies 
  call sort_ascending(nE_eval_global,E_eval_global)
  if(nE_in>1) E_eval_global_cpx(:)=E_eval_global(:)-chem_pot
  deallocate(E_eval_global)

  ! Delete some dynamic arrays and allocate the self-energy array
  do icluster=1,ncluster
   deallocate(clusters(icluster)%E_QP)
   deallocate(clusters(icluster)%E_eval)
  enddo
  deallocate(clusters)


end subroutine 


