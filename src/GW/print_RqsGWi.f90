
! ---

subroutine print_RqsGWi(nBas, nOrb, nO, eqsGW, cqsGW, ENuc, ET, EV, EJ, EK, ERqsGW, dipole)

! Print one-electron energies and other stuff for G0W0

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)                 :: nBas, nOrb
  integer,intent(in)                 :: nO
  double precision,intent(in)        :: eqsGW(nOrb)
  double precision,intent(in)        :: cqsGW(nBas,nOrb)
  double precision,intent(in)        :: ENuc
  double precision,intent(in)        :: ET
  double precision,intent(in)        :: EV
  double precision,intent(in)        :: EJ
  double precision,intent(in)        :: EK
  double precision,intent(in)        :: ERqsGW
  double precision,intent(in)        :: dipole(ncart)

! Local variables

  integer                            :: ixyz
  integer                            :: HOMO
  integer                            :: LUMO
  double precision                   :: Gap
  double precision                   :: S,S2

  logical                            :: dump_orb = .false.

! HOMO and LUMO

  HOMO = nO
  LUMO = HOMO + 1
  Gap = eqsGW(LUMO)-eqsGW(HOMO)

  S2 = 0d0
  S  = 0d0

! Dump results

  write(*,*)
  write(*,'(A50)')           '---------------------------------------'
  write(*,'(A33)')           ' Summary               '
  write(*,'(A50)')           '---------------------------------------'
  write(*,'(A33,1X,F16.10,A3)') ' One-electron energy = ',ET + EV,' au'
  write(*,'(A33,1X,F16.10,A3)') ' Kinetic      energy = ',ET,' au'
  write(*,'(A33,1X,F16.10,A3)') ' Potential    energy = ',EV,' au'
  write(*,'(A50)')           '---------------------------------------'
  write(*,'(A33,1X,F16.10,A3)') ' Two-electron energy = ',EJ + EK,' au'
  write(*,'(A33,1X,F16.10,A3)') ' Hartree      energy = ',EJ,' au'
  write(*,'(A33,1X,F16.10,A3)') ' Exchange     energy = ',EK,' au'
  write(*,'(A50)')           '---------------------------------------'
  write(*,'(A33,1X,F16.10,A3)') ' Electronic   energy = ',ERqsGW,' au'
  write(*,'(A33,1X,F16.10,A3)') ' Nuclear   repulsion = ',ENuc,' au'
  write(*,'(A33,1X,F16.10,A3)') ' qsRGW        energy = ',ERqsGW + ENuc,' au'
  write(*,'(A50)')           '---------------------------------------'
  write(*,'(A33,1X,F16.6,A3)')  ' qsGW HOMO      energy = ',eqsGW(HOMO)*HaToeV,' eV'
  write(*,'(A33,1X,F16.6,A3)')  ' qsGW LUMO      energy = ',eqsGW(LUMO)*HaToeV,' eV'
  write(*,'(A33,1X,F16.6,A3)')  ' qsGW HOMO-LUMO gap    = ',Gap*HaToeV,' eV'
  write(*,'(A50)')           '---------------------------------------'
  write(*,'(A33,1X,F16.6)')     ' <Sz>                = ',S
  write(*,'(A33,1X,F16.6)')     ' <S^2>               = ',S2
  write(*,'(A50)')           '---------------------------------------'
  write(*,'(A36)')           ' Dipole moment (Debye)    '
  write(*,'(10X,4A10)')      'X','Y','Z','Tot.'
  write(*,'(10X,4F10.4)')    (dipole(ixyz)*auToD,ixyz=1,ncart),norm2(dipole)*auToD
  write(*,'(A50)')           '---------------------------------------'
  write(*,*)

! Print results

  if(dump_orb) then 
    write(*,'(A50)') '---------------------------------------'
    write(*,'(A50)') ' RqsGW orbital coefficients '
    write(*,'(A50)') '---------------------------------------'
    call matout(nBas, nOrb, cqsGW)
    write(*,*)
  end if
  write(*,'(A50)') '---------------------------------------'
  write(*,'(A50)') ' RqsGW orbital energies (au) '
  write(*,'(A50)') '---------------------------------------'
  call vecout(nOrb, eqsGW)
  write(*,*)

end subroutine 
