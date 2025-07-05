subroutine G_MO_HFB(nOrb,nOrb_twice,eta,eHFB,wcoord,MAT1,MAT2,MAT3,MAT4,G_MO)

! G(i w)

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: nOrb
  integer,intent(in)            :: nOrb_twice

  double precision,intent(in)   :: eta
  double precision,intent(in)   :: MAT1(nOrb,nOrb)
  double precision,intent(in)   :: MAT2(nOrb,nOrb)
  double precision,intent(in)   :: MAT3(nOrb,nOrb)
  double precision,intent(in)   :: MAT4(nOrb,nOrb)


  complex*16,intent(in)         :: wcoord

! Local variables

  integer                       :: iorb

! Output variables
  double precision,intent(inout):: eHFB(nOrb_twice)
  complex*16,intent(out)        :: G_MO(nOrb,nOrb)
  
!--------------------------
! Build G(i w) in MO basis
!--------------------------

! write(*,*)     
! write(*,*)'**************'
! write(*,*)'* HFB G(i w) *'
! write(*,*)'**************'
! write(*,*)

 G_MO(:,:) = czero
  
 do iorb=1,nOrb
  G_MO(:,:) = G_MO(:,:) + 1d0/(wcoord-eHFB(iorb)-im*eta)           &
            * matmul(Mat1(:,iorb:iorb),transpose(Mat2(:,iorb:iorb)))
  G_MO(:,:) = G_MO(:,:) + 1d0/(wcoord+eHFB(iorb)+im*eta)           &
            * matmul(Mat3(:,iorb:iorb),transpose(Mat4(:,iorb:iorb)))
 enddo

end subroutine

