proc delete data=_all_;
run;
proc delete data=sascha._all_;
run;

/*LISTAR OS ARQUIVOS DO DIRETÓRIO*/
filename indata pipe 'dir D:\Estatística\ESTATÍSTICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_André\Dados /B'; /*pipe auxília na seleção do diretório*/
data  file_list; 
	length arquivos$20.; 
	infile indata truncover ; /*truncover força o sas a parar de ler quando chega ao fim de uma linha*/
	input  arquivos $20.;  /* ler o nome dos arquivos do diretorio */
	call symput('num_files',_n_); /*call symput auxilia na extração e verificação da quantidade de arquivos no diretório*/
arquivos=compress(arquivos,',.txt');
run; 

/*CRIANDO UMA MACRO POR PROC SQL PARA GUARDAR O NOME DOS ARQUIVOS*/
proc sql;
  select arquivos into :lista separated by ' ' from file_list;
quit;

%let &lista;

/*######################### PARTE 1 ###################################*/

/*PEGANDO O NOME DAS VARIÁVEIS*/
data var_names;
format v1-v9 $14. ;
 infile "D:\Estatística\ESTATÍSTICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_André\Dados\df1.txt" obs=1 dlm=" " missover dsd;
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
filename data "D:\Estatística\ESTATÍSTICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_André\Dados\&arquivo..txt";
	data &arquivo;
	infile data dlm=" " missover dsd firstobs=2;
	input v0 (v1 - v8) ($);
	format v0 F16.;
	run;
%mend importar;

/*AQUI IREMOS IMPORTAR TODOS SEPARADOS A PARTIR DE UM LOOP SEGUNDO O TAMANHO DO DIRETÓRIO*/
%macro fileout;
%do i=1 %to &num_files;
	%importar(arquivo=df&i);
		data df&i;
		set var_names df&i;
		run;
%end;
%mend fileout;
%fileout;

/*EXCLUIR PARA TODOS OS BANCOS A VARIÁVEL V0*/
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

/*CRIANDO UMA VARIÁVEL MACRO PARA RENOMEAR SEGUNDO UM SAS DATA-SET*/
proc transpose data=df1(obs=1) out=names ;
  var _all_;
run;
proc sql;
  select catx('=',_name_,col1) 
    into :rename separated by ' ' from names;
quit;

/*FAZENDO A RENOMEAÇÃO*/
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
/*NESTE CASO IREMOS MUDAR TUDO QUE É CHAR PARA NUMERIC*/
%macro char_numeric;
%do i=1 %to &num_files;
proc contents data=df&i out=vars(keep=name type); 
data vars;                                                
set vars;                                                 
	if type=2;                               
	newname=trim(left(name))||"_n";                                                                               
	options symbolgen;                                        
*A opção macro SYMBOLGEN  é selecionada é definida para podermos ver o que a 
	macro realizada no output do Log;
proc sql;                                         
select trim(left(name)), trim(left(newname)),             
       trim(left(newname))||'='||trim(left(name))         
into :c_list separated by ' ', :n_list separated by ' ',  
     :renam_list separated by ' '                         
from vars;                                                
quit;                                                                                                               
*aqui PROC SQL é usada para criar 3 variáveis macro. Uma var macro chamada c_list
contém uma lista de cara variável carácter separada por um espaço em branco. A macro
chamada n_list irá conter uma lista com cada nova variável numérica separada por um espaço
em branco. Por fim a var macro renam_list contém uma lista com cada nova var numérica
separada por um sinal de "=" para ser usada na declaração RENAME;
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

/*EXCLUIR OS BANCOS QUE NÃO SERÃO MAIS USADOS*/
proc delete data= df1 - df5;
run;

libname sascha "D:\Estatística\ESTATÍSTICA_COMPUTACIONAL_II\Desafio_SAS\Desafio_André\Sas_data_set";
/*PROC STDIZE*/
%macro subs_mean;
%do i=1 %to &num_files;
proc stdize data=dff&i out=sascha.df_new&i missing=mean reponly;  *ESSA PROC NOS PERMITE SUBSTIUTIR O MISSING PELA MÉDIA;
  var _numeric_;
run;
%end;
%mend subs_mean;
%subs_mean;

/*######################### PARTE 4 ###################################*/

/*As sill são estimações do parâmetro (s2)=60*/
/*As range são estimações parâmetro (fi)=30*/

/*FAZENDO UMA MACRO PARA EXTRAIR A MÉDIA E A VARIÂNCIA*/
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

/*TRANSFORMANDO AS MEDIDAS EM OBSERVAÇÕES*/
proc transpose data=sascha.newaux out=sascha.vies;
run; 

/*CRIANDO UM IDENTIFICADOR PARA DISTINGUIR OS PARÂMETROS*/
data sascha.vies(rename=(col1=media col2=variancia));
set sascha.vies;
id=find(_name_,'range');
run;

/*ATRIBUINDO OS PARÂMETROS E CALCULANDO O VIÉS*/
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

/*HISTOGRAMA E CURVA DE DENSIDADE DAS DISTRIBUIÇÕES EMPREGADAS*/
title 'Distribuição de sill_mat';
proc univariate data=sascha.Df_new2;
var sill_mat;
	histogram /gamma weibull lognormal;
inset median mean std skewness/ pos = ne  header = 'Estatísticas';
axis1 label=(a=90 r=0);
run;

/*PARÂMETROS E ESTIMATIVAS DAS DISTRIBUIÇÕES*/
ods select ParameterEstimates GoodnessOfFit FitQuantiles MyHist;
proc univariate data=sascha.Df_new2;
var sill_mat;
	histogram /gamma weibull lognormal;
inset median mean std skewness;
axis1 label=(a=90 r=0);
run;

/*MACRO PARA VERIFICAR OS GRÁFICOS DO AJUSTE DAS ACAMULADAS INDIVIDUALMENTE*/
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

/*MOSTRANDO TODOS OS MÉTODOS DISPONÍVEIS EM SEVERITY PARA ESCOLHA DO MELHOR MODELO AJUSTADO*/
ods graphics on;
proc severity data = sascha.Df_new2 crit=aicc print=all plots=(cdfperdist pp qq);
loss sill_mat;
dist logn gamma weibull;
run;




