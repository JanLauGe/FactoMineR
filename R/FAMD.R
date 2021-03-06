	FAMD <- function(base, ncp = 5, graph = TRUE,sup.var=NULL, ind.sup = NULL, axes=c(1,2),row.w=NULL,tab.comp=NULL){
	
    moy.ptab <- function(V, poids) {
        as.vector(crossprod(poids/sum(poids),as.matrix(V)))
    }
	
    ec.tab <- function(V, poids) {
        ecart.type <- sqrt(as.vector(crossprod(poids/sum(poids),as.matrix(V^2))))
		ecart.type[ecart.type <= 1e-16] <- 1
        return(ecart.type)
    }

	fct.eta2 <- function(vec,x,weights) {   ## pb avec les poids
      VB <- function(xx) {
	    return(sum((colSums((tt*xx)*weights)^2)/ni))
      }
      tt <- tab.disjonctif(vec)
      ni <- colSums(tt*weights)
      unlist(lapply(as.data.frame(x),VB))/colSums(x^2*weights)
    }

    if (is.null(rownames(base))) rownames(base) = 1:nrow(base)
    if (is.null(colnames(base))) colnames(base) = paste("V",1:ncol(base),sep="")
	base <- as.data.frame(base)
	base <- droplevels(base)
	row.w.init <- row.w
	if (is.null(row.w)) { row.w.init <- row.w <- rep(1,nrow(base)-length(ind.sup)) }
	row.w <- rep(0,nrow(base))
	row.w[which(!((1:nrow(base))%in%ind.sup))] <- row.w.init
	
	numAct <- which(sapply(base,is.numeric))
	if (is.null(numAct)) stop("All your variables are quantitative: you should use PCA")
	facAct <- which(!sapply(base,is.numeric))
    if (is.null(facAct)) stop("All your variables are qualitative: you should use MCA")

	facIllu <- numIllu <- tabFacIllu <- tabNumIllu <- NULL
	if (!is.null(sup.var)){
      act.var <- (1:ncol(base))[-sup.var]
	  numIllu <- intersect(sup.var,numAct)
	  if (length(numIllu)==0) numIllu <- NULL
	  else numAct <- intersect(act.var,numAct)
	  facIllu <- intersect(sup.var,facAct)
	  if (length(facIllu)==0) facIllu <- NULL
	  else facAct <- intersect(act.var,facAct)
	}

	if (!is.null(tab.comp)) {
	  aa <- c(0,cumsum(sapply(base,nlevels)+1-(sapply(base,nlevels)>0)))
	  ll <- list()
	  for  (i in 1:(length(aa)-1)) ll[[i]] <- (aa[i]+1):aa[i+1]
	  QuantiAct <- tab.comp[,unlist(ll[which(sapply(ll,length)==1)])]
	} else 	QuantiAct <- as.matrix(base[,numAct,drop=FALSE])
	centre <- moy.ptab(QuantiAct,row.w)
	QuantiAct <- t(t(QuantiAct)-centre)
	ecart.type <- ec.tab(QuantiAct,row.w)
	QuantiAct <- t(t(QuantiAct)/ecart.type)
	
	if (!is.null(tab.comp)) {
	  QualiAct <- tab.comp[,unlist(ll[which(sapply(ll,length)!=1)])]
	} else QualiAct <- tab.disjonctif(base[,facAct,drop=FALSE])
    prop <- colSums(QualiAct*(row.w/sum(row.w)))
	QualiAct <- t(t(QualiAct)- moy.ptab(QualiAct,row.w))
	QualiAct <- t(t(QualiAct)/sqrt(prop))

	X <- cbind(QuantiAct,QualiAct)

	if (!is.null(numIllu)){
	  QuantiIllu <- as.matrix(base[,numIllu,drop=FALSE])
	  QuantiIllu <- t(t(QuantiIllu)-moy.ptab(QuantiIllu,row.w))
	  QuantiIllu <- t(t(QuantiIllu)/ec.tab(QuantiIllu,row.w))
	  tabNumIllu <- (ncol(X)+1):(ncol(X)+ncol(QuantiIllu))
	  X <- cbind(X,QuantiIllu)
	}
	if (!is.null(facIllu)){
	  tabFacIllu <- (ncol(X)+1):(ncol(X)+length(facIllu))
	  X <- cbind.data.frame(X,base[,facIllu,drop=FALSE])
    }
    
	ncp <- min(ncp,nrow(base)-1,ncol(QuantiAct)+ncol(QualiAct)-length(facAct))
	pca <- PCA(X,graph=FALSE,ind.sup=ind.sup,quanti.sup=tabNumIllu,quali.sup=tabFacIllu,scale.unit=FALSE,row.w=row.w.init,ncp=ncp)
	eig <- pca$eig[1:ncp,,drop=FALSE]
    ind.quali <- which(!(rownames(pca$var$coord)%in%colnames(base)[numAct]))
    quanti.var <- list(coord=pca$var$coord[colnames(base)[numAct],,drop=FALSE],cos2=pca$var$cos2[colnames(base)[numAct],,drop=FALSE],contrib=pca$var$contrib[colnames(base)[numAct],,drop=FALSE])
 
	tt <- function(v,mat,poids) {
	  res <- matrix(NA,nrow=0,ncol=ncol(mat))
	  for (i in 1:nlevels(v)) {
	    res <- rbind(res,crossprod(poids[v==levels(v)[i]]/sum(poids[v==levels(v)[i]]),as.matrix(mat[v==levels(v)[i],,drop=FALSE])))
      }
	  return(res)
    }
	  
	aux1 <- lapply(base[,facAct,drop=FALSE],tt,X[,1:(ncol(X)-length(tabNumIllu)-length(tabFacIllu)),drop=FALSE],poids=row.w.init)
    bary <- NULL
	for (i in 1:length(aux1)) bary=rbind(bary,aux1[[i]])
	rownames(bary) <- unlist(sapply(base[,facAct,drop=FALSE],levels))
	dist2 <- rowSums(bary^2)
	
    coord.quali.var <- t(t(pca$var$coord[ind.quali,,drop=FALSE]/sqrt(prop))*sqrt(eig[1:ncp,1]))
    quali.var <- list(coord=coord.quali.var,cos2=coord.quali.var^2/dist2,contrib=pca$var$contrib[ind.quali,,drop=FALSE])

	vtest <- pca$var$coord[ind.quali,,drop=FALSE]
	if (sum(row.w.init)>1) nombre <-  prop*sum(row.w.init)
	else nombre <-  prop*(nrow(base)-length(ind.sup))   ## nombre = n
	
	if (sum(row.w.init)>1) {
	  nombre <- (sum(row.w.init) - nombre)
	  nombre <- nombre/(sum(row.w.init) - 1)/(sum(row.w.init))
	} else {
	  nombre <- (nrow(base)-length(ind.sup))- nombre
      nombre <- nombre / (nrow(base)-length(ind.sup)-1)/(nrow(base)-length(ind.sup))  ## nombre = (N-n)/(N-1)
	}
    vtest <- vtest/sqrt(nombre)
    quali.var$v.test <- vtest

	res.var <- list()	
    eta2 <- matrix(NA, length(facAct), ncp)
    colnames(eta2) <- paste("Dim", 1:ncp)
    rownames(eta2) <- attributes(base)$names[facAct]
	if (ncp>1) eta2 <- t(sapply(as.data.frame(base[rownames(pca$ind$coord), facAct,drop=FALSE]),fct.eta2,pca$ind$coord,weights=row.w.init/sum(row.w.init)))
	else {
	   eta2 <- as.matrix(sapply(as.data.frame(base[rownames(pca$ind$coord), facAct,drop=FALSE]),fct.eta2,pca$ind$coord,weights=row.w.init/sum(row.w.init)),ncol=ncp)
	}
	res.var$coord <- rbind(quanti.var$coord^2,eta2)
	aux <- aggregate(quali.var$contrib,by=list(as.factor(rep.int(1:length(facAct),times=sapply(base[,facAct,drop=FALSE],nlevels)))),FUN=sum)[,-1,drop=FALSE]
	colnames(aux) <- colnames(quanti.var$contrib)
    rownames(aux) <- attributes(base)$names[facAct]
	res.var$contrib <- rbind(quanti.var$contrib,aux)
	res.var$cos2 <- rbind(quanti.var$cos2^2,eta2^2/(sapply(base[,facAct,drop=FALSE],nlevels)-1))
	if (!is.null(pca$quanti.sup)&!is.null(pca$quali.sup)) {
	  res.var$coord.sup <- rbind(pca$quanti.sup$coord^2,pca$quali.sup$eta2)
	  res.var$cos2.sup <- rbind(pca$quanti.sup$cos2^2,pca$quali.sup$eta2^2/(sapply(base[,facIllu,drop=FALSE],nlevels)-1))
	}
	if (!is.null(pca$quanti.sup)&is.null(pca$quali.sup)) {
	  res.var$coord.sup <- pca$quanti.sup$coord^2
	  res.var$cos2.sup <- pca$quanti.sup$cos2^2
	}
	if (is.null(pca$quanti.sup)&!is.null(pca$quali.sup)) {
	  res.var$coord.sup <- pca$quali.sup$eta2
	  res.var$cos2.sup <- pca$quali.sup$eta2^2/(sapply(base[,facIllu,drop=FALSE],nlevels)-1)
	}
    res <- list(eig=eig,ind=pca$ind)
	if (!is.null(pca$ind.sup)) res$ind.sup <- pca$ind.sup
    res$var <- res.var
	res$quali.var <- quali.var
	res$quanti.var <- quanti.var
	if (!is.null(pca$quali.sup)) res$quali.sup <- pca$quali.sup
    if (!is.null(pca$quanti.sup)) res$quanti.sup <- pca$quanti.sup
	res$svd <- pca$svd
    res$call <- pca$call
	res$call$X <- base
	res$call$centre <- c(centre,prop)
	res$call$ecart.type <- c(ecart.type,rep(0,length(prop)))
	res$call$quali.sup$quali.sup <- base[,c(facAct,facIllu),drop=FALSE]
	res$call$type <- rep("s",ncol(base))
	res$call$type[c(facAct,facIllu)] <- "n"
	res$call$nature.var <- rep("quanti",ncol(base))
	res$call$nature.var[facAct] <- "quali"
	if (!is.null(facIllu)) res$call$nature.var[facIllu] <- "quali.sup"
	if (!is.null(numIllu)) res$call$nature.var[numIllu] <- "quanti.sup"
	res$call$call <- match.call()
	res$call$prop <- prop
#	res$call$call <- sys.calls()[[1]]
    class(res) <- c("FAMD", "list")
	 if (graph & (ncp>1)){
       plot.FAMD(res,choix="ind", axes=axes,habillage="none")
       plot.FAMD(res,choix="ind", invisible=c("quali","quali.sup"),axes=axes,habillage="none",new.plot=TRUE)
       plot.FAMD(res,choix="var",axes=axes,new.plot=TRUE)
       plot.FAMD(res,choix="quali", axes=axes,habillage="none",new.plot=TRUE)
       plot.FAMD(res,choix="quanti",axes=axes,new.plot=TRUE)
     }
	return(res)
}
