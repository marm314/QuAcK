subroutine R_eh_triplet_Phi(eta,nOrb,nC,nR,nS,eh_trip_Om,eh_trip_rho,eh_trip_Phi)


! Compute irreducible vertex in the triplet pp channel
  implicit none

! Input variables
  double precision,intent(in)   :: eta
  integer,intent(in)            :: nOrb,nC,nR,nS
  double precision,intent(in)   :: eh_trip_Om(nS)
  double precision,intent(in)   :: eh_trip_rho(nOrb,nOrb,nS)

! Local variables
  integer                       :: p,q,r,s
  integer                       :: n

! Output variables
  double precision,intent(out)   :: eh_trip_Phi(nOrb,nOrb,nOrb,nOrb)

! Initialization
  eh_trip_Phi(:,:,:,:) = 0d0

  !$OMP PARALLEL DEFAULT(NONE) &
  !$OMP PRIVATE(p, q, r, s, n) &
  !$OMP SHARED(eta, nC, nOrb, nR, nS, eh_trip_Phi, eh_trip_rho, eh_trip_Om)
  !$OMP DO COLLAPSE(2)
  do s = nC+1, nOrb-nR
     do r = nC+1, nOrb-nR
        do q = nC+1, nOrb-nR
           do p = nC+1, nOrb-nR
              
              do n=1,nS
                 eh_trip_Phi(p,q,r,s) = eh_trip_Phi(p,q,r,s)                &
                      - ((eh_trip_rho(p,r,n)*eh_trip_rho(s,q,n) + eh_trip_rho(r,p,n)*eh_trip_rho(q,s,n))/eh_trip_Om(n)) &
                      * (1d0 - exp(- 2d0 * eta * eh_trip_Om(n) * eh_trip_Om(n)))
              end do
              
           enddo
        enddo
     enddo
  enddo
  !$OMP END DO
  !$OMP END PARALLEL

end subroutine 
