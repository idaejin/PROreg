BBmm <- function(fixed.formula,random.formula=NULL,Z=NULL,nRandComp=NULL,m,data=list(),method="BB-NR",maxiter=50,show=FALSE){

  if ((is.null(random.formula))&(is.null(Z))){
    stop("Random part of the model must be especified")
  }

  if ((is.null(random.formula)==FALSE)&(is.null(Z))==FALSE){
    stop("Random part of the model has been specified twice")
  }

  if ((is.null(Z)==FALSE)&(is.null(nRandComp))){
    stop("Number of random components must be specified")
  }

  if ((is.null(Z))&(is.null(nRandComp)==FALSE)){
    stop("Number of random components must be specified only when Z is defined")
  }

  if (is.null(Z)==FALSE){
    if (dim(Z)[2]!=sum(nRandComp)){
      stop("The number of random effects in each random component must match with the number of columns of the design matrix Z")
    }
  }

  if ((method=="BB-NR") | (method=="rootSolve")){
  } else{
    stop("The choosen estamation method is not adequate")
  }

  if (maxiter!=as.integer(maxiter)){
    stop("maxiter must be integer")
  }

  if(maxiter<=0){
    stop("maxiter must be positive")
  }

  if (sum(as.integer(m)==m)==length(m)){
  } else{
    stop("m must be integer")
  }

  if (min(m)<=0){
    stop("m must be positive")
  }

  # Fixed effects design matrix:
  fixed.mf <- model.frame(formula=fixed.formula, data=data)
  X <- model.matrix(attr(fixed.mf, "terms"), data=fixed.mf)
  q <- dim(X)[2]

  # Outcome variable:
  y <- model.response(fixed.mf)
  nObs <- length(y)
  # Balanced data
  if(length(m)==1){
    balanced <- "yes"
    m. <- rep(m,nObs)
  } else{
    m. <- m
    if (sum(m[1]==m)==length(m)){
      balanced <- "yes"
    } else{
      balanced <- "no"
    }
  }

  if (sum(as.integer(y)==y)==length(y)){
  } else {
    stop("y must be integer")
  }

  if ((length(m)==1) | (length(m)==length(y))){
  } else{
    stop("m must be a number, or a vector of the length of y")
  }

  if (max(y-m)>0 | min(y) < 0){
    stop("y must be bounded between 0 and m")
  }

  # Specifiying random effects structure
  if (is.null(random.formula)){
    nComp <- length(nRandComp) # Number of random components, number of u,v...
    nRand <- dim(Z)[2] # Number of random effects, number of u_i,v_i,..
    namesRand <- as.character(seq(1,nComp,1))
  } else {
    # Random effects design matrix:
    random.mf <- model.frame(formula=update(random.formula,~.-1), data=data)
    nComp <- dim(random.mf)[2] # Number of random components, number of u,v...
    nRandComp <- NULL # Number of random effects in each random components, number of u_i in u.
    Z <- NULL
    for(i in 1:nComp){
      z <- model.matrix(~random.mf[,i]-1)
      Z <- cbind(Z,z)
      nRandComp <- c(nRandComp,dim(z)[2])
    }
    nRand <- dim(Z)[2] # Number of random effects, number of u_i,v_i,..
    namesRand <- names(random.mf)
  }

  # Initial values
  iter <- 0
  BB <- BBreg(fixed.formula,m,data)
  beta <- BB$coefficients
  u <- rep(0,nRand)
  eta <- X%*%beta+Z%*%u

  phi <- BB$phi
  all.sigma <- rep(0.5,nComp)
  disp.Comp <- c(phi,all.sigma)

  # Variance-covariance matrix of random effects
  d <- d. <- NULL
  for (i in 1:nComp){
    d <- c(d,rep((all.sigma[i])^2,nRandComp[i]))
    d. <- c(d.,rep(1/(all.sigma[i])^2,nRandComp[i]))
  }
  D <- diag(d)
  D. <- diag(d.)

  OLDdisp.Comp <- rep(Inf,nComp+1)
  OLDeta <- rep(Inf,nObs)

  # loop
  while((max(abs(disp.Comp-OLDdisp.Comp))>0.001) | (max(abs(eta-OLDeta)/eta)>0.001)){

    OLDdisp.Comp <- disp.Comp
    OLDeta <- eta

    # Fixed and random effects estimation
    if (method=="BB-NR"){
      rand.fix <- EffectsEst.BBNR(y,m.,beta,u,p,phi,D.,X,Z,maxiter)
      if (rand.fix$conv=="no"){
        print("The method has not converged")
        out <- list(conv="no")
        return(out)
      }
    } else {
      rand.fix <- EffectsEst.multiroot(y,m.,beta,u,phi,D.,X,Z)
    }

    ####
    if (show==TRUE){
      cat("Beta:",rand.fix$fixed.est,"\n")
      cat("Random:",rand.fix$random.est,"\n")
    }
    ####

    beta <- rand.fix$fixed.est
    u <- rand.fix$random.est
    eta <- X%*%beta+Z%*%u
    p <- 1/(1+exp(-eta))
    # Rewrite possible 1 or 0 p
    for (i in 1:nObs){
      if (p[i]<0.001){
        p[i] <- 0.001
      }
      if (p[i]>0.999){
        p[i] <- 0.999
      }
    }
    effects.iter <- rand.fix$iter

    # Estimation of dispersion parameter phi
    thetaest <- VarEst(y,m.,p,X,Z,u,nRand,nComp,nRandComp,all.sigma,phi,q)
    phi <- thetaest$phi
    all.sigma <- thetaest$all.sigma

    ####
    if(show==TRUE){
      cat("Phi:",phi,"\n")
      cat("Sigma:",all.sigma,"\n")
    }
    ####


    #Renewing the D
    d. <- NULL
    for (i in 1:nComp){
      d. <- c(d.,rep(1/(all.sigma[i])^2,nRandComp[i]))
    }
    D. <- diag(d.)

    disp.Comp <- c(phi,all.sigma)
    iter <- iter+1
    cat("Iteration number:",iter,"\n")

    if (iter==maxiter){
      warning("Maximum iteration number has been reached without convergence")
      out <- list(conv="no")
      return(out)
    }
  }

  # Random components names
  names(u) <- seq(1:length(u))

  # Variances of the fixed effects
  eta <- X%*%beta+Z%*%u
  p <- 1/(1+exp(-eta))
  S <- diag(c(p*(1-p)))
  t <- NULL
  v <- NULL
  for (j in 1:nObs){
    t1 <- 0
    t2 <- 0
    v1 <- 0
    v2 <- 0
    if (y[j]==0){
      t1 <- 0
      v1 <- 0
    }else{
      for (k in 0:(y[j]-1)){
        t1 <- t1+1/(p[j]+k*phi)
        v1 <- v1+1/((p[j]+k*phi)^2)
      }
    }
    if (y[j]==m.[j]){
      t2 <- 0
      v2 <- 0
    }else{
      for (k in 0:(m.[j]-y[j]-1)){
        t2 <- t2+1/(1-p[j]+k*phi)
        v2 <- v2+1/((1-p[j]+k*phi)^2)
      }
    }
    t <- c(t,t1-t2)
    v <- c(v,v1+v2)
  }

  V <- diag(c(v))
  fixed.vcov <- solve(t(X)%*%S%*%V%*%S%*%X)

  # Variance of random components
  all.sigma.var <- thetaest$all.sigma.var
  psi <- thetaest$psi
  psi.var <- thetaest$psi.var

  # Variances of dispersion components

  # Fitted values
  fitted.eta <- X%*%beta+Z%*%u
  fitted <- 1/(1+exp(-(X%*%beta+Z%*%u)))

  # Convergence
  conv <- "yes"

  # Deviance and null deviance
  e <- sum(y)/sum(m.)
  l1 <- l2 <- 0
  l1. <- l2. <- 0
  l1.null <- l2.null <- 0
  l3 <- 0
  for (j in 1:nObs){

    t1 <- 0
    t1. <- 0
    t1.null <- 0
    if (y[j]==0){
    }else{
      for (k in 0:(y[j]-1)){
        t1 <- t1+log(fitted[j]+k*phi)
        t1. <- t1.+log(y[j]/m.[j]+k*phi)
        t1.null <- t1.null+log(e+k*phi)
      }
    }
    l1 <- l1+t1
    l1. <- l1.+t1.
    l1.null <- l1.null+t1.null

    t2 <- 0
    t2. <- 0
    t2.null <- 0
    if (y[j]==m.[j]){
    }else{
      for (k in 0:(m.[j]-y[j]-1)){
        t2 <- t2+log(1-fitted[j]+k*phi)
        t2. <- t2.+log(1-y[j]/m.[j]+k*phi)
        t2.null <- t2.null+log(1-e+k*phi)
      }
    }
    l2 <- l2+t2
    l2. <- l2.+t2.
    l2.null <- l2.null+t2.null
  }
  deviance <- -2*((l1+l2)-(l1.+l2.))
  null.deviance <- -2*((l1.null+l2.null)-(l1.+l2.))
  df <- nObs-length(beta)-length(all.sigma)-1
  null.df <- nObs-1-length(all.sigma)-1

  out <- list(fixed.coef=beta,fixed.vcov=fixed.vcov,
              random.coef=u,sigma.coef=all.sigma,sigma.var=all.sigma.var,
              phi.coef=phi,psi.coef=psi,psi.var=psi.var,
              fitted.values=fitted,conv=conv,
              deviance=deviance,df=df,null.deviance=null.deviance,null.df=null.df,
              nRand=nRand,nRandComp=nRandComp,namesRand=namesRand,
              iter=iter,nObs=nObs,
              y=y,X=X,Z=Z,D=D,
              balanced=balanced,m=m,
              conv=conv)

  class(out) <- "BBmm"

  out$call <- match.call()
  out$formula <- formula

  out
}



print.BBmm <- function(x,...){
  cat("Call:\t")
  print(x$call)
  cat("\nFixed effects estimation:\n")
  print(x$fixed.coef)
  cat("\n")
  cat("\nStandard deviation of normal random effects:\n")
  for (i in 1:length(x$namesRand)){
    cat(x$namesRand[i], x$sigma.coef[i])
    cat("\n")
  }
  cat("\nBeta-binomial dispersion parameter:",x$phi.coef,"\n")

  cat("\nDeviance of the model:",x$deviance)
  #  cat("\nNull deviance of the model:",x$null.deviance)
  cat("\nNumber of iterations:",x$iter)
  if(x$balanced=="yes"){
    cat("\nBalanced data, maximum score number:", x$m,"\n")
  } else {
    cat("\nNo balanced data.\n")
  }
}



summary.BBmm <- function(object,...){

  # Fixed
  fixed.se <- sqrt(diag(object$fixed.vcov))
  fixed.tval <- object$fixed.coef/fixed.se
  fixed.TAB <- cbind(object$fixed.coef,fixed.se,fixed.tval,2*pnorm(-abs(fixed.tval)))
  colnames(fixed.TAB) <- c("Estimate","StdErr","t.value","p.value")

  #phi
  psi.table <- cbind(object$psi.coef,sqrt(object$psi.var))
  rownames(psi.table) <- "log(phi)"
  colnames(psi.table) <- c("Estimate","StdErr")

  #Sigma
  sigma.table <- cbind(object$sigma.coef,sqrt(object$sigma.var))
  rownames(sigma.table) <- object$namesRand
  colnames(sigma.table) <- c("Estimate","StdErr")

  #Deviance goodness-of-fit test

  Chi <- object$null.deviance-object$deviance
  Chi.p.value <- 1-pchisq(Chi,object$null.df-object$df)

  # output
  res <- list(call=object$call,fixed.coefficients=fixed.TAB,
              sigma.table=sigma.table,psi.table=psi.table,
              random.coef=object$random.coef,
              iter=object$iter,nObs=object$nObs,
              nRand=object$nRand,nComp=object$nComp,nRandComp=object$nRandComp,
              deviance=object$deviance,df=object$df,
              null.deviance=object$null.deviance,null.df=object$null.df,
              Goodness.of.fit=Chi.p.value,
              balanced=object$balanced,m=object$m,
              conv=object$conv)

  class(res) <- "summary.BBmm"
  res
}

print.summary.BBmm <- function(x,...){
  cat("Call:\t")
  print(x$call)


  cat("\nFixed effects coefficients:\n")
  cat("\n")
  printCoefmat(x$fixed.coefficients,P.values=TRUE,has.Pvalue=TRUE)
  cat("\n---------------------------------------------------------------\n")
  cat("Random effects dispersion parameter(s):\n")
  cat("\n")
  print(x$sigma.table)
  cat("\n---------------------------------------------------------------\n")
  cat("Logarithm of beta-binomial dispersion parameter log(phi):\n")
  cat("\n")
  print(x$psi.table)
  cat("\n---------------------------------------------------------------\n")

  cat("Deviance of the model:",x$deviance,"; with", x$df,"degrees of freedom.\n")
  cat("Deviance of the null model",x$null.deviance,"; with", x$null.df ,"degrees of freedom.\n")
  cat("Deviance goodness-of-fit test p-value:",x$Goodness.of.fit,"\n")

  cat("\nNumber of observations:",x$nObs)
  cat("\nNumber of iterations:", x$iter)
  if(x$balanced=="yes"){
    cat("\nBalanced data, maximum score number:", x$m)
  } else {
    cat("\nNo balanced data.")
  }
  cat("\nNumber of random effects in each random component:",x$nRandComp,"\n")
  cat("\n")
}
