# 
#-------------------------------------------------------------------------
# This script is designed to do plots based on output from 
# kmer_entropy.py - for example if you ran 
# kmer_entropy.py -t zipfian -k 6 -p 10 -o zipfian.txt -b ~/analysis_dir  -s .1  /dataset/some_dataset/archive/processed_trimmed/*.fastq.gz
# then your input file would be zipfian.txt
# 
# The general idea is a "10,000 ft view" of sequence data, based on k-mer frequencies
#-------------------------------------------------------------------------
library(Heatplus)
library(RColorBrewer)
library(gplots)


###################################################################################
# edit these variables - the values given are just examples                       #
###################################################################################
#data_folder="M:/Documents/projects/tangential/tgdata/kmers_gbs"     
#output_folder="M:/Documents/projects/tangential/tgdata/kmers_gbs" 
input_file="kmer_summary.txt"                                                         

#....thats all you need to cxhange to start with. More options : 


# you can use this regexp to do a custom trim of the 
# column names that will appear in the plots. Set to NULL 
# to accept the default trim (will remove.kmerdist, .fastq and .gz)
# example : colname_pattern="ELN02.\\d+_S\\d+"      
# would pick out ELN02.123_01 etc 
colname_pattern=NULL      

heatmap_image_file="kmer_entropy.jpg"                                             
number_of_heatmap_row_labels=100  

# next is the number of labels that will appear in the 
# heatmap, and in the dimensional scaling plot                                                
number_of_column_labels=40

zipfian_plots_per_row=4                                                           
zipfian_plot_image_file="kmer_zipfian.jpg"                                        

# next is a list of column name patterns which is used to select the 
# columns displayed in the "comparison plot" which includes
# multiple samples. In addition , all columns in this list will 
# be labelled in the dimensional scaling plot. 
# if set to NULL, all samples will be included in the "comparison plot"
# (and no additional samples will be labelled in the dimensional
# scaling plot)
# examples: 
#zipfian_plot_comparisons=c("1128_S28")
#zipfian_plot_comparisons=c("19_8Kb_1","reads19_1.*")                     
#zipfian_plot_comparisons=c("X3.*", "X4.*", "X5.*")                                
#zipfian_plot_comparisons=c("GA194_B53_C9CHFANXX_7_2554_X4.cnt","GA194_B40_C9CHFANXX_7_2554_X4.cnt")                                
#zipfian_plot_comparisons=c("SQ2530","SQ2531","SQ2533","SQ2534","SQ2535","SQ2536","SQ2537","SQ2538","SQ2539","SQ2540","SQ2541","SQ2515","SQ2516","SQ2517","SQ2518")
zipfian_plot_comparisons=NULL



comparison_plot_image_file="kmer_zipfian_comparisons.jpg"                         
distances_plot_image_file="zipfian_distances.jpg"                                 
################## End of options. Remaining just code ################################


get_command_args <- function() {
   args=(commandArgs(TRUE))
   if(length(args)!=1 ){
      #quit with error message if wrong number of args supplied
      print('Usage example : Rscript --vanilla  kmer_plots_gbs.r datafolder=/dataset/hiseq/scratch/postprocessing/160623_D00390_0257_AC9B0MANXX.gbs/SQ2559.processed_sample/uneak/kmer_analysis')
      print('args received were : ')
      for (e in args) {
         print(e)
      }
      q()
   }else{
      print("Using...")
      # seperate and parse command-line args
      for (e in args) {
         print(e)
         ta <- strsplit(e,"=",fixed=TRUE)
         switch(ta[[1]][1],
            "datafolder" = datafolder <- ta[[1]][2]
         )
      }
   }
   return(datafolder)
}


custom_parser <- function(field_name) {
   # this will parse a fieldname using a regular expression 
   # "colname_parser" defined in the workspace. (It is not 
   # a closure as the function does not need to re-defined 
   # after changing the value of colname_parser)
   result=field_name
   match<-regexpr(colname_pattern,field_name)
   if (match != -1) {
      result = substr(field_name,match,match+attr(match,"match.length")-1)
   }
   return(result)
}

get_data<-function(data_folder, input_file_name, colname_pattern) {
   #
   #this function reads a structured text file (generated by kmer_entropy.py) which contains 
   #three sections. The structured text file looks like this : 
   #-------------------------------------------------------
   #*** ranks *** :
   #kmer_pattern	14_8Kb_1.fastq.kmerdist	...
   #AAAAAA	35	...
   #AAAAAC	109	...  
   #.
   #.
   #TTTTTT	750	...
   #*** entropies *** :
   #kmer_pattern	14_8Kb_1.fastq.kmerdist	...
   #AAAAAA	9.15653805702	...
   #AAAAAC	10.1764807643	...
   #.
   #.
   #*** distances *** :
   #	14_8Kb_1.fastq.kmerdist	... 
   #14_8Kb_1.fastq.kmerdist	0	...
   #.
   #.
   # -----------------------------------------------------
   #The file is parsed and each section is read into a data frame. The three 
   #data frames are bundled into a single list which is returned as the 
   #value of the function. 
   #
   #Example usage: 
   #
   #mydata <- get_data(data_folder, input_file)
   #
   #


   # read the data into a big character vector
   setwd(data_folder)
   Lines <- readLines(input_file_name)

   # parse the data - see example format above. Parse out 
   # a table of ranks, entropies and distances between 
   # samples using a "zipfian" metric

   selected_lines = as.vector(character())
   for(line in Lines) {
      if(substr(line, 0, 13) == "*** ranks ***") {
         selected_lines = as.vector(character())
         next
      }
      if(substr(line, 0, 17) == "*** entropies ***") {
         rank_lines = selected_lines
         selected_lines = as.vector(character())
         next
      }
      if(substr(line, 0, 17) == "*** distances ***") {
         entropy_lines = selected_lines
         selected_lines = as.vector(character())
         next
      }
      selected_lines=c(selected_lines, line)
      distance_lines=selected_lines
   }
   results = list()
   results$rank_data = read.table(textConnection(rank_lines), header=TRUE, row.names=1, sep="\t")
   results$entropy_data = read.table(textConnection(entropy_lines), header=TRUE, row.names=1, sep="\t")
   distance_data<-read.table(textConnection(distance_lines), header=TRUE, row.names=1, sep="\t")

   # auto-tidy the variable names slightly (remove .kmerdist suffix , and .fastq and .gz ) 
   for(pattern in c(".kmerdist", ".fastq", ".gz")) {
      colnames(results$rank_data) <- sub(pattern,"",colnames(results$rank_data))
      colnames(results$entropy_data) <- sub(pattern,"",colnames(results$entropy_data))
      colnames(distance_data) <- sub(pattern,"",colnames(distance_data))
      rownames(distance_data) <- sub(pattern,"",rownames(distance_data))
   }

   # custom-tidy the variable names if requested
   if( ! is.null(colname_pattern)) {   
      colnames(results$rank_data) <- sapply( colnames(results$rank_data), custom_parser)
      colnames(results$entropy_data) <- sapply( colnames(results$entropy_data), custom_parser)
      colnames(distance_data) <- sapply( colnames(distance_data), custom_parser)
      rownames(distance_data) <- sapply( rownames(distance_data), custom_parser)
   }

   # order each data frame by column name so things are easier to find in plots
   results$rank_data <- results$rank_data[,order(colnames(results$rank_data))]
   results$entropy_data <- results$entropy_data[,order(colnames(results$entropy_data))]

   # distances are distances
   results$distance_data <- as.dist(distance_data)

   # supply log-rank 
   results$log_rank_data = log(results$rank_data,2)

  
   return(results)
}

draw_entropy_heatmap <- function(datamatrix, output_folder, heatmap_image_file, number_of_heatmap_row_labels, number_of_column_labels) {
   # draws a heatmap based on the 
   # self-information of the kmers in the data
   # (i.e. rare kmer = large self information, abundant kmer = low self information)
   setwd(output_folder)
   row_label_interval=max(1, floor(nrow(datamatrix)/number_of_heatmap_row_labels))  # 1=label every location 2=label every 2nd location  etc 
   col_label_interval=max(1, floor(ncol(datamatrix)/number_of_column_labels))  # 1=label every location 2=label every 2nd location  etc 

   #cm<-brewer.pal(9,"BuPu") # sequential
   cm <-c("#F7FCFD", "#E0ECF4", "#BFD3E6", "#9EBCDA", "#8C96C6", "#8C6BB1", "#88419D", "#810F7C", "#4D004B")
   cm <- rev(cm)

   # set up a vector which will index the labels that are to be blanked out so that 
   # only every nth row is labelled, 
   # the rest empty strings, n=row_label_interval.
   rowLabels <- rownames(as.matrix(datamatrix))
   rowBlankSelector <- sequence(length(rowLabels))
   rowBlankSelector <- subset(rowBlankSelector, rowBlankSelector %% row_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)

   # set up a vector which will index the labels that are to be blanked out so that 
   # only every nth col is labelled, 
   # the rest empty strings, n=col_label_interval.
   colLabels <- colnames(as.matrix(datamatrix))
   colBlankSelector <- sequence(length(colLabels))
   colBlankSelector <- subset(colBlankSelector, colBlankSelector %% col_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)

   jpeg(filename = heatmap_image_file, width=1300, height=1200) # with dendrograms

   # run the heatmap, just to obtain the clustering index - not the final plot
   hm_internal<-heatmap.2(as.matrix(datamatrix),  scale = "none", dendrogram = "col",
    Colv = TRUE,  
     trace = "none", breaks = 0 + 15/9*seq(0,9),
     col = cm , key=FALSE, density.info="none", 
     keysize=1.0, margin=c(11,20), cexRow=1.5, cexCol=1.5, 
     lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.7, 1.7, .6 ), lhei=c(.5, 3) , labRow = rowLabels)

   dev.off()

   # edit the re-ordered vector of row labels, obtained from the heatmap object, so that only 
   # every nth label on the final plot has a non-empty string
   # this is for the internal distance matrix
   indexSelector <- hm_internal$rowInd[length(hm_internal$rowInd):1]    
   indexSelector <- indexSelector[rowBlankSelector]
   rowLabels[indexSelector] = rep('',length(indexSelector))


   # edit the re-ordered vector of col labels, obtained from the heatmap object, so that only 
   # every nth label on the final plot has a non-empty string
   # this is for the internal distance matrix
   indexSelector <- hm_internal$colInd[length(hm_internal$colInd):1]    
   indexSelector <- indexSelector[colBlankSelector]
   colLabels[indexSelector] = rep('',length(indexSelector))


   # now do the final plot
   jpeg(filename = heatmap_image_file, width=1300, height=1600) # with dendrograms
   hm<-heatmap.2(as.matrix(datamatrix),  scale = "none", dendrogram = "col",
       Colv = TRUE,  
       trace = "none", breaks = min(datamatrix) + (max(datamatrix)-min(datamatrix))/9*seq(0,9), 
       col = cm , key=FALSE, density.info="none", 
       keysize=1.0, margin=c(80,60), cexRow=1.3, cexCol=1.3, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .8, 0 ), lhei=c(.5, 3) , labRow = rowLabels, labCol=colLabels)
   dev.off()

   write.table(colnames(datamatrix)[hm$colInd[1:length(hm$colInd)]] , file="samplenames_ordered_as_heatmap.txt",row.names=TRUE,sep="\t") 
   write.table(rownames(datamatrix)[hm$rowInd[length(hm$rowInd):1]] , file="6mers_ordered_as_heatmap.txt",row.names=TRUE,sep="\t") 

   orderedmat=datamatrix[hm$rowInd[length(hm$rowInd):1],]
   orderedmat=orderedmat[,hm$colInd[1:length(hm$colInd)]]  # NB, the column labels come out reversed !
   write.table(orderedmat,file="data_ordered_as_heatmap.txt",row.names=TRUE,sep="\t")

   clust = as.hclust(hm$colDendrogram)
   sink("heatmap_sample_clustering_support.txt")
   print("clust$merge:")
   print(clust$merge)
   print("clust$height:")
   print(clust$height)
   print("clust$order")
   print(clust$order)
   print("clust$labels")
   print(clust$labels)
   sink()
   write.table(cutree(clust, 1:dim(datamatrix)[2]),file="heatmap_sample_clusters.txt",row.names=TRUE,sep="\t")  # ref https://stackoverflow.com/questions/18354501/how-to-get-member-of-clusters-from-rs-hclust-heatmap-2
}


draw_zipfian_plots <- function(datalist, output_folder, zipfian_plot_image_file, zipfian_plots_per_row) {
   # draws "zipfian" plots for each sample (one plot per sample)
   # these are plots of entropy ~ log( kmer self-information rank)  
   # (- i.e. very similar to "zipf law" plot of log(freq) ~ log (freq rank), but with different 
   # slope and intercept)
   plot_rows = ceiling(ncol(datalist$log_rank_data)/zipfian_plots_per_row)
   if ( plot_rows > 500 ) {
      print(paste("skipping individual zipf plots as too many points for this function (",plot_rows,")"))
      return()
   }
   plot_width=1300
   plot_height = 300 * plot_rows
   jpeg(filename = zipfian_plot_image_file, plot_width, plot_height)
   par(mfrow=c(plot_rows, zipfian_plots_per_row))
   for (i in sequence(ncol(datalist$log_rank_data))) {
      plot(datalist$log_rank_data[,i], datalist$entropy_data[,i],pch='.',main=colnames(datalist$log_rank_data)[i],xlim=c(0,12), ylim=c(6,14))
   }
   dev.off()
}


draw_comparison_plot <- function(datalist, output_folder, comparison_plot_image_file, comparison_columns_patterns) {
   # all / select samples in a single "zipfian" plot
   comparison_columns = as.vector(integer())
   if ( ! is.null(comparison_columns_patterns)) { 
      for (comparison_pattern in comparison_columns_patterns){
         comparison_columns = c(comparison_columns, grep(comparison_pattern,colnames(datalist$entropy_data), ignore.case = TRUE) )
      }
   }
   else {
      comparison_columns = sequence(ncol(datalist$entropy_data))
   }

   if (length(comparison_columns) == 0) {
      comparison_columns = sequence(ncol(datalist$entropy_data))
   }

   log_rank_subset=datalist$log_rank_data[,comparison_columns[1]]
   entropy_subset=datalist$entropy_data[,comparison_columns[1]]

   if (length(comparison_columns) > 1) {
      for(column_number in comparison_columns[2:length(comparison_columns)]) {
         entropy_subset=cbind(entropy_subset, datalist$entropy_data[,column_number])
         log_rank_subset = cbind(log_rank_subset, datalist$log_rank_data[,column_number])
      }
   }

   jpeg(filename = comparison_plot_image_file, 800,800)
   if (length(comparison_columns) < 30 ) {
      plot(log_rank_subset, entropy_subset, pch='.', xlim=c(0,12), ylim=c(6,14))

      xmin <- par("usr")[1]
      xmax <- par("usr")[2]
      ymin <- par("usr")[3]
      ymax <- par("usr")[4]
      delta_y=(ymax-ymin)/40.0
      delta_x=(xmax-xmin)/5

      for(column_number in sequence(length(comparison_columns))) {
         text( xmin + delta_x , ymax - delta_y * (1+column_number), colnames(datalist$entropy_data)[comparison_columns[column_number]], adj = c( 0, 1 ))
      }
   }
   else {
      plot(log_rank_subset, entropy_subset, pch='.', xlim=c(0,12), ylim=c(6,14))
      title(main=paste( colnames(datalist$entropy_data)[1] , "....etc"))
   }
   dev.off()
}


draw_distances_plot <- function(datalist, output_folder, distances_plot_image_file, comparison_columns_patterns,  number_of_column_labels) {
   # the distance matrix (i.e. distances between each pair of zipfian plots)
   # is embedded in 2-D using mds and plotted. 
   # - look for groups and outliers
   fit <- cmdscale(datalist$distance_data,eig=TRUE, k=2)
   jpeg(filename = distances_plot_image_file, 800,800)
   smoothScatter(fit$points, cex=0.7)

   # now work out which ones to label - its a union of all of the "comparison_columns", and 
   # every "n'th" column , as determined by (number of columns / number_of_column_labels)
   comparison_columns = as.vector(integer())
   if (! is.null(comparison_columns_patterns)) {
      for (comparison_pattern in comparison_columns_patterns){
         comparison_columns = c(comparison_columns, grep(comparison_pattern,colnames(datalist$entropy_data), ignore.case = TRUE) )
      }
   }

   col_label_interval=max(1, floor(ncol(datalist$entropy_data)/number_of_column_labels))  # 1=label every location 2=label every 2nd location  etc 
   
   #col_label_selector <- sequence(ncol(datalist$entropy_data))
   #col_label_selector <- subset(col_label_selector, col_label_selector %% col_label_interval == 0)

   #col_labels=rep(NULL, ncol(datalist$entropy_data))
   #col_labels[comparison_columns] = colnames(datalist$entropy_data)[comparison_columns]


   # this code needs more testing - changed after noticed a labelling bug in a fork of this 
   col_labels <- as.vector(rownames(fit$points))
   blank_index <- sequence(length(col_labels))
   blank_index <- subset(blank_index, ! blank_index %in% comparison_columns)
   col_labels[blank_index] <- ''

   col_label_eraser <- sequence(length(col_labels))
   col_label_eraser <- subset(col_label_eraser, ! col_label_eraser %% col_label_interval == 0)
   col_labels[col_label_eraser] = ''

   #col_labels[col_label_selector] = colnames(datalist$entropy_data)[col_label_selector]

   text(fit$points, labels = col_labels, pos = 4, cex=0.8)
   write.table(fit$points, "zipfian_distances_fit.txt", sep="\t")
   dev.off()
}

draw_missing_plot <- function(plot_image_file, width, height, message) {
   # https://stackoverflow.com/questions/19918985/r-plot-only-text
   jpeg(filename = plot_image_file, width,height)
   par(mar = c(0,0,0,0))
   plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
   text(x = 0.5, y = 0.5, paste(message), cex = 1.6, col = "black")
   par(mar = c(5, 4, 4, 2) + 0.1)
   dev.off()
}

my_ncol <- function(arg) {
   n = ncol(arg)
   if (is.null(n)) {
      n = 0
   } 
   return(n) 
}

main <- function() {
   data_folder <- get_command_args()
   output_folder <- data_folder
   mydata <- get_data(data_folder, input_file, colname_pattern)

   if ( my_ncol(mydata$entropy_data) > 1) {
      draw_comparison_plot(mydata, output_folder, comparison_plot_image_file, zipfian_plot_comparisons)
   }
   else {
      draw_missing_plot(comparison_plot_image_file, 800,200, "insufficient data")
   }

   if ( my_ncol(mydata$entropy_data) >= 3) {
      draw_distances_plot(mydata, output_folder, distances_plot_image_file, zipfian_plot_comparisons, number_of_column_labels)
   }
   else {
      draw_missing_plot(distances_plot_image_file, 800,200, "insufficient data")
   }

   if ( my_ncol(mydata$entropy_data) > 1) {
      draw_entropy_heatmap(mydata$entropy_data, output_folder, heatmap_image_file, number_of_heatmap_row_labels, number_of_column_labels)
   }
   else {
      draw_missing_plot(heatmap_image_file, 800,200, "insufficient data")
   }

   if ( my_ncol(mydata$entropy_data) > 1) {
      draw_zipfian_plots(mydata, output_folder, zipfian_plot_image_file, zipfian_plots_per_row) 
   }
   else {
      draw_missing_plot(zipfian_plot_image_file, 800,200, "insufficient data")
   }

   return(mydata)
}


mydata<-main()






