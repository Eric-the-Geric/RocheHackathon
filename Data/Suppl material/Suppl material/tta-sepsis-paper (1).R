library(data.table)
library(ggplot2)
library(geepack)

# R functions to create figures for the time to antibiotic analysis (Schmatz et al 2019)

# EXAMPLE USAGE
# nicu.dt <- read.tta('./')
# plot.tta.boxplot(nicu.dt)
# plot.mortality.prediction(nicu.dt)

# read de-identified TTA dataset from the specified path
# returns a data.table object with the dataset
read.tta <- function(path="./") {
  as.data.table(read.csv(sprintf("%s/deid-nicu-sepsis-tta.csv", path))) -> nicu
  
  # label "sepsis ever" vs. "sepsis never" cohort of children (patient level variable)
  nicu[,sepsis_ever:=0]
  nicu[unique_patient_id %in% nicu[blood_culture_positive==1,unique_patient_id], sepsis_ever:=1]
  
  # create transformed versions of TTA variable
  # log transformation as used to normalize distribution of errors in linear regression analyses where time to antibiotics is the outcome of interest
  nicu[, log_tta := log(time_to_antibiotics)]
  
  # convert time to antibiotics to 30 minute increments (as reported in the TTA manuscript by Schmatz et al 2019)
  nicu[, tta30 := time_to_antibiotics/30]
  
  # return the dataset
  nicu
}

# function to create boxplot of time to antibiotic administration by year
# stores as a PNG file in the working directory
plot.tta.boxplot <- function(nicu, tta_max=300) {
  png(file="boxplot-tta-by-year.png", width=4, height=5, units='in', res=1200)
  boxplot(time_to_antibiotics ~ period, boxwex=0.5, col='grey', yaxp=c(0,tta_max,10), ylim=c(0,tta_max), ylab='Minutes to antibiotic administration', data = nicu[time_to_antibiotics<tta_max])
  dev.off()
}

# function to plot predicted mortality, right censored at the specified "tmax" argument (in minutes)
# creates PNG files for the 7, 14, and 30 day models

# For purposes of illustration, these figures also show the raw mortality events as small points 
# along the bottom and top of the figure

# Note that portions of the code to calculate confidence intervals were adapted from
# https://stackoverflow.com/questions/14423325/confidence-intervals-for-predictions-from-logistic-regression
plot.mortality.prediction <- function(nicu, tmax=240) {
  # inner function to  perform the plotting based on a GEE model (mod) that has already been fit
  plot.it <- function(y.axis.title, mortality, filename) {
    # calculate confidence intervals for prediction
    critval <- qnorm(0.975) ## upper limit for 95% CI
    
    # apply inverse link function from the model to get the 95% confidence intervals
    l <- mod$family$linkinv
    preddata[, lwr :=  l(fit - (critval * se.fit))]
    preddata[, upr :=  l(fit + (critval * se.fit))]
    preddata[, fit :=  l(fit)]
    
    # calculate raw (unadjusted) percent mortality in 60-minute intervals as one might report in a bar plot figure
    # TTA that exceeds the maximum is grouped in the highest bucket
    nicu.barplot60 <- nicu[,.(blood_culture_positive,time_to_antibiotics=pmin(time_to_antibiotics,tmax-1),mortality)][
      blood_culture_positive==1,.(mortality.proportion=sum(mortality)/.N, mortality=sum(mortality), .N), keyby=.(time_to_antibiotics=30+60*floor(time_to_antibiotics/60))]
    # obtain confidence intervals around the proportion (not used in these plots)
    nicu.barplot60 <- suppressWarnings(nicu.barplot60[, as.list(prop.test(mortality,N)$conf.int),keyby=time_to_antibiotics][,.(mortality.proportion.min=V1, mortality.proportion.max=V2),keyby=time_to_antibiotics][nicu.barplot60])
    # hour number (e.g. 1, 2, 3, 4...)
    nicu.barplot60[, hour := ceiling(time_to_antibiotics/60)]
    # indicate with a "+" sign in the label that that maximum hour "bucket" contains data from later time periods
    nicu.barplot60[, hour.label := sprintf("hour %s", ifelse(hour==max(hour), sprintf("%d+", hour), as.character(hour)))]
    
    # legend segment positions
    nicu.legend = data.table(x=c(20,30,40), y=0.7)
    
    # data points for observed mortality (fit=0 indicates survival, =1 indicates death)
    # position in buckets of 3 minute intervals
    nicu.points <- nicu[,.(blood_culture_positive,time_to_antibiotics,mortality)][
      blood_culture_positive==1&time_to_antibiotics<tmax, .(time_to_antibiotics=3*floor(time_to_antibiotics/3),fit=mortality)]
    nicu.points[, count := as.double((1:.N)-1-(.N-1)/2), by=.(fit, time_to_antibiotics)]
    # adjust data points vertically to ensure points do not overlap
    nicu.points[, fit := fit + count/50]
    
    # actually do the plot -- store as PNG file at 1200 dpi
    png(file=filename, width=6, height=6, units='in', res=1200)
    print(
      ggplot() +
        # plot actual observed mortality events
        geom_point(data=nicu.points, mapping=aes(x=time_to_antibiotics,y=fit)) +

        # dashed horizontal grey lines at increments of 0.2 on the probability scale
        geom_hline(yintercept = seq(0, 1, 0.2), linetype='dashed', color='grey70') + 
        
        # shade the confidence interval
        geom_ribbon(data=preddata, mapping=aes(x=tta30*30, ymin=lwr, ymax=upr), alpha=0.6, fill='grey70') + 
        
        # solid blue line for estimated (adjusted) mortality
        geom_line(data=preddata, mapping=aes(x=tta30*30, y=fit), col="blue") +
        
        # solid red line for upper confidence interval
        geom_line(data=preddata, mapping=aes(x=tta30*30, y=upr), col="red") +
        
        # solid red line for lower confidence interval
        geom_line(data=preddata, mapping=aes(x=tta30*30, y=lwr), col="red") +
        
        # dashed line connecting buckets of raw unadjusted mortality
        geom_line(data=nicu.barplot60, mapping=aes(x=time_to_antibiotics, y=mortality.proportion), linetype=2) +
        
        # points indicating observed unadjusted mortality within the bucket
        geom_point(data=nicu.barplot60, mapping=aes(x=time_to_antibiotics, y=mortality.proportion, size=2)) +
        
        # manually draw legend
        geom_line(data=nicu.legend, mapping=aes(x=x, y=y+0.05), col="blue") +
        geom_text(data=nicu.legend[3], mapping=aes(x=x+5, y=y+.05, hjust='left', label='adjusted')) + 
        
        geom_line(data=nicu.legend, mapping=aes(x=x, y=y), linetype=2) +
        geom_point(data=nicu.legend[2], mapping=aes(x=x, y=y, size=2)) +
        geom_text(data=nicu.legend[3], mapping=aes(x=x+5, y=y, hjust='left', label='crude')) + 
        
        # label buckets across the top of the figure
        geom_errorbarh(data=nicu.barplot60, mapping=aes(xmin=time_to_antibiotics-25, xmax=time_to_antibiotics+25, y=0.9), height=.03) +
        geom_text(data=nicu.barplot60, mapping=aes(x=time_to_antibiotics, y=0.96, label=hour.label)) + 
        geom_label(data=nicu.barplot60, mapping=aes(x=time_to_antibiotics, y=0.9, label=sprintf("n=%d", N))) + 
        
        # lable x and y axes
        scale_x_continuous(name="Time to antibiotics (minutes)", breaks = seq(0,tmax,30), limits = c(0,tmax)) +
        scale_y_continuous(name=y.axis.title, breaks = seq(0,1,0.2)) +
        
        # provide color/legend theme for the figure
        theme(legend.position='none',
              panel.background = element_blank(),
              panel.border = element_rect(fill=NA, color='black'))
    )
    
    # close the plot file
    dev.off()
  }
  # function calculate standard errors using covariance matrix and provided vector of independent variables
  to.stderr <- function(vcov.matrix, C) sqrt(t(C) %*% vcov.matrix %*% C)
  
  # fit GEE models to generate predicted mortality figures. Note that model results reported in TTA paper were calculated in Stata.
  # construct 7 day mortality model
  mod <- nicu[blood_culture_positive==1&!is.na(gestational_age_at_birth_weeks), geeglm(overall_mortality_within_7_days ~ tta30 + gestational_age_at_birth_weeks + sex, id=as.factor(unique_patient_id), corstr = 'exchangeable', family='binomial')]
  # construct a data table for predictions, use the median gestational age for the blood culture positive cohort (31) and most common values for sex (1)
  nicu[blood_culture_positive==1, .(tta30=seq(1,tmax,0.5)/30, gestational_age_at_birth_weeks=31, sex=1)] -> preddata
  # calculate the predictions
  preddata[, fit := predict(mod, newdata = preddata, type='link')]
  # calculate the standard errors using the model's covariance matrix
  preddata[, se.fit := to.stderr(mod$geese$vbeta, c(1, tta30, gestational_age_at_birth_weeks, sex)), by=1:nrow(preddata)]
  # produce the figure for this model
  plot.it("Probability of 7-day mortality", nicu$overall_mortality_within_7_days, "tta-Probability-7-day-mortality.png")
  
  # construct 14 day mortality model
  mod <- nicu[blood_culture_positive==1&!is.na(gestational_age_at_birth_weeks), geeglm(overall_mortality_within_14_days ~ tta30 + gestational_age_at_birth_weeks + sex + comorbidity_surgical, id=as.factor(unique_patient_id), corstr = 'exchangeable', family='binomial')]
  # construct a data table for predictions, use the median gestational age for the blood culture positive cohort (31) and most common values for sex (1) and presence of surgical comorbidity (0)
  nicu[blood_culture_positive==1, .(tta30=seq(1,tmax,0.5)/30, gestational_age_at_birth_weeks=31, sex=1, comorbidity_surgical=0)] -> preddata
  # calculate the predictions
  preddata[, fit := predict(mod, newdata = preddata, type='link')]
  # calculate the standard errors using the model's covariance matrix
  preddata[, se.fit := to.stderr(mod$geese$vbeta, c(1, tta30, gestational_age_at_birth_weeks, sex, comorbidity_surgical)), by=1:nrow(preddata)]
  # produce the figure for this model
  plot.it("Probability of 14-day mortality", nicu$overall_mortality_within_14_days, "tta-Probability-14-day-mortality.png")
  
  # construct 30 day mortality model
  mod <- nicu[blood_culture_positive==1&!is.na(gestational_age_at_birth_weeks), geeglm(overall_mortality_within_30_days ~ tta30 + gestational_age_at_birth_weeks + sex + comorbidity_surgical, id=as.factor(unique_patient_id), corstr = 'exchangeable', family='binomial')]
  # construct a data table for predictions, use the median gestational age for the blood culture positive cohort (31) and most common values for sex (1) and presence of surgical comorbidity (0)
  nicu[blood_culture_positive==1, .(tta30=seq(1,tmax,0.5)/30, gestational_age_at_birth_weeks=31, sex=1, comorbidity_surgical=0)] -> preddata
  # calculate the predictions
  preddata[, fit := predict(mod, newdata = preddata, type='link')]
  # calculate the standard errors using the model's covariance matrix
  preddata[, se.fit := to.stderr(mod$geese$vbeta, c(1, tta30, gestational_age_at_birth_weeks, sex, comorbidity_surgical)), by=1:nrow(preddata)]
  # produce the figure for this model
  plot.it("Probability of 30-day mortality", nicu$overall_mortality_within_30_days, "tta-Probability-30-day-mortality.png")
}
