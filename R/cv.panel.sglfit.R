#' Cross-validation fit for panel sg-LASSO
#' 
#' @description 
#' Does k-fold cross-validation for panel data sg-LASSO regression model.
#' 
#' The function runs \code{sglfit} \code{nfolds+1} times; the first to get the path solution in \ifelse{html}{\out{&lambda;}}{\eqn{\lambda}} sequence, the rest to compute the fit with each of the folds omitted. 
#' The average error and standard deviation over the folds is computed, and the optimal regression coefficients are returned for \code{lam.min} and \code{lam.1se}. Solutions are computed for a fixed \ifelse{html}{\out{&alpha;}}{\eqn{\alpha}.}
#'
#' @details
#' The cross-validation is run for sg-LASSO linear model. The sequence of linear regression models implied by \ifelse{html}{\out{&lambda;}}{\eqn{\lambda}} vector is fit by block coordinate-descent. The objective function is
#' \ifelse{html}{\out{<br><br> <center> RSS(&alpha;,&beta;)/T + 2&lambda;  &Omega;<sub>&gamma;</sub>(&beta;), </center> <br>}}{\deqn{RSS(\alpha,\beta)/T + 2\lambda * \Omega_\gamma(\beta),}} 
#'  where \ifelse{html}{\out{RSS(&alpha;,&beta;)}}{\eqn{RSS(\alpha,\beta)}} is the least squares fit. The penalty function \ifelse{html}{\out{&Omega;<sub>&gamma;</sub>(.)}}{\eqn{\Omega_\gamma(.)}} is applied on  \ifelse{html}{\out{&beta;}}{\eqn{\beta}} coefficients with the following structure 
#'  \ifelse{html}{\out{<br> <br> <center> &Omega;<sub>&gamma;</sub>(&beta;) = &gamma; |&beta;|<sub>1</sub> + (1-&gamma;)||&beta;||<sub>2,1</sub>. </center> <br>}}{\deqn{\Omega_\gamma(\beta) = \gamma |\beta|_1 + (1-\gamma)||\beta||_{2,1}.}} 
#'  The penalty is a convex combination of LASSO and group LASSO penalty functions. Tuning parameter \ifelse{html}{\out{&lambda;}}{\eqn{\lambda}} is chosen based on k-fold cross-validation and optimal solutions are returned for the minimum cvm (lam.min) or within 1 standard error of the minimum (lam.1se).
#' @usage 
#' cv.panel.sglfit(x, y, lambda = NULL, gamma = 1.0, gindex = 1:p, nfolds = 10, foldid, method = c("pooled", "fe"), nf = NULL, ...)
#' @param x T by p data matrix, where t and p respectively denote the sample size and the number of regressors.
#' @param y T by 1 response variable.
#' @param lambda a user-supplied lambda sequence. By leaving this option unspecified (recommended), users can have the program compute its own \ifelse{html}{\out{&lambda;}}{\eqn{\lambda}} sequence based on \ifelse{html}{\out{<code>nlambda</code>}}{\code{nlambda}} and \ifelse{html}{\out{&gamma;}}{\eqn{\gamma}} \code{lambda.factor.} It is better to supply, if necessary, a decreasing sequence of lambda values than a single (small) value, as warm-starts are used in the optimization algorithm. The program will ensure that the user-supplied \code{lambda} sequence is sorted in decreasing order before fitting the model.
#' @param gamma sg-LASSO mixing parameter. \ifelse{html}{\out{&gamma;}}{\eqn{\gamma}} = 1 gives LASSO solution and \ifelse{html}{\out{&gamma;}}{\eqn{\gamma}} = 0 gives group LASSO solution.
#' @param gindex p by 1 vector indicating group membership of each covariate.
#' @param nfolds number of folds of the cv loop. Default set to \code{10}.
#' @param foldid the fold assignments used.
#' @param method choose between 'pooled' and 'fe'; 'pooled' forces the intercept to be fitted in \link{sglfit}, 'fe' computes the fixed effects. User must input the number of fixed effects \code{nf} for \code{method = 'fe'}, and it is recommended to do so for \code{method = 'pooled'}. Program uses supplied \code{nf} to construct \code{foldsid}. Default is set to \code{method = 'pooled'}.
#' @param nf number of fixed effects. Used only if \code{method = 'fe'}.
#' @param ... Other arguments that can be passed to \code{sglfit}.
#' @return cv.panel.sglfit object.
#' @author Jonas Striaukas
#' @examples
#' \donttest{ 
#' set.seed(1)
#' x = matrix(rnorm(100 * 20), 100, 20)
#' beta = c(5,4,3,2,1,rep(0, times = 15))
#' y = x%*%beta + rnorm(100)
#' gindex = sort(rep(1:4,times=5))
#' cv.panel.sglfit(x = x, y = y, gindex = gindex, gamma = 0.5, method = "fe", nf = 10)
#' }
#' @export cv.panel.sglfit
cv.panel.sglfit <- function(x, y, lambda = NULL, gamma = 1.0, gindex = 1:p, nfolds = 10, foldid, method = c("pooled", "fe"), nf = NULL, ...) {
  method <- match.arg(method)
  if (method == "fe" && is.null(nf))
    stop("for fe method nf must supplied.")
  
  if (method == "pooled" && is.null(nf))
    warning("'nf' is not supplied. it is recommended to supply 'nf' for pooled panel data regression to create folds over time dimension.")
  
  p <- ncol(x)
  NT <- nrow(x)
  if(!is.null(nf)) {
    T <- NT/nf
  } else {
    T <- NT
    nf <- 1
  }
  y <- drop(y)
  sglfit.object <- sglfit(x, y, lambda = lambda, gamma = gamma, gindex = gindex, method = method, nf = nf, ...)
  lambda <- sglfit.object$lambda
  # predict -> coef
  nz <- sapply(coef(sglfit.object, type = "nonzero"), length)
  if (missing(foldid)) {
    foldid <- rep(sort(rep(1:nfolds, times = ceiling(T/nfolds))[1:T]), times = nf)
  } else nfolds <- max(foldid)
  if (nfolds < 3) 
    stop("nfolds must be at least 3; nfolds=10 recommended")
  
  outlist <- vector("list", length = nfolds)
  for (i in seq(nfolds)) {
    whichfoldnot <- which(!foldid == i)
    y_sub <- y[whichfoldnot]
    outlist[[i]] <- sglfit(x = x[whichfoldnot, , drop = FALSE], 
                          y = y_sub, lambda = lambda, gamma = gamma, gindex = gindex, method = method, nf = nf, ...)
  }
  cvstuff <- cv.panel.sglpath(outlist, lambda = lambda, x = x, y = y, foldid = foldid, method = method, ...)
  cvm <- cvstuff$cvm
  cvsd <- cvstuff$cvsd
  cvname <- cvstuff$name
  lamin <- getmin(lambda, cvm, cvsd)
  idxmin <- which(lamin$lambda.min == lambda)
  idx1se <- which(lamin$lambda.1se == lambda)
  cv.sglfit <- list(lam.min = list(b0 = sglfit.object$b0[idxmin], beta = sglfit.object$beta[,idxmin]), 
                    lam.1se = list(b0 = sglfit.object$b0[idx1se], beta = sglfit.object$beta[,idx1se]))
  
  obj <- list(lambda = lambda, cvm = cvm, cvsd = cvsd, cvupper = cvm + 
              cvsd, cvlower = cvm - cvsd, nzero = nz, name = cvname, lamin = lamin, 
              panel.sgl.fit = sglfit.object, cv.panel.sglfit = cv.panel.sglfit)
  class(obj) <- "cv.panel.sglfit"
  obj
} 

#' Sorts cross-validation output for panel data regressions
#' 
#' @description 
#' Computes \code{cvm} and \code{cvsd} based on cross-validation fit. 
#' @usage 
#' cv.panel.sglpath(outlist, lambda, x, y, foldid, method, ...)
#' @param outlist list of cross-validation fits.
#' @param lambda a sequence of \eqn{\lambda} parameter.
#' @param x regressors
#' @param y response
#' @param foldid the fold assignment
#' @param method 'pooled' or 'fe'.
#' @param ... other arguments passed to \code{predict.sgl}
#' @return \code{cvm} and \code{cvsd}.
#' @export cv.sglpath
#' @keywords internal
cv.panel.sglpath <- function(outlist, lambda, x, y, foldid, method, ...) {
  typenames <- "Panel data sg-LASSO"
  y <- as.double(y)
  nfolds <- max(foldid)
  predmat <- matrix(NA, length(y), length(lambda))
  nlams <- double(nfolds)
  for (i in seq(nfolds)) {
    whichfold <- which(foldid == i)
    fitobj <- outlist[[i]]
    preds <- predict.sglpath(fitobj, x[whichfold, , drop = FALSE], method = method, ...)
    nlami <- length(outlist[[i]]$lambda)
    predmat[whichfold, seq(nlami)] <- preds
    nlams[i] <- nlami
  }
  cvraw <- y-predmat
  N <- length(y) - apply(is.na(predmat), 2, sum)
  cvm <- apply(cvraw, 2, mean, na.rm = TRUE)
  cvsd <- sqrt(apply(scale(cvraw, cvm, FALSE)^2, 2, mean, na.rm = TRUE)/(N - 1))
  list(cvm = cvm, cvsd = cvsd, name = typenames)
} 


