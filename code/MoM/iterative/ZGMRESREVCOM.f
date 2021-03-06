*
      SUBROUTINE ZGMRESREVCOM(N, A, B, X, RESTRT, WORK, LDW, WORK2,
     $                  LDW2, ITER, RESID, INFO, NDX1, NDX2, SCLR1, 
     $                  SCLR2, IJOB)
*
*  -- Iterative template routine --
*     Univ. of Tennessee and Oak Ridge National Laboratory
*     October 1, 1993
*     Details of this algorithm are described in "Templates for the
*     Solution of Linear Systems: Building Blocks for Iterative
*     Methods", Barrett, Berry, Chan, Demmel, Donato, Dongarra,
*     EiITERkhout, Pozo, Romine, and van der Vorst, SIAM Publications,
*     1993. (ftp netlib2.cs.utk.edu; cd linalg; get templates.ps).
*
*     .. Scalar Arguments ..
      INTEGER            N, RESTRT, LDW, LDW2, ITER, INFO
      DOUBLE PRECISION   RESID
      INTEGER            NDX1, NDX2
      COMPLEX*16         SCLR1, SCLR2
      INTEGER            IJOB
*     ..
*     .. Array Arguments ..
      COMPLEX*16         B( * ), A( N, * ), X( * ), WORK( LDW,* ), WORK2( LDW2,* )
Cf2py intent(hide) N
Cf2py intent(in,out) X
Cf2py intent(in) RESTRT
Cf2py depend(n) RESTRT
Cf2py check((0<restrt) && (restrt<=n)) RESTRT
Cf2py intent(inout) WORK
Cf2py intent(hide) LDW
Cf2py intent(inout) WORK2
Cf2py intent(hide) LDW2
Cf2py intent(in,out) ITER
Cf2py intent(in,out) RESID
Cf2py intent(in,out) info
Cf2py intent(in,out) ndx1
Cf2py intent(in,out) ndx2
Cf2py intent(out) sclr1
Cf2py intent(out) sclr2
Cf2py intent(in,out) ijob
*     ..
*
*  Purpose
*  =======
*
*  GMRES solves the linear system Ax = b using the
*  Generalized Minimal Residual iterative method with preconditioning.
*
*  Arguments
*  =========
*
*  N       (input) INTEGER. 
*          On entry, the dimension of the matrix.
*          Unchanged on exit.
* 
*  B       (input) DOUBLE PRECISION array, dimension N.
*          On entry, right hand side vector B.
*          Unchanged on exit.
*
*  X       (input/output) DOUBLE PRECISION array, dimension N.
*          On input, the initial guess; on exit, the iterated solution.
*
*  RESTRT  (input) INTEGER
*          Restart parameter, .ls. = N. This parameter controls the amount
*          of memory required for matrix WORK2.
*
*  WORK    (workspace) DOUBLE PRECISION array, dimension (LDW,6+restrt).
*          Note that if the initial guess is the zero vector, then 
*          storing the initial residual is not necessary.
*
*  LDW     (input) INTEGER
*          The leading dimension of the array WORK. LDW .gt. = max(1,N).
*
*  WORK2   (workspace) DOUBLE PRECISION array, dimension (LDW2,2*RESTRT+2).
*          This workspace is used for constructing and storing the
*          upper Hessenberg matrix. The two extra columns are used to
*          store the Givens rotation matrices.
*
*  LDW2    (input) INTEGER
*          The leading dimension of the array WORK2.
*          LDW2 .gt. = max(2,RESTRT+1).
*
*  ITER    (input/output) INTEGER
*          On input, the maximum iterations to be performed.
*          On output, actual number of iterations performed.
*
*  RESID   (input/output) DOUBLE PRECISION
*          On input, the allowable error tolerance.
*          On ouput, the norm of the residual vector if solution
*          approximated to tolerance, otherwise reset to input
*          tolerance.
*
*  INFO    (output) INTEGER
*          =  0:  successful exit
*          =  1:  maximum number of iterations performed;
*                 convergence not achieved.
*            -5: Erroneous NDX1/NDX2 in INIT call.
*            -6: Erroneous RLBL.
*
*  NDX1    (input/output) INTEGER. 
*  NDX2    On entry in INIT call contain indices required by interface
*          level for stopping test.
*          All other times, used as output, to indicate indices into
*          WORK[] for the MATVEC, PSOLVE done by the interface level.
*
*  SCLR1   (output) DOUBLE PRECISION.
*  SCLR2   Used to pass the scalars used in MATVEC. Scalars are reqd because
*          original routines use dgemv.
*
*  IJOB    (input/output) INTEGER. 
*          Used to communicate job code between the two levels.
*
*  ============================================================
*
*     .. Parameters ..
      DOUBLE PRECISION    ZERO, ONE
      PARAMETER         ( ZERO = 0.0D+0, ONE = 1.0D+0 )
      COMPLEX*16          ZZERO, ZONE
      PARAMETER         ( ZZERO = (0.0D+0, 0.0D+0), 
     $                    ZONE = (1.0D+0, 0.0D+0) )
      INTEGER             OFSET
      PARAMETER         ( OFSET = 1000 )
*     ..
*     .. Local Scalars ..
      INTEGER             I, II, MAXIT, AV, GIV, H, R, S, V, W, Y,
     $                    NEED1, NEED2
      COMPLEX*16          ZDOTC
      COMPLEX*16          toz, TEMPOR
      DOUBLE PRECISION    BNRM2, RNORM, TOL, DZNRM2, 
     $                    DZAPPROXRES

*
*     indicates where to resume from. Only valid when IJOB = 2!
      INTEGER RLBL
*
*     saving all.
      SAVE
*
*     ..
*     .. External Routines ..
      EXTERNAL     ZAXPY, ZCOPY, ZDOTC, DZNRM2, ZSCAL
*     ..
*     .. Executable Statements ..
*
* Entry point, so test IJOB
      IF (IJOB .eq. 1) THEN
         GOTO 1
      ELSEIF (IJOB .eq. 2) THEN
*        here we do resumption handling
*         PRINT *, '(GOTO) RLBL = ', RLBL
         IF (RLBL .eq. 2) GOTO 2
         IF (RLBL .eq. 3) GOTO 3
         IF (RLBL .eq. 4) GOTO 4
         IF (RLBL .eq. 5) GOTO 5
         IF (RLBL .eq. 6) GOTO 6
         IF (RLBL .eq. 7) GOTO 7
*        if neither of these, then error
         INFO = -6
         GOTO 200
      ENDIF
*
* init.
*****************
 1    CONTINUE
*****************
*
      INFO = 0
      MAXIT = ITER
      TOL   = RESID
*
*     Alias workspace columns.
*
      R   = 1
      S   = 2
      W   = 3
      Y   = 4
      AV  = 5
      V   = 6
*
      H   = 1
      GIV = H + RESTRT
*
*     Check if caller will need indexing info.
*
      IF( NDX1.NE.-1 ) THEN
         IF( NDX1.EQ.1 ) THEN
            NEED1 = ((R - 1) * LDW) + 1
         ELSEIF( NDX1.EQ.2 ) THEN
            NEED1 = ((S - 1) * LDW) + 1
         ELSEIF( NDX1.EQ.3 ) THEN
            NEED1 = ((W - 1) * LDW) + 1
         ELSEIF( NDX1.EQ.4 ) THEN
            NEED1 = ((Y - 1) * LDW) + 1
         ELSEIF( NDX1.EQ.5 ) THEN
            NEED1 = ((AV - 1) * LDW) + 1
         ELSEIF( NDX1.EQ.6 ) THEN
            NEED1 = ((V - 1) * LDW) + 1
         ELSEIF( ( NDX1.GT.V*OFSET ) .AND.
     $           ( NDX1.LE.V*OFSET+RESTRT ) ) THEN
            NEED1 = ((NDX1-V*OFSET - 1) * LDW) + 1
         ELSEIF( ( NDX1.GT.GIV*OFSET ) .AND.
     $           ( NDX1.LE.GIV*OFSET+RESTRT ) ) THEN
            NEED1 = ((NDX1-GIV*OFSET - 1) * LDW) + 1
         ELSE
*           report error
            INFO = -5
            GO TO 100
         ENDIF
      ELSE
         NEED1 = NDX1
      ENDIF
*
      IF( NDX2.NE.-1 ) THEN
         IF( NDX2.EQ.1 ) THEN
            NEED2 = ((R - 1) * LDW) + 1
         ELSEIF( NDX2.EQ.2 ) THEN
            NEED2 = ((S - 1) * LDW) + 1
         ELSEIF( NDX2.EQ.3 ) THEN
            NEED2 = ((W - 1) * LDW) + 1
         ELSEIF( NDX2.EQ.4 ) THEN
            NEED2 = ((Y - 1) * LDW) + 1
         ELSEIF( NDX2.EQ.5 ) THEN
            NEED2 = ((AV - 1) * LDW) + 1
         ELSEIF( NDX2.EQ.6 ) THEN
            NEED2 = ((V - 1) * LDW) + 1
         ELSEIF( ( NDX2.GT.V*OFSET ) .AND.
     $           ( NDX2.LE.V*OFSET+RESTRT ) ) THEN
            NEED2 = ((NDX2-V*OFSET - 1) * LDW) + 1
         ELSEIF( ( NDX2.GT.GIV*OFSET ) .AND.
     $           ( NDX2.LE.GIV*OFSET+RESTRT ) ) THEN
            NEED2 = ((NDX2-GIV*OFSET - 1) * LDW) + 1
         ELSE
*           report error
            INFO = -5
            GO TO 100
         ENDIF
      ELSE
         NEED2 = NDX2
      ENDIF
*
*     Set initial residual.
*
      CALL ZCOPY( N, B, 1, WORK(1,R), 1 )
      IF ( DZNRM2( N, X, 1 ).NE.ZERO ) THEN
************         CALL MATVEC( N, A, -ZONE, X, ZONE, WORK(1,R) )
*        Note: using X directly
         SCLR1 = -ZONE
         SCLR2 = ZONE
         NDX1 = -1
         NDX2 = ((R - 1) * LDW) + 1
*
*        Prepare for resumption & return
         RLBL = 2
         IJOB = 1
         RETURN
*
*****************
 2       CONTINUE
*****************
*
         IF ( DZNRM2( N, WORK(1,R), 1 ).LT.TOL ) GO TO 200
      ENDIF
      BNRM2 = DZNRM2( N, B, 1 )
      IF ( BNRM2.EQ.ZERO ) BNRM2 = ONE
*
      ITER = 0
   10 CONTINUE
*
         ITER = ITER + 1
*
*        Construct the first column of V, and initialize S to the
*        elementary vector E1 scaled by RNORM.
*
*********CALL PSOLVE( WORK( 1,V ), WORK( 1,R ) )
*
         NDX1 = ((V - 1) * LDW) + 1
         NDX2 = ((R - 1) * LDW) + 1
*        Prepare for return & return
         RLBL = 3
         IJOB = 2
         RETURN
*
*****************
 3       CONTINUE
*****************
*
         RNORM = DZNRM2( N, WORK( 1,V ), 1 )
         toz = ONE/RNORM
         CALL ZSCAL( N, toz, WORK( 1,V ), 1 )
         
         TEMPOR = ZZERO
         DO 41 II = 1, N
           TEMPOR = TEMPOR + WORK( II,V )
 41      CONTINUE
*         PRINT *, 'SUM(V[:,0]) = ', TEMPOR
         
         CALL ZELEMVEC( 1, N, RNORM, WORK( 1,S ) )
*
*         DO 50 I = 1, RESTRT
         i = 1
 49      if (i.gt.restrt) go to 50
*
************CALL MATVEC( ONE, WORK( 1,V+I-1 ), ZERO, WORK( 1,AV ) )
****************         CALL MATVEC( N, A, ZONE, WORK( 1,V+I-1 ), ZZERO, WORK(1,AV) )
         NDX1 = ((V+I-1 - 1) * LDW) + 1
         NDX2 = ((AV    - 1) * LDW) + 1
*        Prepare for return & return
         SCLR1 = ONE
         SCLR2 = ZERO
         RLBL = 4
         IJOB = 3
         RETURN
*
*****************
 4       CONTINUE
*****************
*
*********CALL PSOLVE( WORK( 1,W ), WORK( 1,AV ) )
*
*********************        CALL MATVEC( N, A, ZONE, WORK( 1,V+I-1 ), ZZERO, WORK(1,W) )
         NDX1 = ((W  - 1) * LDW) + 1
         NDX2 = ((AV - 1) * LDW) + 1
*        Prepare for return & return
         RLBL = 5
         IJOB = 2
         RETURN
*
*****************
 5       CONTINUE
*****************
*
*           Construct I-th column of H so that it is orthnormal to 
*           the previous I-1 columns.
*
           TEMPOR = ZZERO
           DO 42 II = 1, N
             TEMPOR = TEMPOR + WORK( II,W )
 42        CONTINUE
*           PRINT *,'SUM1(W) = ', TEMPOR
           
           
           
           CALL ZORTHOH( I, N, H, WORK2, LDW2, WORK( 1,V ), LDW,
     $                   WORK( 1,W ) )
           TEMPOR = ZZERO
           DO 43 II = 1, N
             TEMPOR = TEMPOR + WORK( II,W )
 43        CONTINUE
*           PRINT *,'SUM2(W) = ', TEMPOR

*
            IF ( I.GT.0 ) THEN
*
*              Apply Givens rotations to the I-th column of H. This
*              effectively reduces the Hessenberg matrix to upper
*              triangular form during the RESTRT iterations.
*
               CALL ZAPPLYGIVENS(I, H, WORK2, LDW2, GIV )
            ENDIF
*           Approximate residual norm. Check tolerance. If okay, compute
*           final approximation vector X and quit.
*
            RESID = DZAPPROXRES( I, H, WORK2, WORK( 1,S ),
     $                          GIV, LDW2 ) / BNRM2
            IF ( RESID.LE.TOL ) THEN
               CALL ZUPDATE(I, N, X, H, WORK2, LDW2, 
     $                     WORK(1,Y), WORK(1,S), WORK( 1,V ), LDW)
               GO TO 200
            ENDIF
            i = i + 1
            go to 49
   50    CONTINUE
         i = restrt
*
*        Compute current solution vector X.
*
         CALL ZUPDATE(RESTRT, N, X, H, WORK2, LDW2,
     $               WORK(1,Y), WORK( 1,S ), WORK( 1,V ), LDW )
*
*        Compute residual vector R, find norm,
*        then check for tolerance.
*
         CALL ZCOPY( N, B, 1, WORK( 1,R ), 1 )
*********CALL MATVEC( -ONE, X, ONE, WORK( 1,R ) )
*         CALL MATVEC( N, A, -ZONE, X, ZONE, WORK(1,R) )
         NDX1 = -1
         NDX2 = ((R - 1) * LDW) + 1
*        Prepare for return & return
         SCLR1 = -ONE
         SCLR2 = ONE
         RLBL = 6
         IJOB = 1
         RETURN
*
*****************
 6       CONTINUE
*****************
         WORK( RESTRT+1,S ) = DZNRM2( N, WORK( 1,R ), 1 )
*
*         RESID = WORK( I+1,S ) / BNRM2
*         IF ( RESID.LE.TOL  ) GO TO 200
*
         NDX1 = NEED1
         NDX2 = NEED2
*        Prepare for resumption & return
         RLBL = 7
         IJOB = 4
         RETURN
*
*****************
 7       CONTINUE
*****************
         IF( INFO.EQ.1 ) GO TO 200
*
         IF ( ITER.EQ.MAXIT ) THEN
            INFO = 1
            GO TO 100
         ENDIF
*
         GO TO 10
*
  100 CONTINUE
*
*     Iteration fails.
*
      PRINT *, 'MISERABLE FAILURE DUMMY!'
      RLBL = -1
      IJOB = -1
      RETURN
*
  200 CONTINUE
*
*     Iteration successful; return.
*
      INFO = 0
      RLBL = -1
      IJOB = -1

      RETURN
*
*     End of GMRESREVCOM
*
      END SUBROUTINE ZGMRESREVCOM
*
*     =========================================================
      SUBROUTINE ZORTHOH( I, N, H, SPACE2, LDW2, V, LDV, W )
*
      INTEGER            I, II, N, H, LDW2, LDV
      COMPLEX*16         SPACE2( LDW2,* ), W( * ), V( LDV,* )
*
*     Construct the I-th column of the upper Hessenberg matrix H
*     using the Gram-Schmidt process on V and W.
*
      INTEGER            K
      DOUBLE PRECISION   DZNRM2, ONE
      PARAMETER        ( ONE = 1.0D+0 )
      COMPLEX*16         ZDOTC, TEMPOR, ZZERO
      PARAMETER        ( ZZERO = (0.0D+0, 0.0D+0) )
      EXTERNAL           ZAXPY, ZCOPY, ZDOTC, DZNRM2, ZSCAL
*
      DO 10 K = 1, I
         SPACE2( K,I+H-1 ) = ZDOTC( N, V( 1,K ), 1, W, 1 )
         CALL ZAXPY( N, -SPACE2( K,I+H-1 ), V( 1,K ), 1, W, 1 )
   10 CONTINUE
      SPACE2( I+1,I+H-1 ) = DZNRM2( N, W, 1 )
      CALL ZCOPY( N, W, 1, V( 1,I+1 ), 1 )
      CALL ZSCAL( N, ONE / SPACE2( I+1,I+H-1 ), V( 1,I+1 ), 1 )
      
      TEMPOR = ZZERO
      DO 42 II = 1, N
        TEMPOR = TEMPOR + W( II )
 42   CONTINUE
*      PRINT *,'SUM(W) = ', TEMPOR
      
      TEMPOR = ZZERO
      DO 43 II = 1, N
        TEMPOR = TEMPOR + V( II,I+1 )
 43   CONTINUE
*      PRINT *,'SUM(V[:, i+1]) = ', TEMPOR
*
      RETURN
*
      END SUBROUTINE ZORTHOH
*     =========================================================
      SUBROUTINE ZAPPLYGIVENS( I, H, SP2, LDW2, GIV )
*
      INTEGER            I, H, LDW2, GIV
      COMPLEX*16         SP2( LDW2,* )
*
*     This routine applies a sequence of I-1 Givens rotations to
*     the I-th column of H. The Givens parameters are stored, so that
*     the first I-2 Givens rotation matrices are known. The I-1st
*     Givens rotation is computed using BLAS 1 routine DROTG. Each
*     rotation is applied to the 2x1 vector [H( J ), H( J+1 )]',
*     which results in H( J+1 ) = 0.
*
      INTEGER            J, C, G
*      DOUBLE PRECISION   TEMP
      EXTERNAL           ZROTG
*
*     .. Executable Statements ..
*
*     Construct I-1st rotation matrix.
*
*     CALL ZROTG( H( I ), H( I+1 ), GIVENS( I,1 ), GIVENS( I,2 ) )
*      CALL ZGETGIV( H( I ), H( I+1 ), GIVENS( I,1 ), GIVENS( I,2 ) )
*
*     Apply 1,...,I-1st rotation matrices to the I-th column of H.
*
      C = I+H-1
      G = GIV
      DO 10 J = 1, I-1
         CALL ZROTVEC( SP2(J,C), SP2(J+1,C), SP2(J,G), SP2(J,G+1) )
*        TEMP     =  GIVENS( J,1 ) * H( J ) + GIVENS( J,2 ) * H( J+1 ) 
*        H( J+1 ) = -GIVENS( J,2 ) * H( J ) + GIVENS( J,1 ) * H( J+1 )
*        H( J ) = TEMP
 10   CONTINUE
      call Zgetgiv( SP2(I,C), SP2(I+1,C), SP2(I,G), SP2(I,G+1) )
      call Zrotvec( SP2(I,C), SP2(I+1,C), SP2(I,G), SP2(I,G+1) )
*
      RETURN
*
      END SUBROUTINE ZAPPLYGIVENS
*
*     ===============================================================
      DOUBLE PRECISION FUNCTION DZAPPROXRES( I, H, SP2, S, GIV, LDW2 )
*
      INTEGER            I, H, GIV, LDW2
      COMPLEX*16         SP2( LDW2,* ), S( * )
*
*     This func allows the user to approximate the residual
*     using an updating scheme involving Givens rotations. The
*     rotation matrix is formed using [H( I ),H( I+1 )]' with the
*     intent of zeroing H( I+1 ), but here is applied to the 2x1
*     vector [S(I), S(I+1)]'.
*
      INTRINSIC          ZABS
      EXTERNAL           ZROTG
*
*     .. Executable Statements ..
*
*     CALL ZROTG( H( I ), H( I+1 ), GIVENS( I,1 ), GIVENS( I,2 ) )
*      CALL ZGETGIV( H( I ), H( I+1 ), SP2(I,GIV), SP2(I,GIV+1) )
      CALL ZROTVEC( S( I ), S( I+1 ), SP2(I,GIV), SP2(I,GIV+1) )
*
      DZAPPROXRES = ZABS( S( I+1 ) )
*
      RETURN
*
      END FUNCTION DZAPPROXRES
*     ===============================================================
      SUBROUTINE ZUPDATE( I, N, X, H, SP2, LDW2, Y, S, V, LDV )
*
      INTEGER            N, I, H, J, LDW2, LDV
      COMPLEX*16         X(*), Y(*), S(*), SP2(LDW2,*), V(LDV,*)
      EXTERNAL           ZAXPY, ZCOPY, ZTRSV
*
*     Solve H*y = s for upper triangualar H.
*
      CALL ZCOPY( I, S, 1, Y, 1 )
      CALL ZTRSV('UPPER','NOTRANS','NONUNIT',I,SP2(1,H),LDW2,Y,1)
*
*     Compute current solution vector X.
*
      DO 10 J = 1, I
         CALL ZAXPY( N, Y( J ), V( 1,J ), 1, X, 1 )
   10 CONTINUE
*
      RETURN
*
      END SUBROUTINE ZUPDATE
*
*     ===============================================================
      SUBROUTINE ZGETGIV( A, B, C, S )
*
      COMPLEX*16   A, B, C, S, TEMP, ZERO, ONE
      PARAMETER  ( 
     $     ZERO = 0.0, 
     $     ONE = 1.0 )
*
      IF ( ABS( B ).EQ.ZERO ) THEN
         C = ONE
         S = ZERO
      ELSE IF ( ABS( B ).GT.ABS( A ) ) THEN
         TEMP = -A / B
         S = ONE / SQRT( ONE + abs(TEMP)**2 )
         C = TEMP * S
*         S = b / SQRT( abs(a)**2 + abs(b)**2 )
*         C = -a / SQRT( abs(a)**2 + abs(b)**2 )
      ELSE
         TEMP = -B / A
         C = ONE / SQRT( ONE + abs(TEMP)**2 )
         S = TEMP * C
*         S = -b / SQRT( abs(a)**2 + abs(b)**2 )
*         C = a / SQRT( abs(a)**2 + abs(b)**2 )
      ENDIF
*
      RETURN
*
      END SUBROUTINE ZGETGIV
*
*     ================================================================
      SUBROUTINE ZROTVEC( X, Y, C, S )
*
      COMPLEX*16   X, Y, C, S, TEMP

*     TEMP = <co= , ,conjg,conjg>(C) * X - <co>(S) * Y
      TEMP = conjg(C) * X - conjg(S) * Y
      Y    = S * X + C * Y
      X    = TEMP
*
      RETURN
*
      END SUBROUTINE ZROTVEC
*
*     ===============================================================
      SUBROUTINE ZELEMVEC( I, N, ALPHA, E )
*
*     Construct the I-th elementary vector E, scaled by ALPHA.
*
      INTEGER            I, J, N
      COMPLEX*16         ALPHA, E( * )
*
*     .. Parameters ..
      DOUBLE PRECISION   ZERO
      PARAMETER        ( ZERO = 0.0D+0 )
*
      DO 10 J = 1, N
         E( J ) = ZERO
   10 CONTINUE
      E( I ) = ALPHA
*
      RETURN
*
      END SUBROUTINE ZELEMVEC

*     ===============================================================
      SUBROUTINE MATVEC( N, A, ALPHA, X, BETA, Y )
*
*     performs Y = A*X
*
      COMPLEX*16         ALPHA, BETA
      INTEGER            INCX, INCY, N
      PARAMETER        ( INCX = 1, INCY = 1 )
      CHARACTER*1        TRANS
      PARAMETER        ( TRANS = 'N')
      COMPLEX*16         A( N, * ), X( * ), Y( * )
      EXTERNAL           ZGEMV

      CALL ZGEMV ( TRANS, N, N, ALPHA, A, N, X, INCX,
     $                   BETA, Y, INCY )

      RETURN

      END SUBROUTINE MATVEC
