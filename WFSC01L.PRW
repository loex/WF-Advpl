#INCLUDE 'protheus.ch'
#INCLUDE 'parmtype.ch'
#INCLUDE "TbiCode.ch"
#INCLUDE "TbiConn.ch"

/*/{Protheus.doc} WFSC01L
//TODO Descrição auto-gerada.
@author Loex
@since 16/01/2019
@version version
@example
(examples)
@see (links_or_references)
/*/

Function u_WFSC01L

	Local   aArea     := GetArea()
	Local   aRetSC    := {}
	Local   aRetSCBLQ := {}
	Private cConOrc   := ""
	Private aSaldoAKD := {}
	Private cEnv      := ""
	
	U_CONSOLE('Logou  /' + cEmpAnt + '-' + cFilAnt)
	
	//-> Carrega as solicitações para envio, levando em consideração a regra de negocio
	fLoadSC(@aRetSC,@aRetSCBLQ)
	
	//Sem nenhum regitro encontrado
	If !( Len(aRetSC) > 0) .And. !(Len(aRetSCBLQ) > 0)		
		U_CONSOLE(Replace(FunName(),'U_','') + " / Nenhuma solicitação foi encontrado na consulta" )
	Else
		If Len(aRetSC) > 0
			PrepEnvEmail(aRetSC)		
		EndIf
		If Len(aRetSCBLQ) > 0 
			PrepEnvEmail(aRetSCBLQ)
		EndIf
	EndIf
	
	RestArea(aArea)
 
Return()

/*/{Protheus.doc} fLoadSC
//TODO Função para carregar SC dentro da regra de aprovação.
@author Loex
@since 21/05/2018
@version undefined
@param aRetSC, array, descricao
@return return, return_description
@example
(examples)
@see (links_or_references)
/*/

Static Function fLoadSC(aRetSC,aRetSCBLQ)

	Local cAlias 	:= GetNextAlias()
	Local cAliasTmp := GetNextAlias()
	Local cGrpEmp   := FWGrpCompany()
	Local cStatus   := ""
	Local cNumAux   := ""
	Local nSalAKD   := 0
	Local nSaldoAux := 0

	Local nTotal    := 0
	Local nQuant    := 0
	Local nValUnit  := 0
	Local nDesc     := 0
	Local aZZH      := {}
	Local aSuperior := {}
	Local cEnv      := ""// 1=Sim;2=Nao

	BeginSql Alias cAlias
		
		SELECT   DISTINCT(C1_NUM),
				 C1_FILIAL,		         
		         C1_EMISSAO,
			     C1_XSALAKD,
			     C1_XMAIL,
			     C1_XENV,
			     C1_XREGRA
		FROM     %Table:SC1%
		WHERE    %NOTDEL%
		AND      C1_APROV    = 'B'
		AND      C1_EMISSAO >= '20200504'
		AND      C1_XENV    != ''
		ORDER BY C1_NUM, C1_FILIAL
				
	EndSql
		
	While !(cAlias)->(Eof())
	 	
	 	cConCont := Posicione("SB1",1,xFilial("SB1") + SC1->C1_PRODUTO,"B1_CONTA"   )
	 	
	 	cConOrc  := Posicione("CT1",1,xFilial("CT1") + cConCont       ,"CT1_YCTORC" )
		
		If (cAlias)->C1_XENV == "2"
			cEmail := "juniorramone@gmail.com"
		Else
			cEmail := GetEmail()
		EndIf
		
		DbSelectArea("SC1")
		DbSetOrder(1)
		If DbSeek((cAlias)->C1_FILIAL + (cAlias)->(C1_NUM))
			While !SC1->(Eof()) .And. (cAlias)->C1_FILIAL + (cAlias)->(C1_NUM) == SC1->C1_FILIAL + SC1->C1_NUM
				nQuant   += SC1->C1_QUANT
				nValUnit += SC1->C1_VUNIT
				nDesc    += SC1->C1_DESC
				nRecno   := Recno()
				SC1->(DbSkip())
			EndDo
		EndIf	
		
		cStatus := (cAlias)->C1_XREGRA
		
		nTotal  := nValUnit - nDesc 
		
		If (cAlias)->C1_XENV == "1" 
			
			aAdd(aRetSC,{  (cAlias)->(C1_FILIAL)  			,; //01
				           (cAlias)->(C1_NUM)     			,; //02
				           (cAlias)->C1_EMISSAO   			,; //03
				           ""       	            		,; //04
				           ""			                    ,; //05
				           nQuant                           ,; //06		 	       
				           nValUnit                         ,; //07
				           nTotal                           ,; //08
				           cEmail  	                        ,; //09
				           cConOrc                			,; //10                
				           cStatus                			,; //11
				           nRecno                           ,; //12
				           nSalAKD                   		,; //13
				           cEnv                             ,; //14
				           nDesc                            }) //15
				           
			//->  SO VAI ABATER O SALDO DE REGISTROS AINDA NAO PROCESSADOS	           
			If	(cAlias)->C1_XSALAKD != "1"       
				nSaldoAux += nValUnit
				aAdd(aSaldoAKD,{(cAlias)->(C1_FILIAL),cConOrc,nSaldoAux,(cAlias)->C1_XSALAKD})
			EndIf
		
		Else
			
			aAdd(aRetSCBLQ,{(cAlias)->(C1_FILIAL) 			,; //01
				           (cAlias)->(C1_NUM)     			,; //02
				           (cAlias)->C1_EMISSAO   			,; //03
				           ""       			            ,; //04
				           ""			                    ,; //05
				           nQuant	                        ,; //06		 	       
				           nValUnit                         ,; //07
				           nTotal                 			,; //08
				           cEmail  	              			,; //09
				           cConOrc                			,; //10
				           "Saldo Insuficiente"   			,; //11
				           nRecno                           ,; //12
				           nSalAKD                			,; //13
 				           cEnv                             ,; //14
				           nDesc                            }) //15

				       
		EndIf
		
		nDesc    := 0 
		nQuant   := 0
		nValUnit := 0
		nTotal   := 0
		
		(cAlias)->(DbSkip())
	EndDo
		
	(cAlias)->(DbCloseArea())

Return 

/*/{Protheus.doc} GetSaldo
//Retorna o saldo para produto de acordo com a conta orçamentaria
@author Loex
@since 21/01/2019
@version undefined
@example
(examples)
@see (links_or_references)
/*/
/*
Static Function GetSaldo(pNum,pFilSC,cStatus)

	Local nRet     := 0
	Local cAlAKD   := GetNextAlias()
	Local cProduto := ""
	Local cConCont := ""
	Local cFilSC   := pFilSC
	Local cNum     := pNum
	
	DbSelectArea("SC1")
	DbSetOrder(1)
	If DbSeek(cFilSC + cNum)
	
		While !SC1->(Eof()) .And. cFilSC + cNum == SC1->C1_FILIAL + SC1->C1_NUM	

		 	cProduto := SC1->C1_PRODUTO
		 	
		 	cConCont := Posicione("SB1",1,xFilial("SB1") + cProduto,"B1_CONTA"   )
		
			//-> pega saldo
			BeginSql Alias cAlAKD
			
				SELECT AKD_XSALDO 
				FROM   %Table:AKD%
				WHERE  %NOTDEL%
				AND    AKD_PROCES   = '000402'		
				AND    AKD_FILIAL   = %Exp:cFilSC%
				AND    AKD_CO       = %Exp:cConOrc%
				
			EndSql 	
			
			If !(cAlAKD)->(Eof())
				
				If (cAlAKD)->AKD_XSALDO <= 0
					cStatus := "SC bloqueado por saldo"
				EndIf
			
				nRet := (cAlAKD)->AKD_XSALDO
			EndIf
			
			(cAlAKD)->(DbCloseArea())
		
			SC1->(DbSkip())
		EndDo
	
	EndIf
	
Return nRet
*/
/*/{Protheus.doc} VlRegra
//Checa se a regra esta dentro do periodo para aprovação
@author Loex
@since 23/01/2019
@version undefined
@example
(examples)
@see (links_or_references)
/*/
/*
Static Function VlRegra(pNum,cStatus,pFilSC)

	Local cConCont := ""
	Local lRet     := .F.
	Local cFilSC   := pFilSC 
	Local cNum     := pNum
	Local cProduto := ""
	Local cConCont := ""
	
	DbSelectArea("SC1")
	DbSetOrder(1)
	If DbSeek(cFilSC + cNum)
		
		While !SC1->(Eof()) .And. cFilSC + cNum == SC1->C1_FILIAL + SC1->C1_NUM 
		
		 	cProduto := SC1->C1_PRODUTO
		 	
		 	cConCont := Posicione("SB1",1,xFilial("SB1") + cProduto,"B1_CONTA"   )
		 	
		 	cConOrc  := Posicione("CT1",1,xFilial("CT1") + cConCont,"CT1_YCTORC" )
		 	
			//-> Checa se a regra esta dentro do periodo para aprovação
			DbSelectArea("ZZF")
			DbSetOrder(1)
			If DbSeek(cFilSC + cConOrc)
				While !ZZF->(Eof()) .And. cFilSC + AllTrim(cConOrc) == ZZF->ZZF_FILIAL + AllTrim(ZZF->ZZF_CO)
				 	If ZZF->ZZF_UNVIGE == "1"
				 		//-> regra mensal
				 		lRet := ValRegAKD(cFilSC,AllTrim(cConOrc))
				 	Else
				 		//-> regra anual
				 		lRet := ValRegAKD(cFilSC,AllTrim(cConOrc))
				 	EndIf
					ZZF->(DbSkip())
				EndDo
			EndIf
		
			SC1->(DbSkip())
		EndDo

	EndIf	
	
	If !lRet
		cStatus := "SC fora do periodo da regra"
	EndIf

Return lRet
*/
/*/{Protheus.doc} PrepEnvEmail
//TODO Descrição auto-gerada.
@author Loex
@since 24/01/2019
@version undefined
@example
(examples)
@see (links_or_references)
/*/

Static Function PrepEnvEmail(aEnvEmail)
	
	Local   cMailID     := "" 
	Local   cTitulo 	:= "Solicitação Pendente de Autorização" 
	Local   aArea	    := GetArea() 
	Local   cFilial     := ""
	Local   cNomFil     := ""
	Local   cNomEmp     := ""
	Local   cDescDep	:= ""
	Local   cDescPro	:= ""
	Local   cDescFor	:= "" 
	Local   cNumCtrl    := ""
	Local   cPasta	    := ""
	Local   cTo		    := ""
	Local   nI		    := 0
	Local   nTotal	    := 0
	Local   nQtdTot	    := 0
	Local   nVlrTot	    := 0
	Local   lEnvia	    := .F.
	Local   lRet        := .F.
	Local   nX
	Local   nI
	Local   nZ
	Local   nR
	Local   cParam      := "" 
	//Local   cServer	    := "" //PRD - Parametro IP servidor HTTP WF
	Local   cServer	    := "192.168.2.215:1280"  //HML - Parametro IP servidor HTTP WF
	Local   cHttpServer := "http://"+cServer+ "/"
	Local   cLocCTHTML  := GETMV("MV_XGERHTM",.F.,"\web\http\emp")
	Local   cmailto     := "" 
	Local   cHtmlTexto  := ""
	Local   cGrpEmp     := FWGrpCompany()                              
	Local   cAssunto    := "Relação de Solicitação de compras pendentes de aprovação"
	Local   cEmail      := ""
	Local   aDadosSC1   := {}
	Private cGrpEmp     := FWGrpCompany() //Capturo o grupo de empresa atual na execução.
	Private oProcess    := Nil
	Private oHtml	    := Nil
	
	//Inicio o primeiro processo 
	//Tratamento do cabeçlho
	oProcess := TWFProcess():New( "APSCOM", cAssunto )
		
	oProcess:NewTask( "Envio", "\WORKFLOW\HTML\WFSC01L.htm" )
	oProcess:bReturn  		:= "U_RATH02W()"
	oProcess:bTimeOut 		:= {{"U_SPCTimeOut()",30, 0, 5 }}
	oProcess:nEncodeMime	:= 0
	oProcess:NewVersion(.T.)
	oHTML := oProcess:oHTML
		
	dbSelectArea("SM0")
	dbSetOrder(1)
	dbSeek(cEmpAnt)
	cNomEmp  := SM0->M0_NOMECOM
	U_CONSOLE(Replace(FunName(),'U_','') + " / Empresa =>" + cNomEmp)
	//Assunto o EmailAdm
	oProcess:cSubject := cNomEmp + " - " + cTitulo

	//*** Preenche os dados do cabecalho //
	oHTML:ValByName( "dData" , DTOC(dDataBase))
                                
	oHTML:ValByName( "FILIAL", cNomEmp )
	
	For nX := 1 To Len(aEnvEmail)
		
		For nI := 1 To Len(aEnvEmail)
		
			If aEnvEmail[nX][1] + AllTrim(aEnvEmail[nX][10]) == aEnvEmail[nI][1] + AllTrim(aEnvEmail[nI][10]) .And. !(aEnvEmail[nI][1] + AllTrim(aEnvEmail[nI][10]) $ cParam) 
				
				lEnvia := .T.
				
				If Empty(cTo)
					cTo := aEnvEmail[nI][9] 
					cEmail := aEnvEmail[nI][9] 
					//InitClassProc(cAssunto,cTitulo)					
				EndIf
			
				nTotal++
					
				//nVlrTot	+= aEnvEmail[nI][7]
				nVlrTot	+= aEnvEmail[nI][8]
				nQtdTot += aEnvEmail[nI][6]
				
				FWFilName(cGrpEmp, aEnvEmail[nI][1] )
				
				AAdd((oHTML:ValByName( "ped.0"  )), cValToChar(aEnvEmail[nI][12])                                              )
				AAdd((oHTML:ValByName( "ped.13" )), cValToChar(aEnvEmail[nI][12])                                              )
				
				AAdd((oHTML:ValByName( "ped.1"  )), aEnvEmail[nI][1]                                                           )	
				AAdd((oHTML:ValByName( "ped.11" )), FWFilName(cGrpEmp, aEnvEmail[nI][1])                                       )//filial
				AAdd((oHTML:ValByName( "ped.3"  )), aEnvEmail[nI][2]                                                           )//SC	
		        AAdd((oHTML:ValByName( "ped.4"  )), DToC(STOD(aEnvEmail[nI][3]))    				                           )//emissao
		        AAdd((oHTML:ValByName( "ped.5"  )), aEnvEmail[nI][11]        						                           )//produto		       
		        AAdd((oHTML:ValByName( "ped.6"  )), aEnvEmail[nI][4]		     					                           )//produto
		        AAdd((oHTML:ValByName( "ped.7"  )), aEnvEmail[nI][5]								                           )//UM
		        AAdd((oHTML:ValByName( "ped.12" )), "R$ " + AllTrim(Transform(aEnvEmail[nI][13],PesqPict("AKD","AKD_XSALDO"))) )//
		        AAdd((oHTML:ValByName( "ped.8"  )), cValToChar(aEnvEmail[nI][6])					                           )//qtd		        
		        AAdd((oHTML:ValByName( "ped.9"  )), "R$ " + AllTrim(Transform(aEnvEmail[nI][7],PesqPict("SC1","C1_VUNIT")))    )//		              
		        AAdd((oHTML:ValByName( "ped.10" )), "R$ " + AllTrim(Transform(aEnvEmail[nI][8],PesqPict("SC1","C1_VUNIT")))    )
		        
		        cArq := oProcess:Start(cLocCTHTML + cEmpAnt + "\" + cPasta + "\")

		        //aAdd(aDadosSC1,{cEmail,cMailAux,aEnvEmail[nX][1],aEnvEmail[nI][2],aEnvEmail[nX][11],aEnvEmail[nI][13],aEnvEmail[nI][14]})
		        aAdd(aDadosSC1,{cEmail,cArq,aEnvEmail[nX][1],aEnvEmail[nI][2]})
		        
	        EndIf
				
		Next nI
		
		If !(aEnvEmail[nX][1] + AllTrim(aEnvEmail[nX][10]) $ cParam)
			cParam += AllTrim(aEnvEmail[nX][1]) + AllTrim(aEnvEmail[nX][10]) + "u"
		EndIf
		
		If lEnvia
				
			oHTML:ValByName( "pedt1" , Transform(nVlrTot,PesqPict("SC7","C7_TOTAL")))	     
			oHTML:ValByName( "pedt2" , cValToChar(nQtdTot))							     
			oHTML:ValByName( "pedG"  , cValToChar(nTotal))
			
			nVlrTot := 0
			nQtdTot := 0
			nTotal  := 0
			
			oProcess:cTo := cTo  //Coloque aqui o destinatario do Email.
			
			cTo := ""
			
			cMailID := oProcess:Start(cLocCTHTML + cEmpAnt + "\" + cPasta + "\")
					
			If File( cLocCTHTML + cEmpAnt + "\" + cPasta + "\" + cMailID )
				conout("Arquivo copiado com sucesso.")
			EndIf
				
			oProcess:NewTask(cAssunto, "\WORKFLOW\HTML\wflink.htm")
					
			oProcess:cSubject := "Aprovação de Solicitação de Compras"
				
			oProcess:oHtml:ValByName("proc_link", cHttpServer + "http/emp" + cEmpAnt + "/" + cPasta + "/" + cMailID + ".htm")
			oProcess:oHtml:ValByName("referencia","Empresa " + Alltrim(SM0->M0_NOMECOM))
					
			lRet := !Empty( oProcess:Start() )
					
			If lRet
				U_CONSOLE("Solicitacao de Compras - " + aEnvEmail[nX][2] )
				U_CONSOLE(Replace(FunName(),'U_','') + " / Processo de envio: " + cMailID + " - Sucesso! " )
			EndIf
					
			cmailto    := "mailto:" + AllTrim(GetMV("MV_WFMAIL"))
			cHtmlTexto := wfloadfile(cLocCTHTML + cEmpAnt + "\" + cPasta + "\" + cMailID+ ".htm" )
			cHtmlTexto := strtran( chtmltexto, cmailto, "WFHTTPRET.APL" )
			wfsavefile(cLocCTHTML + cEmpAnt + "\" + cPasta + "\" + cMailID + ".htm", chtmltexto)
		
			oProcess:Finish()
		
		EndIf
		
		lEnvia    := .F.	
		cParamAux := cParam
		
		lRet := .F.
		
		For nZ := 1 To Len(aEnvEmail)
			If !(aEnvEmail[nZ][1] + AllTrim(aEnvEmail[nZ][10]) $ cParamAux)
				lRet := .T.
			EndIf				
		Next
		
		If lRet 
		
			oProcess := TWFProcess():New( "APSCOM", cAssunto )
				
			oProcess:NewTask( "Envio", "\WORKFLOW\HTML\WFSC01L.htm" )
			oProcess:bReturn  		:= "U_RATH01W()"
			oProcess:bTimeOut 		:= {{"U_SPCTimeOut()",30, 0, 5 }}
			oProcess:nEncodeMime	:= 0
			oProcess:NewVersion(.T.)
			oHTML := oProcess:oHTML
				
			dbSelectArea("SM0")
			dbSetOrder(1)
			dbSeek(cEmpAnt)
			cNomEmp  := SM0->M0_NOMECOM
			U_CONSOLE(Replace(FunName(),'U_','') + " / Empresa =>" + cNomEmp)
			//Assunto o EmailAdm
			oProcess:cSubject := cNomEmp + " - " + cTitulo
		
			//*** Preenche os dados do cabecalho //
			oHTML:ValByName( "dData" , DTOC(dDataBase))
		                                
			oHTML:ValByName( "FILIAL", cNomEmp )
		
		EndIf
	
	Next nX	
	
	For nR := 1 To Len(aDadosSC1)
	  AtuDadosSC1(aDadosSC1[nR][1],aDadosSC1[nR][2],aDadosSC1[nR][3],aDadosSC1[nR][4])
	Next nR
		
	U_CONSOLE(Replace(FunName(),'U_','') + " / Processo de envio - Fim do processamento" )

Return

/*/{Protheus.doc} GetEmail
//TODO Descrição auto-gerada.
@author Loex
@since 24/01/2019
@version undefined
@example
(examples)
@see (links_or_references)
/*/

Static Function GetEmail()

	Local cEmail := ""
	
	DbSelectArea("ZZF")
	DbSetOrder(1)
	If DbSeek(xFilial("ZZF") + cConOrc)		
		While !ZZF->(Eof()) .And. xFilial("ZZF") + AllTrim(cConOrc) == ZZF->ZZF_FILIAL + AllTrim(ZZF->ZZF_CO)			
			DbSelectArea("ZZH")
			DbSetOrder(1)
			If DbSeek(xFilial("ZZH") + ZZF->ZZF_CODIGO)
				While !ZZH->(Eof()) .And. xFilial("ZZH") + ZZF->ZZF_CODIGO == ZZH->ZZH_FILIAL + ZZH->ZZH_CODIGO 
					If !Empty(ZZH->ZZH_EMAIL)
						cEmail += AllTrim(ZZH->ZZH_EMAIL) + ";"
					EndIf
					ZZH->(DbSkip())
				EndDo
			EndIf				
			ZZF->(DbSkip())
		EndDo		
	EndIf

Return cEmail

/*/{Protheus.doc} LoadSldAKD
//TODO Descrição auto-gerada.
@author Loex
@since 25/01/2019
@version undefined
@example
(examples)
@see (links_or_references)
/*/

Static Function LoadSldAKD(pSaldoAKD)
	
	Local aSaldoAKD := pSaldoAKD
	Local cParam    := ""
	Local nSaldo    := 0
	Local lAtualiza := .F.
	Local lRet      := .F.
	Local nJ
	Local nK
	
	For nJ := 1 To Len(aSaldoAKD)
	
		For nK := 1 To Len(aSaldoAKD)
			
			If aSaldoAKD[nJ][1] + AllTrim(aSaldoAKD[nJ][2]) == aSaldoAKD[nK][1] + AllTrim(aSaldoAKD[nK][2]) .And. !(aSaldoAKD[nJ][1] + AllTrim(aSaldoAKD[nJ][2]) $ cParam)
			   	
			   	If aSaldoAKD[nJ][4] != "1"
			   		nSaldo += aSaldoAKD[nJ][3] 
			   		lAtualiza := .T.
				EndIf
				
			EndIf
		
		Next nK
		
		cParam += AllTrim(aSaldoAKD[nJ][1]) + AllTrim(aSaldoAKD[nJ][2]) + "u"
		
		If lAtualiza
		
			DbSelectArea("AKD")
			DbSetOrder(2)
			If DbSeek(xFilial("AKD") + aSaldoAKD[nJ][2])
				While !AKD->(Eof()) .And. xFilial("AKD") + AllTrim(aSaldoAKD[nJ][2]) == AKD->AKD_FILIAL + AllTrim(AKD->AKD_CO)
					If AKD->AKD_PROCES = '000402' 
						If RecLock("AKD",.F.)	
							AKD->AKD_XSALDO -= nSaldo
							AKD->(MsUnlock())
							lRet := .T.
						EndIf
					EndIf
					AKD->(DbSkip())
				EndDo
			EndIf
			lAtualiza := .F.
		EndIf
	
	Next nJ

Return lRet

/*/{Protheus.doc} LoadSC1
//TODO Descrição auto-gerada.
@author Loex
@since 29/01/2019
@version undefined
@example
(examples)
@see (links_or_references)
/*/

Static Function LoadSC1(pLoad)
	
	Local aLoad := pLoad
	Local nD
	
	For nD := 1 To Len(aLoad)
		
		DbSelectArea("SC1")
		DbSetOrder(1)
		If DbSeek(aLoad[nD][1] + aLoad[nD][2])
			While !SC1->(Eof()) .And. aLoad[nD][1] + aLoad[nD][2] == SC1->C1_FILIAL + SC1->C1_NUM
				If SC1->C1_XSALAKD != "1"
					If RecLock("SC1",.F.)
						SC1->C1_XSALAKD := "1"
						SC1->(MsUnlock())
					EndIf
				EndIf
				SC1->(DbSkip())
			EndDo
		EndIf
		
	Next nD
	
Return

/*/{Protheus.doc} ValRegAKD
//TODO Descrição auto-gerada.
@author Loex
@since 04/02/2019
@version undefined
@example
(examples)
@see (links_or_references)
/*/
/*
Static Function ValRegAKD(pFilSC,pConOrc,pRegra)
	
	Local cFilSC   := pFilSC
	Local cConOrc  := pConOrc
	Local cRegra   := pRegra
	Local dPeriodo := SToD("  /  /    ")
	Local dData    := SToD("  /  /    ") 
	Local lRet     := .F.

	DbSelectArea("AKD")
	DbSetOrder(2)
	If DbSeek(cFilSC + cConOrc)
		While !AKD->(Eof()) .And. cFilSC + cConOrc == AKD->AKD_FILIAL + AllTrim(AKD->AKD_CO)
			If AKD->AKD_PROCES = '000402'
				If  cRegra == "1"
					dPeriodo := CToD("01/" + AKD->AKD_XPER)
					dData    := CToD(AllTrim(Str(Last_Day(dPeriodo))) + "/" + AKD->AKD_XPER)
				Else
					dPeriodo := CToD("01/" + AKD->AKD_XPER)
					dData    := CToD(AllTrim(Str(Last_Day(dPeriodo))) + "/" + AKD->AKD_XPER)
				EndIf	
			EndIf
			AKD->(DbSkip())
		EndDo
		
		//-> Dentro do periodo da regra de alçada
		If dDataBase <= dData  
			lRet := .T.						
		EndIf					
		
	EndIf
	
Return lRet
*/
/*/{Protheus.doc} InitClassProc
//TODO Descrição auto-gerada.
@author Loex
@since 26/03/2019
@version version
@example
(examples)
@see (links_or_references)
/*/

Static Function InitClassProc(cAssunto,cTitulo)
	
	Local cNomEmp := ""
	
	oProcess := TWFProcess():New( "APSCOM", cAssunto )
		
	oProcess:NewTask( "Envio", "\WORKFLOW\HTML\WFSC01L.htm" )
	oProcess:bReturn  		:= "U_RATH01W()"
	oProcess:bTimeOut 		:= {{"U_SPCTimeOut()",30, 0, 5 }}
	oProcess:nEncodeMime	:= 0
	oProcess:NewVersion(.T.)
	oHTML := oProcess:oHTML
		
	dbSelectArea("SM0")
	dbSetOrder(1)
	dbSeek(cEmpAnt)
	cNomEmp  := SM0->M0_NOMECOM
	U_CONSOLE(Replace(FunName(),'U_','') + " / Empresa =>" + cNomEmp)
	//Assunto o EmailAdm
	oProcess:cSubject := cNomEmp + " - " + cTitulo

	//*** Preenche os dados do cabecalho //
	oHTML:ValByName( "dData" , DTOC(dDataBase))
                                
	oHTML:ValByName( "FILIAL", cNomEmp )

Return

/*/{Protheus.doc} AtuDadosSC1
//Função responsavel por atualizar a situação das solicitações enviadas pelo WF
@author Loex
@since 31/03/2020
@version version
@example
(examples)
@see (links_or_references)
/*/

Static Function AtuDadosSC1(pEmail,pMailID,pFilial,pNum)

	Local cEmail  := pEmail
	Local cMailID := pMailID
	Local cFilSC1 := pFilial
	Local cNum    := pNum 
	//Local cMotivo := pMotivo
	//Local nSaldo  := pSaldo  
	//Local cEnv    := pEnv

	DbSelectArea("SC1")
	DbSetOrder(1)
	If DbSeek(cFilSC1 + cNum)
		While !SC1->(Eof()) .And. cFilSC1 + cNum == SC1->C1_FILIAL + SC1->C1_NUM
			If RecLock("SC1",.F.)
				SC1->C1_XDATA  := dDatabase
				SC1->C1_XHORA  := Time()
				SC1->C1_XMAIL  := cEmail
				SC1->C1_XARQ   := cMailID
				//SC1->C1_XENV   := cEnv	
				//SC1->C1_XREGRA := cMotivo
				//SC1->C1_XSALDO := nSaldo			
				SC1->(MsUnlock())
			EndIf
			SC1->(DbSkip())
		EndDo
	EndIf

Return

/*/{Protheus.doc} RATH02W
//TODO Descrição auto-gerada.
@author Loex
@since 04/05/2020
@version undefined
@example
(examples)
@see (links_or_references)
/*/

Function u_RATH02W(oProcess)

	Local aArea := GetArea()
	Local nI	:= 0
	Local aPed	:= {}

	U_CONSOLE(Replace(FunName(),'U_','') + " / Acesso ao retorno...")
	
	//-> SC Aprovada
	For nI := 1 to Len(oProcess:oHtml:RetByName("ped.0"))
		If 'x' $ oProcess:oHtml:RetByName("ped.0")[nI]
			aAdd(aPed,{oProcess:oHtml:RetByName("ped.1")[nI],oProcess:oHtml:RetByName("ped.0")[nI],"A"})
		EndIf
	Next nI	
	//-> SC Reprovada
	
	For nI := 1 to Len(oProcess:oHtml:RetByName("ped.13"))
		If	'y' $ oProcess:oHtml:RetByName("ped.13")[nI]
			aAdd(aPed,{oProcess:oHtml:RetByName("ped.1")[nI],oProcess:oHtml:RetByName("ped.13")[nI],"R"})
		EndIf
	Next nI		
	
	If Len(aPed) > 0
		U_SPCRetorno( oProcess, aPed )
	EndIf	

	RestArea(aArea)
Return( Nil )