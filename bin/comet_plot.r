#!/usr/bin/Rscript
#####################################################################################
#
# Title  : Comet.r
# Author : CahaisV@iarc.fr, fernandezn@fellows.iarc.fr
# Date   : 31/03/2016
#
#####################################################################################


comet_plot<-function(){

  library(coMET)
  
  ################################################
  #1-read data
  
  if ( !file.exists(paste0(out,"/",model))) { dir.create(paste0(out,"/",model)) }
  if ( !file.exists(paste0(out,"/",model,"/dmps"))) { dir.create(paste0(out,"/",model,"/dmps")) }
  
  txdb<-getTxdb(genome)
  load(paste0(datadir, "/cpgIslands.", genome, ".rda"))
  
  group<-groups[1]
  
  ###########################################
  #Functions for comet_plot
  ###########################################
  
  ########################
  #Config files
  makeConfigFile<-function( ref.cpg, reg.start, reg.end, reg.chr, configfile){
  
  	configfile<-paste0(ref.cpg,"_conf.txt")
  	configfile <- file.path(getwd(), "data_config.txt")
  	config<-c(
  			disp.mydata=TRUE,
  			mydata.format="site",
  			sample.labels="CpG",
  			symbols="circle-fill",
  			lab.Y="log",
  			disp.color.ref=TRUE,
  			mydata.ref=ref.cpg,
  			pval.threshold=1e-05,
  			disp.association=FALSE,
  			disp.region=FALSE,
  			start=reg.start,
  			end=reg.end,
  			mydata.large.format="region_asso",
  			disp.association.large=TRUE,
  			disp.region.large=TRUE,
  			sample.labels.large="Gene expression",
  			color.list.large="green",
  			symbols.large="diamond-fill",
  			disp.phys.dist=TRUE,
  			disp.color.bar=TRUE,
  			disp.legend=TRUE,
  			list.tracks="",
  			disp.mult.lab.X=FALSE,
  			image.type="pdf",
  			image.title=paste(ref.cpg, "region"),
  			image.name=paste0(out, "/comet.jpg"),
  			image.size=7,
  			genome=genome,
  			dataset.geneE="hsapiens_gene_ensembl",
  			cormatrix.format="raw",
  			disp.cormatrixmap=TRUE,
  			cormatrix.method="spearman",
  			cormatrix.color.scheme="bluewhitered",
  			cormatrix.conf.level=0.05,
  			cormatrix.sig.level= 1,
  			cormatrix.adjust="none",
  			fontsize.gviz=12
  	)
  	write.table(config, file=configfile, row.names=T, quote=F,col.names=F, sep="=")
  	return(configfile)
  }
  
  
  ######################
  #select sites in the same range
  getSites<-function( info, betas, reg.start, reg.end, reg.chr ){
  
  	sites<- makeGRangesFromDataFrame(info, start.field="MAPINFO", end.field="MAPINFO", seqnames.field="CHR", keep.extra.columns=TRUE)
  	sites<- sites[seqnames(sites)==reg.chr,]
  	sites<- sites[start(sites) > reg.start, ]
  	sites<- sites[end(sites) < reg.end, ]
  	sites<- sites[sites$TargetID %in% rownames(betas),]
  	if (length(sites) < 2) { return(sites) }
  	sites$betas<-betas[match(sites$TargetID, rownames(betas)),]
  	sites<-sort(sites)
  	strand(sites)<-"*"
  	return(sites)
  }
  
  ######################
  #Info file
  makeInfofile<-function(info,sites){
  	infofile <- file.path(getwd(), "infofile.txt")
  	inf<-info[info$TargetID %in% sites$TargetID,]
  	if(is.numeric(inf$TargetID)) { inf$TargetID<-paste0("cgp",inf$TargetID) } # MYDATA names cannot start with numbers
  	rownames(inf)<-seq(1:nrow(inf))
  	write.table(inf, file="infofile.txt", sep="\t", row.names=F,quote=F)
  	return(infofile)
  }
  
  ########################
  #Build correlation matrix between selected dmps
  makeCorMatrix<-function(sites,betas){
  
  	cormatrix <- file.path(getwd(), "cormatrix.txt")
  	cor<-betas[sites$TargetID,]
  	cor<-cor[complete.cases(cor),]
  	if(is.numeric(rownames(cor)))  { rownames(cor)<-paste0("cgp",rownames(cor)) }
  	write.table(t(cor), file="cormatrix.txt", row.names=T, sep="\t",quote=F)
  	return(cormatrix)
  }
  
  ########################
  #get cpgi sites
  getCpgIslandsSites<-function(cpgIslands, reg.chr, reg.start, reg.end ){
  
  	cpgi<- cpgIslands[seqnames(cpgIslands)==reg.chr]
  	cpgi<- cpgi[start(cpgi) > reg.start, ]
  	cpgi<- cpgi[start(cpgi) < reg.end, ]
  	return(cpgi)	
  }
  
  ########################
  #comet plot
  cometCpg<-function(){
  
  	configfile<-makeConfigFile( ref.cpg, reg.start, reg.end, reg.chr, configfile )
  	sites<-getSites( info, betas, reg.start, reg.end, reg.chr )
  	if (length(sites) < 2){ print(paste0(ref.cpg," : not enough dmps in the region")); return(); }
  	infofile<-makeInfofile(info,sites)
  
  	cormatrix<-makeCorMatrix(sites,betas)
  	########################
  	#7- dataTrack
  	dTrack <- DataTrack(sites[,-c(1,2)], name = "meth(%)", groups = pdata[,group], data <- sites$betas, type = c("a", "confint"), from=reg.start, to=reg.end)
  	########################
  	#8- cpgIslands
  	cTrack<-NULL
  	cpgi<-getCpgIslandsSites(cpgIslands, reg.chr, reg.start, reg.end )
  	print(reg.chr)
  	if (length(cpgi) > 0 ){
  		cTrack<-DataTrack(cpgi@ranges, name = "CpG Islands", 
  				type = c("hist"), 
  				from = reg.start, 
  				to = reg.end,
  				chromosome=ChrNameToNumeric(reg.chr), 
  				genome="hg19",
  				trackType = "AnnotationTrack",
  				stacking="dense",
  				showId=TRUE,
  				fill = "#006400")
  	}
  	########################
  	#9- genetrack	
  	#genetrack <-genes_ENSEMBL("hg19",reg.chr,reg.start,reg.end,showId=TRUE)
  	geneTrack <- GeneRegionTrack(txdb, from=reg.start, to=reg.end, chromosome=reg.chr, genome=genome, showId=TRUE, geneSymbol=TRUE, showExonId=TRUE, name="genes ENSEMBL" )
  	
  	########################
  	#10- Comet Plot
  	gvizlist<-list(geneTrack, cTrack, dTrack)
  	if ( is.null(cTrack) ){
  		gvizlist<-list(geneTrack, dTrack)
  	}
  	tryCatch({
  			jpeg(paste0(out, "/", model, "/dmps/", ref.cpg, ".comet.jpg"), width=800, height=800)
  			comet(config.file=configfile, 
  					tracks.gviz=gvizlist, 
  					mydata.file=infofile, 
  					mydata.type="file", 
  					print.image=FALSE, 
  					sample.labels=as.vector(pdata[,group]), 
  					cormatrix.file=cormatrix, 
  					cormatrix.type="listfile")
  
  			dev.off()
  		},
  		error=function(cond) {
  			print("error")
  		},
  		warning=function(cond) {
  			print("warning")
  	})
  
  }
  
  
  ########################
  #2-MAIN
  ########################
  comets<-list()
  for (dmp in dmps){
  	if (dmp %in% toptable$cpg){
  	
  		ref.cpg = dmp
  		reg.start = toptable$start[toptable$cpg==ref.cpg] - (win/2)
  		reg.end = toptable$start[toptable$cpg==ref.cpg] + (win/2)
  		reg.chr = as.character(toptable$chr[toptable$cpg==ref.cpg])
  		#comets[ref.cpg]<-cometCpg()
  		cometCpg()
  	}
  }
  print(paste0("win=",win))
  #print(toptable$cpg)
  if (max > length(toptable$cpg) ) { max=length(toptable$cpg) }
  for (i in 1:max){
  	
  	ref.cpg = toptable$cpg[i]
  	reg.start = toptable$start[toptable$cpg==ref.cpg] - (win/2)
  	reg.end = toptable$start[toptable$cpg==ref.cpg] + (win/2)
  	reg.chr = as.character(toptable$chr[toptable$cpg==ref.cpg])
  	#comets[ref.cpg]<-cometCpg()
  	print(paste0(ref.cpg,":",reg.chr,":",reg.start,":",reg.end))
  	cometCpg()
  }
  
  #comets<-paste(comets, collapse="\n")
  
  ########################
  #3-Create html report
  print("Create report")
  library(rmarkdown)
  formula1<-paste(colnames(design)[-1], collapse=" + ")
  render(paste0(path,"/comet.Rmd"), params = list(project=out, model=model, formula=formula1) )
  
  
}


