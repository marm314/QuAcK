subroutine Xoiw_mo_RHFB(nOrb,nOrb_twice,eta,eHFB,weval,Mat1,Mat2,Chi0_mo_iw)

! Restricted Xo(i w) in MO basis

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: nOrb
  integer,intent(in)            :: nOrb_twice

  double precision,intent(in)   :: eta
  double precision,intent(inout):: eHFB(nOrb_twice)
  double precision,intent(in)   :: Mat1(nOrb,nOrb)
  double precision,intent(in)   :: Mat2(nOrb,nOrb)

  complex *16,intent(in)        :: weval

! Local variables

  integer                       :: index_ps,index_rq
  integer                       :: porb,qorb,rorb,sorb
  integer                       :: Istate,Jstate,nState

  double precision              :: factor1,factor2

! Ouput variables

  complex *16,intent(out)       :: Chi0_mo_iw(nOrb*nOrb,nOrb*nOrb)

!------------------------------------------------------------------------
! Build Xo(i w) in MO basis (M^6 scaling)
!------------------------------------------------------------------------

  nState=nOrb
  Chi0_mo_iw=czero

  do porb=1,nOrb
   do qorb=1,nOrb
    do rorb=1,nOrb
     do sorb=1,nOrb
      do Istate=1,nState
       do Jstate=1,nState
        factor1=Mat2(porb,Istate)*Mat2(qorb,Istate)*Mat1(rorb,Jstate)*Mat1(sorb,Jstate) & ! G_he G_he
               -Mat2(porb,Istate)*Mat1(qorb,Istate)*Mat2(rorb,Jstate)*Mat1(sorb,Jstate)   ! G_hh G_ee
        factor2=Mat2(rorb,Jstate)*Mat2(sorb,Jstate)*Mat1(porb,Istate)*Mat1(qorb,Istate) & ! G_he G_he
               -Mat1(rorb,Jstate)*Mat2(sorb,Jstate)*Mat1(porb,Istate)*Mat2(qorb,Istate)   ! G_hh G_ee
        index_ps=1+(sorb-1)+(porb-1)*nOrb
        index_rq=1+(rorb-1)+(qorb-1)*nOrb
        Chi0_mo_iw(index_ps,index_rq)=Chi0_mo_iw(index_ps,index_rq)                     &
                                  +factor1/(weval-(-eHFB(Istate)-eHFB(Jstate))+im*eta)  &
                                  -factor2/(weval+(-eHFB(Istate)-eHFB(Jstate))-im*eta)
       enddo
      enddo
     enddo
    enddo
   enddo
  enddo
  
  Chi0_mo_iw=2d0*Chi0_mo_iw  ! Times 2 because of the spin contributions
                             ! [ i.e., for Ghe Ghe take (up,up,up,up) and (down,down,down,down) 
                             !                                 & 
                             !       for Ghh Gee (up,down,down,up) and (down,up,up,down) ]

end subroutine

