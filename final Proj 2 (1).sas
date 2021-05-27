/* Generated Code (IMPORT) */
/* Source File: complete_dataset.csv */
/* Source Path: /home/u57831460/sasuser.v94 */
/* Code generated on: 4/6/21, 5:29 PM */

%web_drop_table(WORK.IMPORT);


FILENAME REFFILE '/home/u57831460/sasuser.v94/complete_dataset.csv';
	
PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; 
RUN;


%web_open_table(WORK.IMPORT);

*to convert the data into monthly system;
proc timeseries data=work.import out=work.demand;
id date interval=month accumulate=mean;
var _numeric_;
run;
***********************************************************************************************************************;
*CHECKING OUTLIERS IN THE DATA;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=WORK.DEMAND;
	vbox demand /;
	yaxis grid;
run;

ods graphics / reset;

***********************************************************************************************************************;
*CHECKING OUTLIERS IN THE DATA;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=WORK.DEMAND;
	vbox RRP /;
	yaxis grid;
run;

ods graphics / reset;

***********************************************************************************************************************;

*to sort the data till 2019;
proc sql noprint;
	create table work.filter1 as select * from WORK.DEMAND 
		where date between '01JAN2015'd and '01DEC2019'd;
quit;
***********************************************************************************************************************;
title " checking for trend";
symbol1 interpol=join value=dot;
proc gplot data = work.filter1;
plot demand * date;
plot RRP*date;
run;

title " checking for trend";
symbol1 i=rl v=none c=red value=dot;
proc gplot data = work.filter1;
plot demand * date;
plot RRP*date;
run;

title " relationship between demand and RRP";
proc gplot data = work.filter1;
plot RRP*demand ;
RUN;
***********************************************************************************************************************;
*plotting demand, rainfall per month;
ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=WORK.filter1;
title height=14pt " Demand of electricity in Australia per month";
	bubble x=date y=demand size=demand/ colorresponse=demand colormodel=(CX667fa2 
		CXFAFBFE CXD05B5B) bradiusmin=7 bradiusmax=14;
	xaxis grid;
	yaxis grid;
run;

proc sgplot data=WORK.filter1;
title height=14pt "Recommended retail price in Australia per month";
	bubble x=date y=rrp size=rrp/ colorresponse=rrp datalabel=date
		colormodel=(CX667fa2 CXFAFBFE CXD05B5B) bradiusmin=7 bradiusmax=14;
	xaxis grid;
	yaxis grid;
run;

ods graphics / reset;
************************************************************************************************************************;
*dummy variables;

data work.dummy;
set work.filter1;

trend=_N_;

if month(date)=1 then Jan=1;
else jan=0;

if month(date)=2 then Feb=1;
else Feb=0;

if month(date)=3 then March=1;
else March=0;

if month(date)=4 then April=1;
else April=0;
if month(date)=5 then May=1;
else May=0;
if month(date)=6 then June=1;
else june=0;
if month(date)=7 then July=1;
else july=0;
if month(date)=8 then Aug=1;
else aug=0;
if month(date)=9 then Sept=1;
else sept=0;
if month(date)=10 then Oct=1;
else oct=0;
if month(date)=11 then Nov=1;
else Nov=0;

run;


*checking the autocorrelation;
proc autoreg data=work.dummy;
model demand=date/dwprob; *positive auto-correlation;
run;

proc autoreg data=work.filter1;
model RRP=date/dwprob; *positive auto-correlation;
run;
***************************************************************************************************************************;
title"Checking which differencing will be good?";
proc arima data = work.dummy;
i var =demand;

proc arima data = work.filter1;
i var =RRP;
***************************************************************************************************************************;
title "to check stationarity using unit root test";
proc arima data = work.dummy;
identify var = demand stationarity = (adf) ; 
*can see the demand is not stationary so we have to do the differencing;
identify var = demand(1) stationarity = (adf);
*IACF is dying down very slowly so its overdifferenced;
identify var = demand(1,12) stationarity = (adf) ;
 identify var = demand(12) stationarity = (adf) ;
 *trend is not significant, hence we have to add 1 to differencing;
identify var = demand (6,12) stationarity = (adf) ;
*NO SIGNIFCANT P-VALUES;
run;

proc arima data=work.dummy;
identify var=RRP(1) stationarity= (Adf);
identify var=RRP(2) stationarity= (Adf);
*IACF is dying down very slowly so its overdifferenced;

***************************************************************************************************************************;

*Checking which model is appropriate;
proc arima data = work.dummy;
identify var = demand(1,12) scan esacf minic;
run;

proc arima data = work.filter1;
identify var = RRP(1) scan esacf minic;
run;
***************************************************************************************************************************;

*Checking which model is appropriate;
title "model 3";
proc arima data = work.dummy;
identify var = demand(1,12) nlag=25 ;
estimate q= (1)(12) noint printall plot; *noint as our intercept was not significant,factored models as they have seasonality factor;
forecast lead=10 ;
run;

title "model 2";
proc arima data = work.filter1;
identify var = demand(1,12) nlag=25 ;
estimate p=(1) q=(1) printall plot; *the model is not adequate;
forecast lead=5;
run;

title "model 1";
proc arima data = work.filter1;
identify var = demand(1,12) nlag=25 ;
estimate q= (1) noint printall plot; *the model is not adequate for lag 12th;
forecast lead=5 ;
run;

*final model choosen is model 3;
proc arima data=Work.dummy plots
    (only)=(series(corr crosscorr) residual(corr normal) 
		forecast(forecastonly)) out=work.out;
	identify var=demand(1,12);
	estimate q=(1)(12) ma=(1.0) noint method=ml;
	forecast lead=10 back=0 alpha=0.05 id=date interval=month;
	run;
quit;

*checking which model is better for rrp;
proc arima data = work.filter1 plots (only)=(series(corr crosscorr) residual(corr normal) 
		forecast(forecastonly)) out=work.rrp ;
identify var = RRP(1) nlag=25 ;
estimate P= (1) ma=(1.0) method=ml NOINT  printall plot; 
forecast lead=10 back=0 alpha=0.05 id=date interval=month;
run;


*plotting the forecasted and model together for Demand;
data work.forecast;
set work.demand;
set work.out;
keep forecast date demand;
run;


proc print data= work.forecast;
run;

data errors;
set work.forecast;
Forecast_error=forecast-demand;
ABSDEVIATION = ABS(Forecast_error);
SQUARED_ERROR = Forecast_error ** 2;
RUN;

proc print data= work.errors;
run;

symbol1 interpol=join value=dot;
proc gplot data = work.errors;
plot forecast*date demand*Date  /overlay legend=legend1;
run;
quit; 
 
proc autoreg data=work.forecast;
model demand=date/ method=ml;
run;

proc autoreg data=work.f1;
model RRP=date/ method=ml;
run;

*plotting the forecasted and model together for RRP;
data work.f1;
set work.demand;
set work.rrp;
keep forecast date rrp;
run;


proc print data= work.f1;
run;

symbol1 interpol=join value=dot;
proc gplot data = work.f1;
 plot forecast*date rrp*Date/overlay legend=legend1;
run;
quit; 

***************************************************************************************************************************;

