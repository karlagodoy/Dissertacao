cap log close
clear all

cd "C:\Users\KarlaGodoyDaCostaLim\OneDrive - Latino Economic Development Center\Documents\ADM\karla"

log using dissertacao.log, replace
/*
**clean up data on number of personnel
**want # of personnel per mission per month/year
import delimited using odp_contributionsbygender.csv

rename mission_acronym mission 

***create month and year variables
gen date_report=date(last_reporting_date, "DM20Y")
format date_report %td
gen mo_report=month(date_report)
gen yr_report=year(date_report)
list last_reporting_date date_report mo_report yr_report in 1/10

***collapse data to add up all personnel in a mission/month/year
collapse (sum) female_personnel male_personnel, by(mission yr_report mo_report)


***create variables to match case data
tostring yr_report, g(yr)
tostring mo_report, g(mo)
gen yearmo=yr+ "0" +mo if mo_report<10
replace yearmo=yr+ mo if mo_report>=10
destring yearmo, replace

keep yearmo mission female_personnel male_personnel
sort mission yearmo
save numperson.dta, replace
*/
***clean up data on cases
**want # of cases and victims per mission per month/year
clear
use cases.dta

***create start and end dates for crime
encode crimestart_mo, g(crimest_mo)
recode crimest_mo (1=4) (2=6) (3=12) (4=2) (5=1) (6=7) (7=6) (8=3) (9=5) (10=11) (11=10) (12=9) (13/.=.)
label drop crimest_mo
tab crimest_mo, miss

encode crimeend_mo, g(crimeen_mo)
recode crimeen_mo (1=4) (2=6) (3=12) (4=2) (5=1) (6=7) (7=6) (8=3) (9=5) (10=11) (11=10) (12=9) (13/.=.)
label drop crimeen_mo
tab crimeen_mo, miss

destring crimestart_yr, g(crimest_yr) force
destring crimeend_yr, g(crimeen_yr) force


gen crime_start=mdy(crimest_mo, 15, crimest_yr)

*assign case date if no crime dates
gen crime_report=date(casedate, "MY")
format crime_report %td
gen mo_report=month(crime_report)
gen yr_report=year(crime_report)
replace crime_start=mdy(mo_report, 15, yr_report) if crime_start==.


*assign case month if no month
replace crime_start=mdy(mo_report,15,crimest_yr) if crimest_mo==.
gen crime_end=mdy(crimeen_mo, 15, crimeen_yr)

replace crime_end=mdy(mo_report,15,crimeen_yr) if crimeen_mo==.
format crime_start %td
format crime_end %td
list crime_start crimestart_mo crimestart_yr crime_report in 1/10
list crime_end crimeend_mo crimeend_yr crime_report in 1/10



***create binary variables for every month and year -- set to 1 if a crime occurred in that month/year
forvalues y=2002/2022 {
	forvalues m=1/9 {
gen d`y'0`m'=0
	}
}
forvalues y=2002/2022 {
	forvalues m=10/12 {
gen d`y'`m'=0
	}
}
forvalues y=2002/2022 {
	forvalues m=1/9 {
replace d`y'0`m'=1 if year(crime_start)==`y' & month(crime_start)==`m'
replace d`y'0`m'=1 if year(crime_end)==`y' & month(crime_end)==`m'
}
}
forvalues y=2002/2022 {
	forvalues m=10/12 {
replace d`y'`m'=1 if year(crime_start)==`y' & month(crime_start)==`m'
replace d`y'`m'=1 if year(crime_end)==`y' & month(crime_end)==`m'
}
}

*if no end date, then crime should only have one date
egen ndates=rsum(d*)
tab ndates if crime_end==.


*if the crime happened in 2 years, assign january as 1 (because can't do Jan in loop)
forvalues y=2003/2022 {
	local j= `y' -1
replace d`y'01=1 if ndates==2 & mdy(1,15,`y')>crime_start & mdy(1,15,`y')<crime_end
}

*if ndates=2, any 0s between the 2 dates should be assigned a 1
*can't do januarys in this loop
forvalues y=2002/2022 {
	forvalues m=2/9 {
		local j = `m' -1
replace d`y'0`m'=1 if ndates==2 & d`y'0`j'==1 & mdy(`m',15,`y')<crime_end
	}
}
forvalues y=2002/2022 {
	replace d`y'10=1 if ndates==2 & d`y'09==1 & mdy(10,15,`y')<crime_end
	forvalues m=11/12 {
		local j = `m' -1
replace d`y'`m'=1 if ndates==2 & d`y'`j'==1 & mdy(`m',15,`y')<crime_end
	}
}

**d201407 tells us if there was a crime committed in this mission in July 2014
tab d201407
list mission crime_start d201407
list in 6/10


***Create victim count and criminal count
**create vd201407 to tell us how many victims were hurt in this mission in July 2014
**create cd201407 to tell us how many criminals in this mission in July 2014

forvalues y=2002/2022 {
	forvalues m=1/9 {
		gen vd`y'0`m'=0
		gen cd`y'0`m'=0
	}
}
forvalues y=2002/2022 {
	forvalues m=10/12 {
		gen vd`y'`m'=0
		gen cd`y'`m'=0
	}
}
forvalues y=2002/2022 {
	forvalues m=1/9 {
		replace vd`y'0`m'=d`y'0`m'*numvictims
		replace cd`y'0`m'=d`y'0`m'*numpersonnel
	}
}
forvalues y=2002/2022 {
	forvalues m=10/12 {
		replace vd`y'`m'=d`y'`m'*numvictims
		replace cd`y'`m'=d`y'`m'*numpersonnel
	}
}


***collapse data to add up all cases, victims, personnel involved in a mission/month/year
***this makes is so that there is one observation per mission
collapse (sum) d* vd* cd*, by(mission)


***reshape the data so that every mission/yearmo is an observation
reshape long d vd cd, i(mission) j(yearmo)

save numcrimes.dta, replace

***Merge the cases data with the personnel data
merge mission yearmo using numperson.dta
tab _merge

**drop observations where there were no personnel on a mission
drop if _merge==1

***if a yearmo does not have a crime, set to 0
replace d=0 if _merge==2
replace vd=0 if _merge==2
replace cd=0 if _merge==2

***compute rates -- to make the numbers easy to interpret I set them to be
****number of crime/victims/criminal per 10000 personnel stationed
gen numpersonnel=female_personnel+male_personnel
gen crimerate=d/numpersonnel*10000
gen victimrate=vd/numpersonnel*10000
gen criminalrate=cd/numpersonnel*10000


replace mission= "MONUSCO" if mission== "MONUC"

encode mission, g(miss)

gen post=(yearmo>=201901)

tostring yearmo, g(yearmo_s)
gen year_s=substr(yearmo_s,1,4)
destring year_s, g(year)

*replace cdt=1 if mission=="
gen cdt=0
replace cdt=1 if mission=="UNIFIL"
replace cdt=1 if mission=="MINURSO"
replace cdt=1 if mission=="MONUSCO"
replace cdt=1 if mission=="UNISFA"
replace cdt=1 if mission=="UNMISS"
replace cdt=1 if mission=="MINUSMA"
replace cdt=1 if mission=="MINUSCA"



save missionmonth.dta, replace

sum numpersonnel if cdt ==1
sum numpersonnel if cdt ==0


drop if cdt== 0

replace crimerate=100 if crimerate>100
list victimrate criminalrate if crimerate==100


replace victimrate=100 if crimerate>100
replace criminalrate=100 if crimerate>100

sum victimrate, detail

sum criminalrate, detail


*results

table year if numpersonnel>25, stat(mean crimerate victimrate criminalrate)

sum numpersonnel crimerate victimrate criminalrate yearmo miss male_personnel 

* to see auto corelation 
dwstat

* Base year is 2010

tsset miss yearmo

prais crimerate post yearmo i.miss male_personnel if numpersonnel>25 , vce(robust)

prais victimrate post yearmo i.miss male_personnel if numpersonnel>25 , vce(robust)

prais criminalrate post yearmo i.miss male_personnel if numpersonnel>25 , vce(robust)

bysort year : sum numpersonnel crimerate victimrate criminalrate



*T tests


*Crimerate


ttest crimerate if numpersonnel>25, by(post) unequal



ttest crimerate if numpersonnel>25 & mission=="UNIFIL", by(post) unequal

ttest crimerate if numpersonnel>25 & mission=="MINURSO", by(post) unequal

ttest crimerate if numpersonnel>25 & mission=="MONUSCO", by(post) unequal

ttest crimerate if numpersonnel>25 & mission=="UNISFA", by(post) unequal

ttest crimerate if numpersonnel>25 & mission=="UNMISS", by(post) unequal


ttest crimerate if numpersonnel>25 & mission=="MINUSMA", by(post) unequal

ttest crimerate if numpersonnel>25 & mission=="MINUSCA", by(post) unequal

*victimrate

ttest victimrate if numpersonnel>25, by(post) unequal

ttest victimrate if numpersonnel>25 & mission=="UNIFIL", by(post) unequal

ttest victimrate if numpersonnel>25 & mission=="MINURSO", by(post) unequal

ttest victimrate if numpersonnel>25 & mission=="MONUSCO", by(post) unequal

ttest victimrate if numpersonnel>25 & mission=="UNISFA", by(post) unequal

ttest victimrate if numpersonnel>25 & mission=="UNMISS", by(post) unequal

ttest victimrate if numpersonnel>25 & mission=="MINUSMA", by(post) unequal

ttest victimrate if numpersonnel>25 & mission=="MINUSCA", by(post) unequal


*Criminalrate

ttest criminalrate if numpersonnel>25, by(post) unequal

ttest criminalrate if numpersonnel>25 & mission=="UNIFIL", by(post) unequal

ttest criminalrate if numpersonnel>25 & mission=="MINURSO", by(post) unequal

ttest criminalrate if numpersonnel>25 & mission=="MONUSCO", by(post) unequal

ttest criminalrate if numpersonnel>25 & mission=="UNISFA", by(post) unequal

ttest criminalrate if numpersonnel>25 & mission=="UNMISS", by(post) unequal

ttest criminalrate if numpersonnel>25 & mission=="MINUSMA", by(post) unequal

ttest criminalrate if numpersonnel>25 & mission=="MINUSCA", by(post) unequal


log close


