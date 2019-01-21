proc delete data=_all_;
run;
proc delete data=sascha._all_;
run;

/*LISTAR OS ARQUIVOS DO DIRET�RIO*/
filename indata pipe 'dir D:\Estat�stica\ESTAT�STICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_Andr�\Dados /B'; /*pipe aux�lia na sele��o do diret�rio*/
data  file_list; 
	length arquivos$20.; 
	infile indata truncover ; /*truncover for�a o sas a parar de ler quando chega ao fim de uma linha*/
	input  arquivos $20.;  /* ler o nome dos arquivos do diretorio */
	call symput('num_files',_n_); /*call symput auxilia na extra��o e verifica��o da quantidade de arquivos no diret�rio*/
arquivos=compress(arquivos,',.txt');
run; 

/*CRIANDO UMA MACRO POR PROC SQL PARA GUARDAR O NOME DOS ARQUIVOS*/
proc sql;
  select arquivos into :lista separated by ' ' from file_list;
quit;

%let &lista;

/*######################### PARTE 1 ###################################*/

/*PEGANDO O NOME DAS VARI�VEIS*/
data var_names;
format v1-v9 $14. ;
 infile "D:\Estat�stica\ESTAT�STICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_Andr�\Dados\df1.txt" obs=1 dlm=" " missover dsd;
 input (v1-v9) ($);
run; 

/*ORGANIZANDO OS NOMES SEGUNDO A ORDEM CORRETA*/
data var_names(rename=(v9=v0) drop=v9);
retain v0 v1 - v8;
set var_names;
format v0 F16.;
run;

/*CRIANDO UMA MACRO PARA IMPORTAR OS ARQUIVOS*/
%macro importar(arquivo=);
filename data "D:\Estat�stica\ESTAT�STICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_Andr�\Dados\&arquivo..txt";
	data &arquivo;
	infile data dlm=" " missover dsd firstobs=2;
	input v0 (v1 - v8) ($);
	format v0 F16.;
	run;
%mend importar;

/*AQUI IREMOS IMPORTAR TODOS SEPARADOS A PARTIR DE UM LOOP SEGUNDO O TAMANHO DO DIRET�RIO*/
%macro fileout;
%do i=1 %to &num_files;
	%importar(arquivo=df&i);
		data df&i;
		set var_names df&i;
		run;
%end;
%mend fileout;
%fileout;

/*EXCLUIR PARA TODOS OS BANCOS A VARI�VEL V0*/
%macro excluiv0;
%do i=1 %to &num_files;
	data _null_;
	data df&i(drop = v0);
	set df&i;
	run;
%end;
run;
%mend excluiv0;
%excluiv0;

/*######################### PARTE 2 ###################################*/

/*CRIANDO UMA VARI�VEL MACRO PARA RENOMEAR SEGUNDO UM SAS DATA-SET*/
proc transpose data=df1(obs=1) out=names ;
  var _all_;
run;
proc sql;
  select catx('=',_name_,col1) 
    into :rename separated by ' ' from names;
quit;

/*FAZENDO A RENOMEA��O*/
%macro renomear;
%do i=1 %to &num_files;
	data df&i(rename=(&rename));
	set df&i;
	if v1 = 'sill_mat' then delete;
	run;
%end;
%mend renomear;
%renomear;

/*MACRO UTILIZADA PARA MUDAR UM BANCO INTEIRO*/
/*NESTE CASO IREMOS MUDAR TUDO QUE � CHAR PARA NUMERIC*/
%macro char_numeric;
%do i=1 %to &num_files;
proc contents data=df&i out=vars(keep=name type); 
data vars;                                                
set vars;                                                 
	if type=2;                               
	newname=trim(left(name))||"_n";                                                                               
	options symbolgen;                                        
*A op��o macro SYMBOLGEN  � selecionada � definida para podermos ver o que a 
	macro realizada no output do Log;
proc sql;                                         
select trim(left(name)), trim(left(newname)),             
       trim(left(newname))||'='||trim(left(name))         
into :c_list separated by ' ', :n_list separated by ' ',  
     :renam_list separated by ' '                         
from vars;                                                
quit;                                                                                                               
*aqui PROC SQL � usada para criar 3 vari�veis macro. Uma var macro chamada c_list
cont�m uma lista de cara vari�vel car�cter separada por um espa�o em branco. A macro
chamada n_list ir� conter uma lista com cada nova vari�vel num�rica separada por um espa�o
em branco. Por fim a var macro renam_list cont�m uma lista com cada nova var num�rica
separada por um sinal de "=" para ser usada na declara��o RENAME;
data df&i;                                               
set df&i;                                                 
	array ch(*) $ &c_list;                                    
	array nu(*) &n_list;                                      
		do i = 1 to dim(ch);                                      
  		nu(i)=input(ch(i),8.);                                  
		end;                                                      
	drop i &c_list;                                           
	rename &renam_list;                                                                                      
run;            
%end;
%mend char_numeric;
%char_numeric;

/*######################### PARTE 3 ###################################*/

/*EXCLUIR OS CASOS ONDE RANGE>100 E SILL>80*/
%macro excluir_casos;
%do i=1 %to &num_files;
data dff&i;
set df&i;
	array x[*] range_100_100 range_100_300 range_300_100 range_mat;  
	do i = 1 to dim(x);
	if x(i) >= 80 then x(i)=.;
	end; 
		array y[*] sill_100_100 sill_100_300 sill_300_100 sill_mat;
		do i = 1 to dim(y);
		if y(i) >= 100 then y(i)=.;
		end;
run;
%end;
%mend excluir_casos;
%excluir_casos;

/*EXCLUIR OS BANCOS QUE N�O SER�O MAIS USADOS*/
proc delete data= df1 - df5;
run;

libname sascha "D:\Estat�stica\ESTAT�STICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_Andr�\Sas_data_set";
/*PROC STDIZE*/
%macro subs_mean;
%do i=1 %to &num_files;
proc stdize data=dff&i out=sascha.df_new&i missing=mean reponly;  *ESSA PROC NOS PERMITE SUBSTIUTIR O MISSING PELA M�DIA;
  var _numeric_;
run;
%end;
%mend subs_mean;
%subs_mean;

/*######################### PARTE 4 ###################################*/

/*As sill s�o estima��es do par�metro (s2)=60*/
/*As range s�o estima��es par�metro (fi)=30*/

/*FAZENDO UMA MACRO PARA EXTRAIR A M�DIA E A VARI�NCIA*/
%macro estatistica(medida=,banco=);
proc means data=sascha.df_new5 noprint;
var _numeric_;
output out=sascha.&banco(drop=_type_ _freq_) &medida=;
run;
%mend estatistica;
%estatistica(medida=var,banco=variancia)
%estatistica(medida=mean,banco=media)

data sascha.newaux(drop= i);
set sascha.media sascha.variancia;
run;

/*TRANSFORMANDO AS MEDIDAS EM OBSERVA��ES*/
proc transpose data=sascha.newaux out=sascha.vies;
run; 

/*CRIANDO UM IDENTIFICADOR PARA DISTINGUIR OS PAR�METROS*/
data sascha.vies(rename=(col1=media col2=variancia));
set sascha.vies;
id=find(_name_,'range');
run;

/*ATRIBUINDO OS PAR�METROS E CALCULANDO O VI�S*/
data sascha.vies;
set sascha.vies;
	if id = 1 then theta=30 ;
	else theta=60;
		if id = 1 then bias=(media - theta) ;
		else bias=media - theta;
run;

/*CALCULANDO O REQM*/
data sascha.reqm;
set sascha.vies;
reqm= sqrt(variancia + bias**2);
run;

/*######################### PARTE 5 ###################################*/

/*HISTOGRAMA E CURVA DE DENSIDADE DAS DISTRIBUI��ES EMPREGADAS*/
title 'Distribui��o de sill_mat';
proc univariate data=sascha.Df_new2;
var sill_mat;
	histogram /gamma weibull lognormal;
inset median mean std skewness/ pos = ne  header = 'Estat�sticas';
axis1 label=(a=90 r=0);
run;

/*PAR�METROS E ESTIMATIVAS DAS DISTRIBUI��ES*/
ods select ParameterEstimates GoodnessOfFit FitQuantiles MyHist;
proc univariate data=sascha.Df_new2;
var sill_mat;
	histogram /gamma weibull lognormal;
inset median mean std skewness;
axis1 label=(a=90 r=0);
run;

/*MACRO PARA VERIFICAR OS GR�FICOS DO AJUSTE DAS ACAMULADAS INDIVIDUALMENTE*/
%macro ajuste(banco=, distrib=,var=);
ods graphics on;
proc severity data = &banco crit=aicc;
loss &var;
dist &distrib;
run;
%mend;
%ajuste(banco=sascha.Df_new2, distrib=logn,var=sill_mat);
%ajuste(banco=sascha.Df_new2, distrib=gamma,var=sill_mat);
%ajuste(banco=sascha.Df_new2, distrib=weibull,var=sill_mat);

/*MOSTRANDO TODOS OS M�TODOS DISPON�VEIS EM SEVERITY PARA ESCOLHA DO MELHOR MODELO AJUSTADO*/
ods graphics on;
proc severity data = sascha.Df_new2 crit=aicc print=all plots=(cdfperdist pp qq);
loss sill_mat;
dist logn gamma weibull;
run;




