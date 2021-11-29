subroutine unrestricted_fock_exchange_individual_energy(nBas,Pw,ERI,Ex)

! Compute the HF individual energy in the unrestricted formalism

  implicit none

! Input variables

  integer,intent(in)            :: nBas
  double precision,intent(in)   :: Pw(nBas,nBas)
  double precision,intent(in)   :: ERI(nBas,nBas,nBas,nBas)

! Local variables

  double precision,allocatable  :: Fx(:,:)
  double precision,external     :: trace_matrix

! Output variables

  double precision,intent(out)  :: Ex

! Compute HF exchange matrix

  allocate(Fx(nBas,nBas))

  call unrestricted_fock_exchange_potential(nBas,Pw,ERI,Fx)

  Ex = - 0.5d0*trace_matrix(nBas,matmul(Pw,Fx))

end subroutine unrestricted_fock_exchange_individual_energy
