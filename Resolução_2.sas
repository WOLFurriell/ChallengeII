/*Limpando diretório work*/
proc delete data = _all_;
run;

/*Etapa 1: Importação*/
%macro importando;
	%do i=1 %to 5;
		proc import out = df&i replace 
				datafile = "C:\Users\André Felipe\Google Drive\Estats\Diretoria Análise e Desenvolvimento\Grupo de Estudos\Manipulação II SAS\Dados\df&i..txt"
				dbms = dlm;
				delimiter = "";
				getnames = yes;
		run;
	%end;
%mend;
%importando;

/*Definindo nomes das variáveis*/
%let oldnames = sill_mat range_mat sill_100_100 range_100_100 sill_100_300 range_100_300 sill_300_100 range_300_100 var9;
%let newnames = v1 sill_mat range_mat sill_100_100 range_100_100 sill_100_300 range_100_300 sill_300_100 range_300_100;
%let nvars = 9;


/*
%macro rename(data=,newdata=);
  data &newdata (drop = v1);
  		set  &data;
    		%do i = 1 %to &nvars.;
      			rename %scan(&oldnames.,&i.) = %scan(&newnames.,&i.);
    		%end;
  run;
%mend;
%rename(data=df1,newdata=df1);
%rename(data=df2,newdata=df2);
%rename(data=df3,newdata=df3);
%rename(data=df4,newdata=df4);
%rename(data=df5,newdata=df5); */

/*Etapa 2: Renomeando variáveis*/
%macro rename2;
	%do j=1 %to 5; 
		data df&j (drop = v1);
  			set df&j;
    			%do i = 1 %to &nvars.;
      				rename %scan(&oldnames.,&i.) = %scan(&newnames.,&i.);
    			%end;
		run;
	%end;
%mend;
%rename2;

/*Etapa 3: Substituindo os valores outliers pela média da variável*/

%macro outliers;
	%do k = 1 %to 5;
		data df&k;
			set df&k;
			array mt[*] _numeric_;
			do j=1 to 7 by 2;
				if(mt[j] ge 100) then mt[j] = .;
			end;
			do j=2 to 8 by 2;
	   			if(mt[j] ge 80) then mt[j] = .;
			end;
			drop j;
		run;
	%end;
%mend;
%outliers;

%macro subs_media;
	%do k = 1 %to 5;
		proc iml; reset;
			nomes = {"sill_mat", "range_mat", "sill_100_100", "range_100_100", "sill_100_300", "range_100_300", "sill_300_100" ,"range_300_100"};
			use df&k;
			read all into m;
			close df&k;

			colmeans = repeat({0},1,ncol(m));
			do j = 1 to ncol(m);
				colmeans[,j] = mean(m[,j]);
			end;
	
			do l = 1 to nrow(m);
				do c = 1 to ncol(m);
					if(m[l,c] = .) then m[l,c] = colmeans[1,c];
				end;
			end;
	
			create ndf&k from m[colname=nomes];
				append from m;	
		quit;
	%end;
%mend;
%subs_media;

/*Etapa 4: Calculando o viés e REQM*/

%let sill = 60;
%let range = 30;

proc iml; reset;
	use df5;
	read all into m;
	close df5;

	nomes = {"sill_mat", "range_mat", "sill_100_100", "range_100_100", "sill_100_300", "range_100_300", "sill_300_100" ,"range_300_100"};
	colmeans = repeat({0},1,ncol(m));
	vies = j(1,ncol(m),0);
	reqm = j(1,ncol(m),0);

	do j = 1 to ncol(m);
		colmeans[,j] = mean(m[,j]);
	end;

	vies[,{1,3,5,7}] = colmeans[,{1,3,5,7}] - &sill;
	vies[,{2,4,6,8}] = colmeans[,{2,4,6,8}] - &range;
	
	reqm[,{1,3,5,7}] = sqrt(mean((m[,{1,3,5,7}] - &sill)##2));
	reqm[,{2,4,6,8}] = sqrt(mean((m[,{2,4,6,8}] - &range)##2));

	create vies from vies[colname=nomes];
	append from vies;
		create reqm from reqm[colname=nomes];
	append from reqm; 
quit;


/*Etapa 5: Ajustando uma distribuição de probabilidade*/
ods graphics on;
proc univariate data = ndf3 noprint;
    var sill_mat;
    histogram / normal weibull lognormal;
run;


title 'Viés';
proc print data = vies noobs
	style(data)=[background=gray foreground=white]
	style(header)=[font_weight=bold background=black foreground=white];
run;

title 'REQM';
proc print data = reqm noobs
	style(data)=[background=gray foreground=white]
	style(header)=[font_weight=bold background=black foreground=white];
run;











