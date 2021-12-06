subroutine unrestricted_hybrid_exchange_derivative_discontinuity(DFA,nEns,wEns,nCC,aCC,nGrid,weight,rhow,&
                                                              Cx_choice,doNcentered,ExDD)

! Compute the exchange part of the derivative discontinuity for hybrid functionals

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: DFA
  integer,intent(in)            :: nEns
  double precision,intent(in)   :: wEns(nEns)
  integer,intent(in)            :: nCC
  double precision,intent(in)   :: aCC(nCC,nEns-1)
 
  integer,intent(in)            :: nGrid
  double precision,intent(in)   :: weight(nGrid)
  double precision,intent(in)   :: rhow(nGrid)
  integer,intent(in)            :: Cx_choice
  logical,intent(in)            :: doNcentered

! Local variables


! Output variables

  double precision,intent(out)  :: ExDD(nEns)

! Select exchange functional

  select case (DFA)

    case (1)

      ExDD(:) = 0d0

    case (2)

      ExDD(:) = 0d0

    case (3)

      ExDD(:) = 0d0

    case default

      call print_warning('!!! Hybrid exchange derivative discontinuity not available !!!')
      stop

  end select
 
end subroutine unrestricted_hybrid_exchange_derivative_discontinuity
