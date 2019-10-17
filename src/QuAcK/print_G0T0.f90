subroutine print_G0T0(nBas,nO,e,ENuc,EHF,SigT,Z,eGW,EcRPA)

! Print one-electron energies and other stuff for G0T0

  implicit none
  include 'parameters.h'

  integer,intent(in)                 :: nBas,nO
  double precision,intent(in)        :: ENuc
  double precision,intent(in)        :: EHF
  double precision,intent(in)        :: EcRPA
  double precision,intent(in)        :: e(nBas),SigT(nBas),Z(nBas),eGW(nBas)

  integer                            :: x,HOMO,LUMO
  double precision                   :: Gap

! HOMO and LUMO

  HOMO = nO
  LUMO = HOMO + 1
  Gap = eGW(LUMO)-eGW(HOMO)

! Dump results

  write(*,*)'-------------------------------------------------------------------------------'
  write(*,*)'  One-shot G0T0 calculation (T-matrix self-energy)  '
  write(*,*)'-------------------------------------------------------------------------------'
  write(*,'(1X,A1,1X,A3,1X,A1,1X,A15,1X,A1,1X,A15,1X,A1,1X,A15,1X,A1,1X,A15,1X,A1,1X)') &
            '|','#','|','e_HF (eV)','|','Sigma_T (eV)','|','Z','|','e_QP (eV)','|'
  write(*,*)'-------------------------------------------------------------------------------'

  do x=1,nBas
    write(*,'(1X,A1,1X,I3,1X,A1,1X,F15.6,1X,A1,1X,F15.6,1X,A1,1X,F15.6,1X,A1,1X,F15.6,1X,A1,1X)') &
    '|',x,'|',e(x)*HaToeV,'|',SigT(x)*HaToeV,'|',Z(x),'|',eGW(x)*HaToeV,'|'
  enddo

  write(*,*)'-------------------------------------------------------------------------------'
  write(*,'(2X,A30,F15.6)') 'G0T0 HOMO      energy (eV):',eGW(HOMO)*HaToeV
  write(*,'(2X,A30,F15.6)') 'G0T0 LUMO      energy (eV):',eGW(LUMO)*HaToeV
  write(*,'(2X,A30,F15.6)') 'G0T0 HOMO-LUMO gap    (eV):',Gap*HaToeV
  write(*,*)'-------------------------------------------------------------------------------'
  write(*,'(2X,A30,F15.6)') 'RPA@G0T0 total energy       =',ENuc + EHF + EcRPA
  write(*,'(2X,A30,F15.6)') 'RPA@G0T0 correlation energy =',EcRPA
  write(*,*)'-------------------------------------------------------------------------------'
  write(*,*)

end subroutine print_G0T0


