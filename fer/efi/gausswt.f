*
*  This software was developed by the Thermal Modeling and Analysis
*  Project(TMAP) of the National Oceanographic and Atmospheric
*  Administration's (NOAA) Pacific Marine Environmental Lab(PMEL),
*  hereafter referred to as NOAA/PMEL/TMAP.
*
*  Access and use of this software shall impose the following
*  obligations and understandings on the user. The user is granted the
*  right, without any fee or cost, to use, copy, modify, alter, enhance
*  and distribute this software, and any derivative works thereof, and
*  its supporting documentation for any purpose whatsoever, provided
*  that this entire notice appears in all copies of the software,
*  derivative works and supporting documentation.  Further, the user
*  agrees to credit NOAA/PMEL/TMAP in any publications that result from
*  the use of this software or in any product that includes this
*  software. The names TMAP, NOAA and/or PMEL, however, may not be used
*  in any advertising or publicity to endorse or promote any products
*  or commercial entity unless specific written permission is obtained
*  from NOAA/PMEL/TMAP. The user also understands that NOAA/PMEL/TMAP
*  is not obligated to provide the user with any support, consulting,
*  training or assistance of any kind with regard to the use, operation
*  and performance of this software nor to provide the user with any
*  updates, revisions, new versions or "bug fixes".
*
*  THIS SOFTWARE IS PROVIDED BY NOAA/PMEL/TMAP "AS IS" AND ANY EXPRESS
*  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
*  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
*  ARE DISCLAIMED. IN NO EVENT SHALL NOAA/PMEL/TMAP BE LIABLE FOR ANY SPECIAL,
*  INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
*  RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
*  CONTRACT, NEGLIGENCE OR OTHER TORTUOUS ACTION, ARISING OUT OF OR IN
*  CONNECTION WITH THE ACCESS, USE OR PERFORMANCE OF THIS SOFTWARE. 
*
C  Gausswt software From Billy Kessler, PMEL, Seattle WA  25-Aug-1998

C  !ACM Modified to pass nxaxis, NAY dimensions of grid and wate.
C   and to deal with nx, nz, or nm = 1.  Also to send cutoff as a parameter.


c.............subroutines to do gaussian-weighted mapping onto grids.

c.......3sep97: rewritten to give each nested loop a separate loop number.
c		otherwise "if (delx.gt.xcut) go to 100" does not work right!
c************************************************************************
c............sub gausswt forms the weight sums inside loop over all data.
c............--->>> 3-d mapping (x,y,t)
c............--->>> allows wraparound year (flagged by arg iwflag)
c............method is to call this sub for each data value
c............  sub loops on grid locations, maps each irregular data point to
c............  all possible gridpts, weighting by 3-d distance from gridpt.
c............  all calcs done in gridbox units
c............xx/x1/xf/xsc all in same units
c............yy/y1/yf/ysc all in same units
c............tt/t1/tf/tsc all in same units (but nm can be anzthing)
c............   note that, ie, t1 is the center of gridbox 1. So if dates
c............   are in months, Jan 15=1, Dec 15=12, and Jan 1=0.5, Dec 31=12.5.

c  i	xx,yy,tt=x/y/t location of data pt (data units)
c  i	val=data value at this (xx,yy,tt)
c  o	grid(nx,nz,nm)=sum of weighted values
c  o	wate(nx,nz,nm)=sum of weights
c  i	nx,nz,nm=size of grids
c  i	x1,y1,t1=west/south/date edge of grid (center of 1st box in data units)
c  i	xf,yf,tf=east/north/date edge of grid (center of final box)
c  i	xsc,ysc,tsc=mapping scales (data units)
c  i	iwflag=1 for time wrapping; 0 for no wrapping
c--------------------------------------------------------------------------

	subroutine gausswt (xx,yy,tt,val,grid,wate,nx,nz,nm,x1,y1,t1,
     .                    xf,yf,tf,xsc,ysc,tsc,iwflag,cutoff,nax,nay)
 
	integer nx, nz, nm, iwflag, nax, nay, i, j, m
	real grid(nax,nay,*), wate(nax,nay,*)
	real xx, yy, tt, val, x1, y1, t1, xf, yf, tf, xsc, ysc, tsc
	real cutoff, dx, dy, dt, xxg, yyg, ttg, xcut, ycut, tcut
	real xgp, delx, ygp, dely, tgp, delt, xgas, ygas, tgas, expn


	dx=1.
	dy=1. 
	dt=1.
	if (nx .gt. 1) dx=(xf-x1)/real(nx-1)  ! gridbox sizes in data units
	if (nz .gt. 1) dy=(yf-y1)/real(nz-1) 
	if (nm .gt. 1) dt=(tf-t1)/real(nm-1)

	xxg=(xx-x1)/dx+1.		  ! grid values of data location
	yyg=(yy-y1)/dy+1.
	ttg=(tt-t1)/dt+1.

c	cutoff=2.			  ! cutoff limits search (min wt=e**-4)
	xcut=cutoff*xsc/dx		  ! cutoffs scaled to grid units
	ycut=cutoff*ysc/dy		  ! look only cutoff* the scale width
	tcut=cutoff*tsc/dt		  !   from the gridbox center

	do 100 i=1,nx			  ! loop on x gridpoints
	xgp=real(i)			  ! center of gridbox
	delx=abs(xgp-xxg)		  ! distance of data pt from grid ctr
	if (delx.gt.xcut) go to 100  	  ! only do nearby points

	do 101 j=1,nz			  ! loop on y gridpoints, same procedure
	ygp=real(j)		
	dely=abs(ygp-yyg)
	if (dely.gt.ycut) go to 101

	do 102 m=1,nm			  ! loop on t gridpoints, same procedure
	tgp=real(m)
	delt=abs(tgp-ttg)
	if (delt.gt.tcut .and. iwflag.eq.1) 
     .		delt=abs(delt-real(nm)) 	! allow flagged time wrapping
	if (delt.gt.tcut) go to 102

	xgas=(delx*dx/xsc)**2		  	! make gaussian exponents
	ygas=(dely*dy/ysc)**2
	tgas=(delt*dt/tsc)**2
	expn=exp(-xgas-ygas-tgas)		! make the gaussian weight
	wate(i,j,m)=wate(i,j,m)+expn		! sum the weights
	grid(i,j,m)=grid(i,j,m)+val*expn	! sum the weighted values

102	continue
101	continue
100	continue

	return
	end

c************************************************************************
c............sub gaussfin divides weighted values by sum of weights
c............call this outside of summation loop.
c............for 2-d mapping, call gaussfin with nm=1.

	subroutine gaussfin (nx,nz,nm,grid,wate)

	integer nx, nz, nm, i, j, m
	real grid(nx,nz,nm),wate(nx,nz,nm)
	real realbad

        
	realbad=1.e35

	do 100 i=1,nx	! these extra loop number may not be necessary
	do 101 j=1,nz	! here, since there are no if-jumps and every
	do 102 m=1,nm	! element is goen through no matter what
	if (wate(i,j,m).gt.0.) then
		grid(i,j,m)=grid(i,j,m)/wate(i,j,m)
	else
		grid(i,j,m)=realbad
	endif
102	continue
101	continue
100	continue

	return
	end

c************************************************************************
c************************************************************************
c............sub gausswt-2d forms the weight sums inside loop over all data.
c............--->>> 2-d mapping (x,y)
c............--->>> allows wraparound year (flagged by arg iwflag) (use x -> t)
c............2-d also makes a grid of the number of obs/gridbox
c............method is to call this sub for each data value
c............  sub loops on grid locations, maps each irregular data point to
c............  all possible gridpts, weighting by 3-d distance from gridpt.
c............  all calcs done in gridbox units
c............xx/x1/xf/xsc all in same units
c............yy/y1/yf/ysc all in same units
c............after sum loop, use gaussfin to finish. Call gaussfin with nm=1.

c  i	xx,yy=x/y location of data pt (data units)
c  i	val=data value at this (xx,yy)
c  o	grid(nx,nz)=sum of weighted values
c  o	wate(nx,nz)=sum of weights
c  o	obs(nx,nz)=number of obs/box. See note.
c  i	nx,nz=size of grids
c  i	x1,y1=west/south edge of grid (center of 1st box in data units)
c  i	xf,yf=east/north edge of grid (center of final box)
c  i	xsc,ysc=mapping scales (data units)
c  i	iwflag=1 for time wrapping; 0 for no wrapping
c  Note: obs accumulates. If this sub is called repeatedly ==>> reset
c--------------------------------------------------------------------------

	subroutine gausswt_2d (xx,yy,val,grid,wate,obs,nx,nz,x1,y1,
     .			xf,yf,xsc,ysc,iwflag)

	integer nx, nz, iwflag, ig, jg, i, j
	real grid(nx,nz), wate(nx,nz)
	real obs(nx,nz)
	real xx, yy, val, x1, y1, xf, yf, xsc, ysc, dx, dy, xxg, yyg
	real cutoff, xcut, ycut, xgp, delx, ygp, dely, xgas, ygas, expn

	dx=(xf-x1)/real(nx-1)		  ! x-grid size in data units
	dy=(yf-y1)/real(nz-1) 

	xxg=(xx-x1)/dx+1.		  ! grid values of data location
	yyg=(yy-y1)/dy+1.

c.................save the number of obs in each gridbox
	ig=nint(xxg)
	jg=nint(yyg)
	if (ig.ge.1.and.ig.le.nx.and.jg.ge.1.and.jg.le.nz)
     .		obs(ig,jg)=obs(ig,jg)+1.

	cutoff=2.		 	  ! cutoff to limit search
	xcut=cutoff*xsc/dx		  ! look only twice the scale width
	ycut=cutoff*ysc/dy		  !   from the gridbox center

	do 100 i=1,nx			  ! loop on x gridpoints
	xgp=real(i)			  ! center of gridbox
	delx=abs(xgp-xxg)		  ! distance of data pt from grid ctr
	if (delx.gt.xcut .and. iwflag.eq.1) 
     .		delx=abs(delx-real(nx))   ! allow flagged time wrapping
	if (delx.gt.xcut) go to 100  	  ! only do nearby points

	do 101 j=1,nz			  ! loop on y gridpoints, same procedure
	ygp=real(j)		
	dely=abs(ygp-yyg)
	if (dely.gt.ycut) go to 101

	xgas=(delx*dx/xsc)**2		  	! make gaussian exponents
	ygas=(dely*dy/ysc)**2
	expn=exp(-xgas-ygas)		! make the gaussian weight
	wate(i,j)=wate(i,j)+expn	! sum the weights
	grid(i,j)=grid(i,j)+val*expn	! sum the weighted values

101	continue
100	continue

	return
	end
