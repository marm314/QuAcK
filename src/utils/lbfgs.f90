
!=========================================================================
subroutine lbfgs(N, M, X, F, G, DIAG, W, IFLAG,      &
                 GTOL, STPMIN, STPMAX, STP, ITER, &
                 INFO, NFEV,                  &
                 LINE_DGINIT, LINE_FINIT,      &
                 LINE_STX, LINE_FX, LINE_DGX,   &
                 LINE_STY, LINE_FY, LINE_DGY,   &
                 LINE_STMIN, LINE_STMAX,       &
                 LINE_BRACKT, LINE_STAGE1, LINE_INFOC)
  implicit none

  integer, intent(inout) :: LINE_INFOC
  integer, intent(inout)  :: ITER, IFLAG, INFO, NFEV
  integer, intent(in)     :: N, M
  double precision, intent(inout) :: GTOL
  double precision, intent(in)    :: STPMIN, STPMAX
  double precision, intent(inout) :: STP
  double precision, intent(in)    :: F
  double precision, intent(inout) :: LINE_DGINIT, LINE_FINIT
  double precision, intent(inout) :: LINE_STX, LINE_FX, LINE_DGX
  double precision, intent(inout) :: LINE_STY, LINE_FY, LINE_DGY
  double precision, intent(inout) :: LINE_STMIN, LINE_STMAX
  logical, intent(inout)  :: LINE_BRACKT, LINE_STAGE1
  !arrays
  double precision, intent(inout) :: X(N), DIAG(N), W(N*(2*M+1)+2*M)
  double precision, intent(in)    :: G(N)
  !=====
  double precision :: FTOL, YS, YY, SQ, YR, BETA
  integer :: POINT, ISPT, IYPT, MAXFEV, BOUND, NPT, CP, I, INMC, IYCN, ISCN
  !=====


  !
  ! Initialize
  !-----------

  ! Parameters for line search routine
  FTOL = 1.0D-4
  MAXFEV = 20

  ISPT = N + 2 * M
  IYPT = ISPT + N * M
  POINT = MAX( 0 , MOD(ITER-1, M) )
  NPT = POINT * N
  ITER  = ITER + 1
  BOUND = MIN( ITER-1 , M)


  !
  ! Entering the subroutine with a new position and gradient
  ! or entering for the first time ever
  if( IFLAG /= 1 ) then
    W(ISPT+1:ISPT+N) = -G(1:N) * DIAG(1:N)

  else

    call MCSRCH(N, X, F, G, W(ISPT+POINT*N+1), STP, FTOL, MAXFEV, INFO, NFEV, &
               DIAG, GTOL, STPMIN, STPMAX, LINE_DGINIT, LINE_FINIT, &
               LINE_STX, LINE_FX, LINE_DGX, &
               LINE_STY, LINE_FY, LINE_DGY, &
               LINE_STMIN, LINE_STMAX, &
               LINE_BRACKT, LINE_STAGE1, LINE_INFOC)
    !
    ! Compute the new step and gradient change
    !
    NPT = POINT * N
    W(ISPT+NPT+1:ISPT+NPT+N) = STP * W(ISPT+NPT+1:ISPT+NPT+N)
    W(IYPT+NPT+1:IYPT+NPT+N) = G(1:N) - W(1:N)

    YS = DOT_PRODUCT( W(IYPT+NPT+1:IYPT+NPT+N) , W(ISPT+NPT+1:ISPT+NPT+N) )
    YY = DOT_PRODUCT( W(IYPT+NPT+1:IYPT+NPT+N) , W(IYPT+NPT+1:IYPT+NPT+N) )
    DIAG(1:N)= YS / YY

    !
    !  COMPUTE -H*G USING THE FORMULA GIVEN IN: Nocedal, J. 1980,
    !  "Updating quasi-Newton matrices with limited storage",
    !  Mathematics of Computation, Vol.24, No.151, pp. 773-782.
    !  ---------------------------------------------------------
    !
    POINT = MODULO(ITER - 1, M)
    CP = POINT
    if (POINT == 0) CP = M

    W(N+CP) = 1.0d0 / YS
    W(1:N)  = -G(1:N)

    CP = POINT
    do I= 1, BOUND
      CP = CP - 1
      if (CP ==  -1) CP = M - 1
      SQ = DOT_PRODUCT(W(ISPT+CP*N+1:ISPT+CP*N+N), W(1:N))
      INMC = N + M + CP + 1
      IYCN = IYPT + CP * N
      W(INMC)= W(N+CP+1) * SQ
      W(1:N) = W(1:N) - W(INMC) * W(IYCN+1:IYCN+N)
    enddo

    W(1:N) = DIAG(1:N) * W(1:N)

    do I=1, BOUND
      YR = DOT_PRODUCT(W(IYPT+CP*N+1:IYPT+CP*N+N), W(1:N))
      BETA = W(N+CP+1) * YR
      INMC = N + M + CP + 1
      BETA = W(INMC) - BETA
      ISCN = ISPT + CP * N
      W(1:N) = W(1:N) + BETA * W(ISCN+1:ISCN+N)
      CP = CP + 1
      if (CP == M) CP = 0
    enddo

    !
    !  STORE THE NEW SEARCH DIRECTION
    W(ISPT+POINT*N+1:ISPT+POINT*N+N) = W(1:N)

  endif

  !
  ! Obtain the one-dimensional minimizer of the function
  ! by using the line search routine mcsrch
  !----------------------------------------------------
  NFEV = 0
  STP = 1.0d0
  W(1:N) = G(1:N)

  INFO  = 0

  call MCSRCH(N, X, F, G, W(ISPT+POINT*N+1), STP, FTOL, MAXFEV, INFO, NFEV, &
             DIAG, GTOL, STPMIN, STPMAX, LINE_DGINIT, LINE_FINIT, &
             LINE_STX, LINE_FX, LINE_DGX, &
             LINE_STY, LINE_FY, LINE_DGY, &
             LINE_STMIN, LINE_STMAX, &
             LINE_BRACKT, LINE_STAGE1, LINE_INFOC)

  if (INFO  ==  -1) then
    IFLAG = 1
    return
  else
    IFLAG = -1
    return
  endif

end subroutine lbfgs


!=========================================================================
subroutine mcsrch(N, X, F, G, S, STP, FTOL, MAXFEV, INFO, NFEV, WA, &
                  GTOL, STPMIN, STPMAX, DGINIT, FINIT, &
                  STX, FX, DGX, STY, FY, DGY, STMIN, STMAX, &
                  BRACKT, STAGE1, INFOC)
  implicit none

  integer, intent(in)     :: N, MAXFEV
  integer, intent(inout)  :: INFO, NFEV
  integer, intent(inout)  :: INFOC
  double precision, intent(in)    :: GTOL, STPMIN, STPMAX
  double precision, intent(in)    :: F, FTOL
  double precision, intent(inout) :: STP, DGINIT, FINIT
  double precision, intent(inout) :: STX, FX, DGX
  double precision, intent(inout) :: STY, FY, DGY
  double precision, intent(inout) :: STMIN, STMAX
  logical, intent(inout) :: BRACKT, STAGE1
  double precision, intent(in)     :: G(N)
  double precision, intent(inout)  :: X(N), S(N), WA(N)
  !=====
  double precision, parameter :: XTOL=1.0d-17
  double precision, parameter :: P5     = 0.50d0
  double precision, parameter :: P66    = 0.66d0
  double precision, parameter :: XTRAPF = 4.00d0
  double precision           :: DG, DGM, DGTEST, DGXM, DGYM, FTEST1, FM, FXM, FYM, WIDTH, WIDTH1
  !=====


  DGTEST = FTOL * DGINIT
  WIDTH = STPMAX - STPMIN
  WIDTH1 = WIDTH / P5

  ! Is it a first entry (info == 0)
  ! or a second entry (info == -1)?
  if( INFO == -1 ) then

    ! Reset INFO
    INFO = 0

    NFEV = NFEV + 1
    DG = SUM( G(:) * S(:) )
    FTEST1 = FINIT + STP * DGTEST
    !
    !  TEST FOR CONVERGENCE.
    !
    if ((BRACKT .AND. (STP <= STMIN .OR. STP >= STMAX)) &
      .OR. INFOC  ==  0) INFO = 6
    if (STP  ==  STPMAX .AND. &
       F <= FTEST1 .AND. DG <= DGTEST) INFO = 5
    if (STP  ==  STPMIN .AND.  &
       (F > FTEST1 .OR. DG >= DGTEST)) INFO = 4
    if (NFEV >= MAXFEV) INFO = 3
    if (BRACKT .AND. STMAX-STMIN <= XTOL*STMAX) INFO = 2
    if (F <= FTEST1 .AND. ABS(DG) <= GTOL*(-DGINIT)) INFO = 1
    !
    !  CHECK FOR TERMINATION.
    !
    if (INFO /= 0) return
    !
    !  IN THE FIRST STAGE WE SEEK A STEP FOR WHICH THE MODIFIED
    !  FUNCTION HAS A NONPOSITIVE VALUE AND NONNEGATIVE DERIVATIVE.
    !
    if (STAGE1 .AND. F <= FTEST1 .AND. &
       DG >= MIN(FTOL, GTOL)*DGINIT) STAGE1 = .FALSE.
    !
    !  A MODIFIED FUNCTION IS USED TO PREDICT THE STEP ONLY IF
    !  WE HAVE NOT OBTAINED A STEP FOR WHICH THE MODIFIED
    !  FUNCTION HAS A NONPOSITIVE FUNCTION VALUE AND NONNEGATIVE
    !  DERIVATIVE, AND IF A LOWER FUNCTION VALUE HAS BEEN
    !  OBTAINED BUT THE DECREASE IS NOT SUFFICIENT.
    !
    if (STAGE1 .AND. F <= FX .AND. F > FTEST1) then
      !
      !     DEFINE THE MODIFIED FUNCTION AND DERIVATIVE VALUES.
      !
      FM = F - STP * DGTEST
      FXM = FX - STX * DGTEST
      FYM = FY - STY * DGTEST
      DGM = DG - DGTEST
      DGXM = DGX - DGTEST
      DGYM = DGY - DGTEST
      !
      !     CALL MCSTEP TO UPDATE THE INTERVAL OF UNCERTAINTY
      !     AND TO COMPUTE THE NEW STEP.
      !
      call mcstep(STX, FXM, DGXM, STY, FYM, DGYM, STP, FM, DGM, BRACKT, STMIN, STMAX, INFOC)
      !
      !     RESET THE FUNCTION AND GRADIENT VALUES FOR F.
      !
      FX = FXM + STX * DGTEST
      FY = FYM + STY * DGTEST
      DGX = DGXM + DGTEST
      DGY = DGYM + DGTEST
    else
      !
      !     CALL MCSTEP TO UPDATE THE INTERVAL OF UNCERTAINTY
      !     AND TO COMPUTE THE NEW STEP.
      !
      call mcstep(STX, FX, DGX, STY, FY, DGY, STP, F, DG, BRACKT, STMIN, STMAX, INFOC)
    endif
    !
    !  FORCE A SUFFICIENT DECREASE IN THE SIZE OF THE
    !  INTERVAL OF UNCERTAINTY.
    !
    if (BRACKT) then
      if (ABS(STY-STX) >= P66 * WIDTH1) STP = STX + P5 * (STY - STX)
      WIDTH1 = WIDTH
      WIDTH = ABS(STY-STX)
    endif

  else

    INFOC = 1
    !
    !  CHECK THE INPUT PARAMETERS FOR ERRORS.
    !
    if ( STP <= 0.0d0 .OR. FTOL < 0.0d0 .OR.  &
       GTOL < 0.0d0 .OR. XTOL < 0.0d0 .OR. STPMIN < 0.0d0 &
       .OR. STPMAX < STPMIN ) return
    !
    !  COMPUTE THE INITIAL GRADIENT IN THE SEARCH DIRECTION
    !  AND CHECK THAT S IS A DESCENT DIRECTION.
    !
    DGINIT = DOT_PRODUCT( G , S )

    if (DGINIT > 0.0d0) then
      return
    endif
    !
    !  INITIALIZE LOCAL VARIABLES.
    !

    BRACKT = .FALSE.
    STAGE1 = .TRUE.
    NFEV = 0
    FINIT = F
    DGTEST = FTOL * DGINIT
    WA(:) = X(:)


    !
    !  THE VARIABLES STX, FX, DGX CONTAIN THE VALUES OF THE STEP,
    !  FUNCTION, AND DIRECTIONAL DERIVATIVE AT THE BEST STEP.
    !  THE VARIABLES STY, FY, DGY CONTAIN THE VALUE OF THE STEP,
    !  FUNCTION, AND DERIVATIVE AT THE OTHER ENDPOINT OF
    !  THE INTERVAL OF UNCERTAINTY.
    !  THE VARIABLES STP, F, DG CONTAIN THE VALUES OF THE STEP,
    !  FUNCTION, AND DERIVATIVE AT THE CURRENT STEP.
    !
    STX = 0.0d0
    FX = FINIT
    DGX = DGINIT
    STY = 0.0d0
    FY = FINIT
    DGY = DGINIT
  endif

  !
  !SET THE MINIMUM AND MAXIMUM STEPS TO CORRESPOND
  !TO THE PRESENT INTERVAL OF UNCERTAINTY.
  !
  if (BRACKT) then
    STMIN = MIN(STX, STY)
    STMAX = MAX(STX, STY)
  else
    STMIN = STX
    STMAX = STP + XTRAPF*(STP - STX)
  endif
  !
  !FORCE THE STEP TO BE WITHIN THE BOUNDS STPMAX AND STPMIN.
  !
  STP = MAX(STPMIN, STP)
  STP = MIN(STP, STPMAX)
  !
  !IF AN UNUSUAL TERMINATION IS TO OCCUR THEN LET
  !STP BE THE LOWEST POINT OBTAINED SO FAR.
  !
  if ((BRACKT .AND. (STP <= STMIN .OR. STP >= STMAX)) &
    .OR. NFEV >= MAXFEV-1 .OR. INFOC  ==  0 &
    .OR. (BRACKT .AND. STMAX-STMIN <= XTOL*STMAX)) STP = STX

  !
  !Evaluate the function and gradient at STP
  !and compute the directional derivative.
  !We return to main program to obtain F and G.
  !
  X(:) = WA(:) + STP * S(:)

  INFO = -1


end subroutine mcsrch


!=========================================================================
subroutine mcstep(STX, FX, DX, STY, FY, DY, STP, FP, DG, BRACKT, STPMIN, STPMAX, INFO)
  implicit none

  integer, intent(inout)  :: INFO
  double precision, intent(in)     :: FP
  double precision, intent(inout)  :: STX, FX, DX, STY, FY, DY, STP, DG, STPMIN, STPMAX
  logical, intent(inout) :: BRACKT
  !=====
  logical BOUND
  double precision GAM, P, Q, R, S, SGND, STPC, STPF, STPQ, THETA
  !=====

  INFO = 0
  !
  ! CHECK THE INPUT PARAMETERS FOR ERRORS.
  !
  IF ((BRACKT .AND. (STP <= MIN(STX, STY) .OR. &
     STP >= MAX(STX, STY))) .OR.  &
     DX*(STP-STX) >= 0.0 .OR. STPMAX < STPMIN) RETURN
  !
  ! Determine if the derivatives have opposite sign
  !
  SGND = DG * ( DX / ABS(DX) )

  ! FIRST CASE. A HIGHER FUNCTION VALUE.
  ! THE MINIMUM IS BRACKETED. IF THE CUBIC STEP IS CLOSER
  ! TO STX THAN THE QUADRATIC STEP, THE CUBIC STEP IS TAKEN,
  ! ELSE THE AVERAGE OF THE CUBIC AND QUADRATIC STEPS IS TAKEN.
  !
  IF (FP > FX) THEN
  INFO = 1
  BOUND = .TRUE.
  THETA = 3*(FX - FP)/(STP - STX) + DX + DG
  S = MAX(ABS(THETA), ABS(DX), ABS(DG))
  GAM = S * SQRT( (THETA/S)**2 - (DX/S)*(DG/S) )
  IF (STP < STX) GAM = -GAM
  P = (GAM - DX) + THETA
  Q = ((GAM - DX) + GAM) + DG
  R = P / Q
  STPC = STX + R*(STP - STX)
  STPQ = STX + ( ( DX / ( ( FX - FP ) / ( STP - STX ) + DX ) ) / 2 ) * ( STP - STX )
  IF (ABS(STPC-STX) < ABS(STPQ-STX)) THEN
  STPF = STPC
  ELSE
  STPF = STPC + (STPQ - STPC) / 2
  END IF
  BRACKT = .TRUE.
  !
  ! SECOND CASE. A LOWER FUNCTION VALUE AND DERIVATIVES OF
  ! OPPOSITE SIGN. THE MINIMUM IS BRACKETED. IF THE CUBIC
  ! STEP IS CLOSER TO STX THAN THE QUADRATIC (SECANT) STEP,
  ! THE CUBIC STEP IS TAKEN, ELSE THE QUADRATIC STEP IS TAKEN.
  !
  ELSE IF (SGND < 0.0) THEN
  INFO = 2
  BOUND = .FALSE.
  THETA = 3*(FX - FP)/(STP - STX) + DX + DG
  S = MAX(ABS(THETA), ABS(DX), ABS(DG))
  GAM = S * SQRT( (THETA/S)**2 - (DX/S)*(DG/S) )
  IF (STP > STX) GAM = -GAM
  P = (GAM - DG) + THETA
  Q = ((GAM - DG) + GAM) + DX
  R = P/Q
  STPC = STP + R*(STX - STP)
  STPQ = STP + (DG/(DG-DX))*(STX - STP)
  IF (ABS(STPC-STP) > ABS(STPQ-STP)) THEN
  STPF = STPC
  ELSE
  STPF = STPQ
  END IF
  BRACKT = .TRUE.
  !
  ! THIRD CASE. A LOWER FUNCTION VALUE, DERIVATIVES OF THE
  ! SAME SIGN, AND THE MAGNITUDE OF THE DERIVATIVE DECREASES.
  ! THE CUBIC STEP IS ONLY USED IF THE CUBIC TENDS TO INFINITY
  ! IN THE DIRECTION OF THE STEP OR IF THE MINIMUM OF THE CUBIC
  ! IS BEYOND STP. OTHERWISE THE CUBIC STEP IS DEFINED TO BE
  ! EITHER STPMIN OR STPMAX. THE QUADRATIC (SECANT) STEP IS ALSO
  ! COMPUTED AND IF THE MINIMUM IS BRACKETED THEN THE THE STEP
  ! CLOSEST TO STX IS TAKEN, ELSE THE STEP FARTHEST AWAY IS TAKEN.
  !
  ELSE IF (ABS(DG) < ABS(DX)) THEN
  INFO = 3
  BOUND = .TRUE.
  THETA = 3*(FX - FP)/(STP - STX) + DX + DG
  S = MAX(ABS(THETA), ABS(DX), ABS(DG))
  !
  !   THE CASE GAM = 0 ONLY ARISES IF THE CUBIC DOES NOT TEND
  !   TO INFINITY IN THE DIRECTION OF THE STEP.
  !
  GAM = S * SQRT( MAX(0.0D0, (THETA/S)**2 - (DX/S)*(DG/S)) )
  IF (STP > STX) GAM = -GAM
  P = (GAM - DG) + THETA
  Q = (GAM + (DX - DG)) + GAM
  R = P/Q
  IF (R < 0.0 .AND. GAM .NE. 0.0) THEN
  STPC = STP + R*(STX - STP)
  ELSE IF (STP > STX) THEN
  STPC = STPMAX
  ELSE
  STPC = STPMIN
  END IF
  STPQ = STP + (DG/(DG-DX))*(STX - STP)
  IF (BRACKT) THEN
  IF (ABS(STP-STPC) < ABS(STP-STPQ)) THEN
  STPF = STPC
  ELSE
  STPF = STPQ
  END IF
  ELSE
  IF (ABS(STP-STPC) > ABS(STP-STPQ)) THEN
  STPF = STPC
  ELSE
  STPF = STPQ
  END IF
  END IF
  !
  ! FOURTH CASE. A LOWER FUNCTION VALUE, DERIVATIVES OF THE
  ! SAME SIGN, AND THE MAGNITUDE OF THE DERIVATIVE DOES
  ! NOT DECREASE. IF THE MINIMUM IS NOT BRACKETED, THE STEP
  ! IS EITHER STPMIN OR STPMAX, ELSE THE CUBIC STEP IS TAKEN.
  !
  ELSE
  INFO = 4
  BOUND = .FALSE.
  IF (BRACKT) THEN
  THETA = 3*(FP - FY)/(STY - STP) + DY + DG
  S = MAX(ABS(THETA), ABS(DY), ABS(DG))
  GAM = S * SQRT( (THETA/S)**2 - (DY/S)*(DG/S) )
  IF (STP > STY) GAM = -GAM
  P = (GAM - DG) + THETA
  Q = ((GAM - DG) + GAM) + DY
  R = P/Q
  STPC = STP + R*(STY - STP)
  STPF = STPC
  ELSE IF (STP > STX) THEN
  STPF = STPMAX
  ELSE
  STPF = STPMIN
  END IF
  END IF

  !
  ! Update the interval of uncertainty. this update does not
  ! depend on the new step or the case analysis above.
  !
  IF (FP > FX) THEN
  STY = STP
  FY = FP
  DY = DG
  ELSE
  IF (SGND < 0.0) THEN
  STY = STX
  FY = FX
  DY = DX
  END IF
  STX = STP
  FX = FP
  DX = DG
  END IF

  !
  ! Compute the new step and safeguard it.
  !
  STPF = MIN(STPMAX, STPF)
  STPF = MAX(STPMIN, STPF)
  STP = STPF
  IF (BRACKT .AND. BOUND) THEN
  IF (STY > STX) THEN
  STP = MIN( STX + 0.66 * (STY-STX) , STP)
  ELSE
  STP = MAX( STX + 0.66 * (STY-STX) , STP)
  END IF
  END IF


end subroutine mcstep
