library(data.table)

# R functions to transform data from PCORNet/PTN format into variables commonly used in
# analysis of exposures and outcomes related to late onset sepsis among infants

# function to read NICU dataset that is in PCORNet/PTN format
read.nicu <- function(nicupath = "./") {
  episodes <- as.data.table(read.csv(Sys.glob(sprintf("%s/*nicusepsis*cohort*.csv", nicupath))[1]))
  
  # reformat episode table to be more convenient for merging with the PCORNet fomat data
  episodes <- episodes[,.(PAT_ID, PAT_ENC_CSN_ID, EPISODE_ID, ONSET_DTTM, ONSET_DT=as.POSIXct(ONSET_DTTM,format='%m/%d/%Y %H:%M'),SEPSIS_GROUP), keyby=.(PATID=SUBJECT_ID)]
  
  # if onset date is not plausible -- it may be a two digit year issue
  episodes[ONSET_DT < as.POSIXct('1900-01-01'), `:=`(ONSET_DT=as.POSIXct(ONSET_DTTM,format='%m/%d/%y %H:%M'))]
  
  ressup <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_RESSUP-*.csv", nicupath))[1]))
  ressup[, `:=`(RESP_SUPPORT_GIVEN_DT=as.POSIXct(RESP_SUPPORT_GIVEN_DATE), RESP_SUPPORT_STOP_DT=as.POSIXct(RESP_SUPPORT_STOP_DATE))]
  setkey(ressup, PATID)
  
  medadm <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_MEDADM-*.csv", nicupath))[1]))
  setkey(medadm, PATID)
  medadm[, MED_ADMIN_START_DT := as.POSIXct(MED_ADMIN_START_DT_TM)]
  
  labs <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_LABRST-*.csv", nicupath))[1]))
  setkey(labs, PATID)
  
  demog <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_DEMOGR-*.csv", nicupath))[1]))
  setkey(demog, PATID)
  
  enc <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_ENCNTR-*.csv", nicupath))[1]))
  setkey(enc, PATID)
  # describe length of stay in hours associated with each subject from admit through hospital discharge (more than just the NICU stay)
  # code as NA if child was still admitted at time of data extraction.
  enc[DISCHARGE_DT_TM=='', DISCHARGE_DT_TM := enc[,max(as.character(DISCHARGE_DT_TM))]]
  enc[, `:=`(ADMIT_DT=as.POSIXct(ADMIT_DT_TM, format="%F %H:%M"), DISCHARGE_DT=as.POSIXct(DISCHARGE_DT_TM, format="%F %H:%M"))]
  enc[, LOS_HOURS := ifelse(DISCHARGE_DT_TM == max(as.character(DISCHARGE_DT_TM)), NA, difftime(DISCHARGE_DT, ADMIT_DT, units = 'hours'))]
  # add admit/discharge date to each episode, associate each episode with first discharge after episode onset
  episodes <- enc[, .(ADMIT_DT, DISCHARGE_DT, LOS_HOURS), keyby=PATID][episodes[,.SD,keyby=PATID], allow.cartesian=T][DISCHARGE_DT>ONSET_DT,.SD,keyby=.(EPISODE_ID, DISCHARGE_DT)][,.SD[1],keyby=EPISODE_ID]
  episodes[, ADMIT_HOURS_AT_ONSET := as.numeric(difftime(ONSET_DT, ADMIT_DT, units = 'hours'))]
  setkey(episodes, PATID)
  
  assess <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_ASSESS-*.csv", nicupath))[1]))
  setkey(assess, PATID)
  assess[, ASSESS_DT := as.POSIXct(ASSESS_DT_TM)]
  
  vitals <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_VITALS-*.csv", nicupath))[1]))
  setkey(vitals, PATID)
  
  probs <- as.data.table(read.csv(Sys.glob(sprintf("%s/NICU_PTN_CONDTN-*.csv", nicupath))[1]))
  setkey(probs, PATID)
  
  list(episodes=episodes, ressup=ressup, medadm=medadm, labs=labs, demog=demog, enc=enc, assess=assess, vitals=vitals, probs=probs)
}

# little helper functions
na.as.0 <- function(x) ifelse(is.na(x), 0, x)
na.as.F <- function(x) ifelse(is.na(x), F, x)

# helper function to calculate day number based on sepsis onset date
date.to.daynum <- function(onset.dt, dt) {
  # Deal with UTC issue -- as.Date converts to calendar day in UTC by default unless explicitly told to work in local time
  daynum <- as.numeric(as.Date(dt, tz=Sys.timezone()) - as.Date(onset.dt, tz=Sys.timezone())) + 1
  
  # need to recode 12 hours prior to onset time as "Day 1" and anything prior to that as "before sepsis (NA)"
  daynum[dt<onset.dt&as.numeric(difftime(onset.dt, dt, units = 'secs'))/3600 <= 12] <- 1
  daynum[dt<onset.dt&as.numeric(difftime(onset.dt, dt, units = 'secs'))/3600 > 12] <- -1
  
  return(daynum)
}

# days to next episode
episode.days <- function(nicu) {
  epi <- nicu$episodes[, .(NEXT_DATE=as.Date(NA), EPISODE_ID), keyby=.(PATID,ONSET_DATE=as.Date(ONSET_DT, tz=Sys.timezone()))]
  epi[ , N:=.N,by=PATID]
  epi <- epi[N>1]
  epi[, NEXT_DATE := c(ONSET_DATE[2:.N],NA), by=PATID]
  epi[, DAYS_TO_NEXT_EPISODE := as.numeric(NEXT_DATE-ONSET_DATE)]
  epi[DAYS_TO_NEXT_EPISODE<28, DAYS_TO_NEXT_EPISODE, keyby=EPISODE_ID]
}

# return list of sepsis days with mechanical ventilation
# if day #0 is listed as a ventilator day, that indicates the infant was intubated at the time of sepsis onset
vent.days <- function(nicu) {
  ressup <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][nicu$ressup, allow.cartesian=T] 
  ressup[, `:=`(RESP_SUPPORT_GIVEN_DAYNUM=date.to.daynum(ONSET_DT, RESP_SUPPORT_GIVEN_DT),
                RESP_SUPPORT_STOP_DAYNUM=date.to.daynum(ONSET_DT, RESP_SUPPORT_STOP_DT))]
  
  # return in sorted episode/daynum order, combining day 0 support
  rbind(
    ressup[RESP_SUPPORT_TYPE=='01'&RESP_SUPPORT_GIVEN_DAYNUM<=1&RESP_SUPPORT_STOP_DAYNUM>=1,.(EPISODE_ID,DAYNUM=0)], # day 0 support
    nicu$episodes[,.(DAYNUM=1:28),keyby=EPISODE_ID][
      ressup[RESP_SUPPORT_TYPE=='01',.SD,keyby=EPISODE_ID],allow.cartesian=T][
        RESP_SUPPORT_GIVEN_DAYNUM<=DAYNUM&RESP_SUPPORT_STOP_DAYNUM>=DAYNUM,.(EPISODE_ID,DAYNUM)])[  # day 1-28 support
          , .N, keyby=.(EPISODE_ID,DAYNUM)][, .(EPISODE_ID,DAYNUM)]
}

inotrope.days <- function(nicu) {
  medadm.inotrope <- nicu$medadm[MED_ADMIN_DOSE_UNIT=='ug/kg/min'&grepl('(?i)(epinephrine|nor.?epi|dopamin|dobutam).*infus.*(line|custom)',MED_ADMIN_GENERIC_NAME)]
  
  # exclude dopamine infusions with dose < 4, which are sometimes used to treat right heart failure (rather than hyoptension)
  # see e-mail from Melissa on 6/30/17 -- translates to "include all epi/norepi/dobuta infusions OR infusions with dose >= 4
  medadm.inotrope <- medadm.inotrope[MED_ADMIN_DOSE>=4|grepl('(?i)epinephrine|nor.?epi|dobutam',MED_ADMIN_GENERIC_NAME)]
  
  # add in episode info
  medadm.inotrope <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][medadm.inotrope, allow.cartesian=T]
  medadm.inotrope[, DAYNUM := date.to.daynum(ONSET_DT, MED_ADMIN_START_DT)]
  
  # determine inotrope support on day 0, based on heuristics developed by manual chart review
  medadm.inotrope.day0 <- medadm.inotrope[MED_ADMIN_START_DT<=ONSET_DT, .(LAST_INOTROPE_HOURS=round(max(as.numeric(difftime(MED_ADMIN_START_DT, ONSET_DT, units = 'hours'))))), keyby=EPISODE_ID]
  medadm.inotrope.day0 <- medadm.inotrope[MED_ADMIN_START_DT>ONSET_DT, .(NEXT_INOTROPE_HOURS=round(min(as.numeric(difftime(MED_ADMIN_START_DT, ONSET_DT, units = 'hours'))))), keyby=EPISODE_ID][medadm.inotrope.day0]
  medadm.inotrope.day0[, INOTROPE := F]
  # if support present on day 1, assume it was present at baseline
  medadm.inotrope.day0[EPISODE_ID %in% medadm.inotrope[DAYNUM==1, EPISODE_ID], INOTROPE := T]
  # in addition, will flag kids who had inotrope support mentioned both within 48 hours before and after (and no more than 48 hours apart -- manual review confirmed all these
  # kids were on dopa at 5 or higher on day 1 of sepsis -- only flags an additional 5 kids)
  medadm.inotrope.day0[LAST_INOTROPE_HOURS>-48 & NEXT_INOTROPE_HOURS<48 & NEXT_INOTROPE_HOURS-LAST_INOTROPE_HOURS, INOTROPE := T]
  
  # combine with day 1:28 support
  # TODO: sometimes documentation is only on alternate days -- may need to fill in gaps in case where support only documented
  # on alternate days
  rbind(medadm.inotrope.day0[INOTROPE==T, .(EPISODE_ID, DAYNUM=0)], # day 0 support
    medadm.inotrope[DAYNUM %in% 1:28, .(EPISODE_ID,DAYNUM)])[       # day 1-28 support
      , .N, keyby=.(EPISODE_ID,DAYNUM)][, .(EPISODE_ID,DAYNUM)]
}

all.cultures <- function(nicu) {
  micro.viral.re = '(?i)cult|pcr.*virus|virus.*pcr|(cmv|ebv|hbv|hepatitis c|hepatitis b|hcv|hsv|hhv-6|mumps|varicella|vzv|wnv).*pcr'
  exclude.re = '(?i)hiv|dna|qual|quant|antb|antibody'
  nicu$labs[(grepl(micro.viral.re,LAB_PANEL)|grepl(micro.viral.re,LAB_LONG_NAME))&!(grepl(exclude.re,LAB_PANEL)|grepl(exclude.re,LAB_LONG_NAME))]
}

positive.cultures <- function(nicu)
  all.cultures(nicu)[!grepl('(?i)no growth|^negative|^normal|received by lab|\\bno \\w* isolated', RAW_RESULT)]

culture.results <- function(nicu) {
  # add culture result information
  labs.cult <- positive.cultures(nicu)
  labs.cult <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][labs.cult, allow.cartesian=T]
  labs.cult[, DAYNUM := date.to.daynum(ONSET_DT, as.POSIXct(SPECIMEN_COLLECTED_DT_TM))]
  # filter out the negatives, restrict analysis to day #1
  labs.cult <- labs.cult[DAYNUM == 1]
  labs.cult[, RAW_RESULT := gsub('^\\s+|\\s+$', '', gsub('\\s+', ' ', RAW_RESULT))]
  labs.cult <- labs.cult[, .SD[1], keyby=.(EPISODE_ID, LAB_PANEL, LAB_SHORT_NAME, RAW_RESULT)]
  # separate out micro results from viral and return results
  labs.result <- labs.cult[grepl('CULT',LAB_PANEL), .(BACTERIAL_CX=paste(sprintf("%s: %s", ifelse(LAB_PANEL=='BODY FLUID CULTURE AND GRAM STAIN',
                                                                                                  ifelse(SPECIMEN_SOURCE=='OT', toupper(as.character(SPECIMEN_SOURCE_OTH)), 
                                                                                                         as.character(SPECIMEN_SOURCE)), as.character(LAB_PANEL)), RAW_RESULT), collapse = '; ')), keyby=EPISODE_ID]
  labs.cult[!grepl('CULT',LAB_PANEL)&DAYNUM == 1, .(VIRAL_CX=paste(sprintf("%s: %s", LAB_SHORT_NAME, RAW_RESULT), collapse = '; ')), keyby=EPISODE_ID][labs.result]
}

central.lines <- function(nicu) {
  # deal with Central Venous Line
  assess.cvl <- nicu$assess[ASSESS_CAT_TYPE=='CVL', .(ASSESS_DT, ASSESS_TOOL), keyby=PATID]

  assess.cvl <- nicu$episodes[, .(EPISODE_ID, ONSET_DT), keyby=PATID][assess.cvl, allow.cartesian=T]
  assess.cvl[, DAYNUM := date.to.daynum(ONSET_DT, ASSESS_DT)]
  # restrict to informatino about presence of lines on sepsis day #1
  assess.cvl <- assess.cvl[DAYNUM==1]
  
  # code presence or absence of CVL, UAC, and ECMO on day of sespsis onset
  cohort <- nicu$episodes[, .(CVL=F, UAC=F, ECMO=F), keyby=EPISODE_ID]
  cohort[EPISODE_ID %in% assess.cvl[DAYNUM==1&grepl('(?i)CVL|PICC|\\bPORT\\b|CENTRAL.*VENOUS|UVC',ASSESS_TOOL), EPISODE_ID], CVL := T]
  cohort[EPISODE_ID %in% assess.cvl[DAYNUM==1&grepl('(?i)UAC',ASSESS_TOOL), EPISODE_ID], UAC := T]
  cohort[EPISODE_ID %in% assess.cvl[DAYNUM==1&grepl('(?i)ECMO',ASSESS_TOOL), EPISODE_ID], ECMO := T]
  
  return(cohort[, .(CVL, UAC, ECMO), keyby=EPISODE_ID])
}

antibiotic.medadm <- function(nicu) {
  # restrict to intravascular antibiotics
  abx <- nicu$medadm[(MED_ADMIN_ROUTE %in% c(11,13)|MED_ADMIN_ROUTE=='OT'&grepl('(?i)\\bcircuit', MED_ADMIN_ROUTE_OTHER))&MED_ADMIN_DOSE_UNIT %in% c('mg','IU')&grepl('(?i)sulfameth|cillin|m[iy]cin|\\bcef|flox|kacin|penem|linezolid|metronidazole|rifampin', MED_ADMIN_GENERIC_NAME)]
  # exclude cefazolin, oseltamivir, metronidazole and daily Ampicillin at 50mg/kg (prophylactic abx)
  abx <- abx[!grepl('(?i)cefazolin|metronidazole', MED_ADMIN_GENERIC_NAME)]
  
  # exclude doses of Ampicillin that are "daily" (18+ hours from nearest dose, if any, and at 50 mg/kg)
  # first calculate time delta from prior and next doses
  abx[, `:=`(PREV_DELTA=as.numeric(difftime(MED_ADMIN_START_DT, c(as.POSIXct(NA),MED_ADMIN_START_DT[-.N]), units = 'hours')),
             NEXT_DELTA=as.numeric(difftime(c(MED_ADMIN_START_DT[-1], as.POSIXct(NA)), MED_ADMIN_START_DT, units = 'hours'))), by=PATID]
  # second, do the actual exclusion
  abx[!(grepl('(?i)amp', MED_ADMIN_GENERIC_NAME)&between(MED_ADMIN_DOSE/MED_DOSING_WEIGHT,45,55)&!na.as.F(PREV_DELTA<18)&!na.as.F(NEXT_DELTA<18))]
}

antibiotic.days.admission <- function(nicu) {
  medadm.abx <- antibiotic.medadm(nicu)
  medadm.abx[, ADMIT_DT := as.POSIXct(ADMIT_DT_TM)]
  medadm.abx[, DAYNUM := date.to.daynum(ADMIT_DT, MED_ADMIN_START_DT)]
  return(medadm.abx[,.N,keyby=.(PATID, ADMIT_DT, DAYNUM)][, .(PATID, ADMIT_DT, DAYNUM)])
}

antibiotic.days <- function(nicu) {
  medadm.abx <- antibiotic.medadm(nicu)
  medadm.abx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT) , keyby=PATID][medadm.abx, allow.cartesian=T] 
  medadm.abx[, DAYNUM := date.to.daynum(ONSET_DT, MED_ADMIN_START_DT)]
  
  cohort <- nicu$episodes[,.(DAYNUM=1:28,ABX=F),keyby=EPISODE_ID][,.SD,keyby=.(EPISODE_ID,DAYNUM)]
  cohort[J(medadm.abx[,.(EPISODE_ID,DAYNUM)]), ABX := T]
  setkey(cohort, EPISODE_ID)
  cohort <- cohort[DAYNUM>1&ABX==F,.(ABXFREEDAY=min(DAYNUM)),keyby=EPISODE_ID][cohort]
  cohort[DAYNUM >= ABXFREEDAY, ABX := F]
  
  return(cohort[ABX==T, .N, keyby=.(EPISODE_ID, DAYNUM)][, .(EPISODE_ID, DAYNUM)])
}

time.to.antibiotic = function(nicu) {
  medadm.abx <- antibiotic.medadm(nicu)
  medadm.abx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT) , keyby=PATID][medadm.abx, allow.cartesian=T] 
  medadm.abx[, ADMIN_SECONDS := as.numeric(difftime(MED_ADMIN_START_DT, ONSET_DT, units = 'secs'))]
  # TODO: check to see if I goofed. --- check EPISODE_ID
  prior.abx <- medadm.abx[between(ADMIN_SECONDS,-48*60*60,-1)][, .(PRIOR_ADMIN_SECONDS=max(ADMIN_SECONDS)),keyby=EPISODE_ID][J(nicu$episodes$EPISODE_ID),.SD,keyby=EPISODE_ID]
  next.abx <- medadm.abx[between(ADMIN_SECONDS, 0, 24*60*60)][, .(NEXT_ADMIN_SECONDS=min(ADMIN_SECONDS)),keyby=EPISODE_ID][J(nicu$episodes$EPISODE_ID),.SD,keyby=EPISODE_ID]
  prior.abx[next.abx]
}

# use Schmatz definitions for co-morbidities
comorbidities <- function(nicu) {
  # add co-morbidity data
  # first list snomed codes for the co-morbidities
  ivh_shunt <- c(240313004, 206196005, 288276001, 722582007, 206395003,
                 206396002, 206397006, 261808007, 70611002, 47020004,
                 371077002, 432616009, 700132008, 161694000,271986005,
                 699006006, 23276006, 111746009, 195239002, 230769007,
                 230808006, 276652002, 371077002, 432616009, 276650005) 
  
  shunt <- c(47020004, 111746009, 230808006, 371077002, 432616009, 699006006, 700132008)
  
  surgical <- c(253101008, 253100009, 253100009, 15671007, 445116003,
                53776005, 204021005, 253103006, 253104000, 52330001,
                65455002, 42376006, 253109005, 253108002, 4088009,
                4113009, 15139001, 271569006, 253132009, 302882002,
                253131002, 253133004, 230746009, 53318002, 253117002, 253112008,
                253119004, 37382001, 103771000119101, 253120005, 203998000,
                204005000, 203994003, 61819007, 204006004, 58557008,
                76916001, 32232003, 77224008, 445307009, 53318002, 203955004,
                40130009, 204008003, 30620003, 253185002, 373587001, 253186001,
                253187005, 253117002, 111318005, 59128005, 268194008, 29938001,
                10375008, 28065000, 275262008, 29110005, 204691002, 31686000,
                268213006, 69518005, 253886003, 118642009, 17190001,
                196863007, 196859000, 301008003, 236032006, 67508005, 330007004,
                196867008, 81336004, 6667002, 70013003, 60697001, 
                111440002, 205777005, 43387009, 458085000, 30248008, 458044005,
                76089002, 24533004, 86417009, 161533003, 161572004, 18792003,
                25896009, 26179002, 27729002, 37054000, 50513008, 51118003,
                59514009, 77480004, 93032003, 95435007, 204712000,
                253764008, 268201001, 360491009, 61758007, 236645006, 253900005,
                95575002, 310670008, 72951007, 204731006, 204739008, 204741009,
                444860006, 301232003)
  
  cardiac <- c(13213009, 718556007, 445898001, 253333008,253542002, 78485007, 422348008, 448619007, 253650001,
               26201005, 253528005, 204448004, 448007000, 717859007, 444851003, 263960005, 448162007, 720567008,
               717943008, 268174004, 720605009, 720606005, 719456001, 720639008, 63191000119107, 253334002, 447874007,
               253272009, 447938004, 447824005, 448920004, 253267000, 448064005, 253511007, 413905004, 204395001, 28574005,
               70320004, 204394002, 718181001, 48121000, 93051009, 75270000, 204398004, 237227006, 253264007, 93078006,93262004,
               51789008, 10818008, 128567004, 64862009, 253527000, 253525008, 59494005, 73660006, 472801002, 41514002, 128568009,
               253269002, 12770006, 78250005, 204311009, 83130006, 445928005, 15459006, 204351007, 264467005, 459062008, 253364005,
               446916007, 719395001, 721009008,363028003,721010003, 721013001, 204399007, 19092004, 448681000, 253335001, 128563000, 722027009,
               253547008, 719400000, 123661007, 721976003, 264086008, 722461004, 94150003, 412787009, 719379001, 94702005,5203004,
               722051004, 718681002, 722206009, 718216009, 8239009, 253523001, 268180007, 253533009, 721073008, 715987000, 253691004,
               716740009, 253524007, 2829000, 447285001, 30288003, 448096002, 253667008,91841003,204451006,460890003,14482000,62023000,
               721688004,717866008,703329004,297218007,447823004,92977007,59877000,92994009,93018000,36110001,111322000,432461000,
               2213002,93057008,93061002,93067003,13213009,93329009,93353003,473394001,471294009,397894003,27986000,93392005,253329001,
               722211006,31481000,128599005, 714180007,448743001,253363004,253427003,473383000,253406008,448618004,448643005,253385005,
               448159009,425548001,75473000,194845005,448982005,50570003,65340007,82608003,195126007,68583001,445512009,473372009,472835004,
               41884003,35304003,398995000,8186001,399617002,445294008,13213009,53741008,67682002,29899005,373093003,234010000,398274000,
               63739005,253323000,27097002,399020009,66595008,195032004,65457005,287272002,370513009,282729004,27277001,40445007,44241007,
               609389009,233873004,204391005,471841009,86175003,414545008,373905003,253352002,253535002,253400002,91335003,64077000,57373003,
               387842002,457632005,457607008,448581008,195141007,195142000,31080005,68602002,234181008,253339007,253516002,29889000,27007008,
               16573007,448478000,15629741000119102,457637004,457612009,253732001,253380000,253579004,417094009,448305002,459055004,6210001,
               266249003,253549006, 26146002)
  
  chronic_lung <- c(29596007, 39871006, 59006007, 67569000, 67905004, 161685006, 233782000, 302108003, 363225006, 413839001, 427896006, 428173007)
  
  nec <- c(2707005, 32097002, 43752006, 64613007, 206525008, 442461003)
  
  first.dx <- function(codes, re='nomatch', exclude.re='nomatch')  nicu$probs[(grepl(re, CONDITION, perl=T)|COND_CODE %in% codes)&!grepl(exclude.re, CONDITION, perl=T), .SD, keyby=.(REPORT_DT_TM=as.POSIXct(ONSET_DATE), PATID)][,.SD[1],keyby=PATID]
  
  nec.dx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][first.dx(nec, '(?i)nec.*(enter|colitis)')[,.(REPORT_DT_TM),keyby=PATID]][REPORT_DT_TM < ONSET_DT,.SD,keyby=EPISODE_ID]
  cld.dx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][first.dx(chronic_lung, '(?i)chron.*(resp|lung)|tracheos|bpd|broncho.*pulm.*dys')[,.(REPORT_DT_TM),keyby=PATID]][REPORT_DT_TM < ONSET_DT,.SD,keyby=EPISODE_ID]
  cardiac.dx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][first.dx(cardiac, '(?i)pulm.*arter|transpos.*art|\\btga\\b|\\btof\\b|tet.*fal|hypolas|double|hlhs|interruption.*aortic|coarct|anom.*pulm|ebstein|(common|complete).*canal')[,.(REPORT_DT_TM),keyby=PATID]][REPORT_DT_TM < ONSET_DT,.SD,keyby=EPISODE_ID]
  surgery.dx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][first.dx(surgical, '(?i)cdh|cong.*dia.*hern|bps|(bronch|pulm).*seq|ccam|cong.*cyst.*aden|gastrosch|omphalocel|hir.*prun|imperf|encephalocele|syrinx.*spin|spina.*bifida|myel.*men.*cele|aqueduct|teratoma|mesoblast|hepatoblast', '(?i)spontan.*(pda|pat.*duct.*art)|history.*genetic.*condition')[,.(REPORT_DT_TM),keyby=PATID]][REPORT_DT_TM < ONSET_DT,.SD,keyby=EPISODE_ID]
  ivh.shunt.dx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][first.dx(ivh_shunt, '(?i)ivh|intr.*ven.*hem|\\bv.*p.*shunt')[,.(REPORT_DT_TM),keyby=PATID]][REPORT_DT_TM < ONSET_DT,.SD,keyby=EPISODE_ID]
  shunt.dx <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][first.dx(shunt, '(?i)\\bv.*p.*shunt')[,.(REPORT_DT_TM),keyby=PATID]][REPORT_DT_TM < ONSET_DT,.SD,keyby=EPISODE_ID]
  
  # look for runs of pip-tazo to identify additional NEC episodes
  
  # restrict to those kids with at least 7 days of pip.tazo treatment
  medadm.piptazo <- nicu$medadm[grepl('(?i)pip.*taz',MED_ADMIN_GENERIC_NAME),.SD,keyby=PATID]
  medadm.piptazo[, ADMIT_DAY := as.numeric(as.Date(MED_ADMIN_START_DT, tz=Sys.timezone()) - as.Date(ADMIT_DT_TM, tz=Sys.timezone())) + 1]
  medadm.piptazo <- nicu$episodes[,.(EPISODE_ID, ONSET_DT), keyby=PATID][medadm.piptazo, allow.cartesian=T][MED_ADMIN_START_DT < ONSET_DT]
  
  medadm.piptazo.days <- medadm.piptazo[,.(ADMIT_DAY=min(ADMIT_DAY):max(ADMIT_DAY),RX = F),keyby=EPISODE_ID][, RX, keyby=.(EPISODE_ID, ADMIT_DAY)]
  medadm.piptazo.days[medadm.piptazo[,.(EPISODE_ID, ADMIT_DAY)], RX := T]
  
  medadm.piptazo.days[,rle(RX),by=EPISODE_ID][values==T&lengths>=7][,.N,keyby=EPISODE_ID] -> medadm.piptazo.episodes
  
  # add indicator variables for each co-morbidity
  cohort <- nicu$episodes[, .(NEC = F, IVHSHUNT = F, VPSHUNT = F, SURGICAL = F, CARDIAC = F, CLD = F), keyby=.(EPISODE_ID, PATID)][,.SD,keyby=EPISODE_ID]
  cohort[medadm.piptazo.episodes, NEC := T]
  cohort[nec.dx, NEC := T]
  cohort[cld.dx, CLD := T]
  cohort[cardiac.dx, CARDIAC := T]
  cohort[surgery.dx, SURGICAL := T]
  cohort[ivh.shunt.dx, IVHSHUNT := T]
  cohort[shunt.dx, VPSHUNT := T]
  
  # for cardiac and surgical: if condition ever present, then apply to all episodes
  cohort[, `:=`(CARDIAC=as.logical(max(CARDIAC)), SURGICAL=as.logical(max(SURGICAL))), by=PATID]
  return(cohort[, .(NEC, IVHSHUNT, VPSHUNT, SURGICAL, CARDIAC, CLD), keyby=EPISODE_ID])
}

# helper function to inspect antibiotic exposure for a particular episode
inspect.antibiotics = function(nicu, episode.id) {
  epi <- nicu$episodes[EPISODE_ID==episode.id]
  abx <- antibiotic.medadm(nicu)[PATID==epi$PATID]
  abx[, DAYNUM := date.to.daynum(epi$ONSET_DT, MED_ADMIN_START_DT)]
  abx[DAYNUM %in% 0:7]
}

sepsis.group = function(nicu) {
  cohort <- nicu$episodes
  # add date of death
  cohort <- nicu$demog[, .(DEATH_DT=as.POSIXct(DEATH_DATE, format='%F %H:%M')),keyby=PATID][cohort[,.SD,keyby=PATID]]
  setkey(cohort, EPISODE_ID)
  cohort <- culture.results(nicu)[cohort]
  cohort <- antibiotic.days(nicu)[,.(EPISODE_ABX_DAYS=.N), keyby=EPISODE_ID][cohort]
  # days to next episode
  cohort <- episode.days(nicu)[cohort]
  
  # any positive fungal -- categorize as fungal
  cohort[SEPSIS_GROUP==9&grepl('BLOOD:\\s*CANDIDA',BACTERIAL_CX), SEPSIS_GROUP := 5]
  # any positive viral without positive culture -- categorize as viral
  cohort[SEPSIS_GROUP==9&!is.na(VIRAL_CX)&!grepl('URINE|BLOOD|CSF|PERITONEAL|PLEURAL',BACTERIAL_CX), SEPSIS_GROUP := 4]
  # if more than 5 days abx and culture positive (urine/blood/csf/peritoneal or pleural source), code as culture positive sepsis
  cohort[SEPSIS_GROUP==9&EPISODE_ABX_DAYS>5&grepl('URINE|BLOOD|CSF|PERITONEAL|PLEURAL',BACTERIAL_CX),SEPSIS_GROUP := 1]
  # for children who died within 5 days of sepsis onset with positive cultures, code as bacterial sepsis
  cohort[SEPSIS_GROUP==9&grepl('URINE|BLOOD|CSF|PERITONEAL|PLEURAL',BACTERIAL_CX)&as.numeric(difftime(DEATH_DT, ONSET_DT, units = 'days'))<5, SEPSIS_GROUP := 1]
  
  cohort[SEPSIS_GROUP==9&EPISODE_ABX_DAYS>5&is.na(VIRAL_CX), SEPSIS_GROUP := 3]
  # for children who died within 5 days of sepsis onset, code as presumed sepsis
  cohort[SEPSIS_GROUP==9&as.numeric(difftime(DEATH_DT, ONSET_DT, units = 'days'))<5, SEPSIS_GROUP := 3]

  # remaining kids with < 4 days abx treated as "not septic"
  cohort[SEPSIS_GROUP==9&EPISODE_ABX_DAYS<4&(is.na(DAYS_TO_NEXT_EPISODE)|DAYS_TO_NEXT_EPISODE>EPISODE_ABX_DAYS)&!grepl('URINE|BLOOD|CSF|PERITONEAL|PLEURAL',BACTERIAL_CX), SEPSIS_GROUP := 2]
  
  
  cohort[, SEPSIS_GROUP, keyby=EPISODE_ID]
}
