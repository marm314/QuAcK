subroutine MP(doMP2,doMP3,unrestricted,regularize,nBas,nC,nO,nV,nR,ERI,ERI_aaaa,ERI_aabb,ERI_bbbb,ENuc,EHF,epsHF)

! Moller-Plesset module

  implicit none
  include 'parameters.h'

! Input variables

  logical,intent(in)            :: doMP2
  logical,intent(in)            :: doMP3
  logical,intent(in)            :: unrestricted

  logical,intent(in)            :: regularize
  integer,intent(in)            :: nBas
  integer,intent(in)            :: nC(nspin)
  integer,intent(in)            :: nO(nspin)
  integer,intent(in)            :: nV(nspin)
  integer,intent(in)            :: nR(nspin)
  double precision,intent(in)   :: ENuc
  double precision,intent(in)   :: EHF
  double precision,intent(in)   :: epsHF(nBas)
  double precision,intent(in)   :: ERI(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: ERI_aaaa(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: ERI_aabb(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: ERI_bbbb(nBas,nBas,nBas,nBas)

! Local variables

  double precision              :: start_MP     ,end_MP       ,t_MP

! Output variables

!------------------------------------------------------------------------
! Compute MP3 energy
!------------------------------------------------------------------------                               

  if(doMP2) then    
       
    call cpu_time(start_MP)
    if(unrestricted) then
      call UMP2(nBas,nC,nO,nV,nR,ERI_aaaa,ERI_aabb,ERI_bbbb,ENuc,EHF,epsHF)
    else
      call MP2(regularize,nBas,nC,nO,nV,nR,ERI,ENuc,EHF,epsHF)
    end if          
    call cpu_time(end_MP)

    t_MP = end_MP - start_MP
    write(*,'(A65,1X,F9.3,A8)') 'Total CPU time for MP2 = ',t_MP,' seconds'
    write(*,*)
                    
  end if

!------------------------------------------------------------------------
! Compute MP3 energy
!------------------------------------------------------------------------                               
                    
  if(doMP3) then    

    call cpu_time(start_MP)

    if(unrestricted) then
      write(*,*) 'MP3 NYI for UHF reference'
      stop
    else
      call MP3(nBas,nC,nO,nV,nR,ERI,ENuc,EHF,epsHF)
    end if
    call cpu_time(end_MP)

    t_MP = end_MP - start_MP
    write(*,'(A65,1X,F9.3,A8)') 'Total CPU time for MP2 = ',t_MP,' seconds'
    write(*,*)

  end if

end subroutine 
