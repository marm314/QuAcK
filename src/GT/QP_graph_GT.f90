subroutine QP_graph_GT(eta,nBas,nC,nO,nV,nR,nOO,nVV,eHF,Omega1,rho1,Omega2,rho2,eGTlin,eGT)

  implicit none
  include 'parameters.h'

! Iput variables
  integer,intent(in)            :: nBas
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nOO
  integer,intent(in)            :: nVV
  
  double precision,intent(in)   :: eta
  double precision,intent(in)   :: eHF(nBas)
  double precision,intent(in)   :: Omega1(nVV)
  double precision,intent(in)   :: rho1(nBas,nBas,nVV)
  double precision,intent(in)   :: Omega2(nOO)
  double precision,intent(in)   :: rho2(nBas,nBas,nOO)

  double precision,intent(in)   :: eGTlin(nBas)
  
! Local variables
  integer                       :: p
  integer                       :: nIt
  integer,parameter             :: maxIt = 64
  double precision,parameter    :: thresh = 1d-6
  double precision,external     :: SigmaC_GT,dSigmaC_GT
  double precision              :: sigC,dsigC
  double precision              :: f,df
  double precision              :: w
  
! Output variables
  double precision,intent(out)  :: eGT(nBas)

  sigC = 0d0
  dsigC = 0d0

! Run Newton's algorithm to find the root
  do p=nC+1,nBas-nR

    write(*,*) '-----------------'
    write(*,'(A10,I3)') 'Orbital ',p
    write(*,*) '-----------------'

    w = eGTlin(p)
    write(*,*) 'HERE', eGTlin(p), eHF(p)
    nIt = 0
    f = 1d0
    write(*,'(A3,I3,A1,1X,3F15.9)') 'It.',nIt,':',w*HaToeV,f

    do while (abs(f) > thresh .and. nIt < maxIt)

       nIt = nIt + 1

       sigC  =  SigmaC_GT(p,w,eta,nBas,nC,nO,nV,nR,nOO,nVV,eHF,Omega1,rho1,Omega2,rho2)
       dsigC = dSigmaC_GT(p,w,eta,nBas,nC,nO,nV,nR,nOO,nVV,eHF,Omega1,rho1,Omega2,rho2)
       write (*,*) sigC
       f  = w - eHF(p)  - sigC 
       df = 1d0 - dsigC
    
       w = w - f/df

       write(*,'(A3,I3,A1,1X,3F15.9)') 'It.',nIt,':',w*HaToeV,f,sigC

    end do

    if(nIt == maxIt) then 
      write(*,*) 'Newton root search has not converged!'
    else
      eGT(p) = w
      write(*,'(A32,F16.10)')   'Quasiparticle energy (eV)   ',eGT(p)*HaToeV
      write(*,*)
    end if

  end do
  
end subroutine QP_graph_GT
