
#RECBUFSZ = 65000
#SNDBUFSZ = 65000
#ServerPort = 987
#MAX_INFO_RETRY = 987
#R2C2_Version$ = "0.2.2"

CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  #KeyCode_Enter = 10
  #KeyCode_Return = 127
  #KeyCode_Escape = 27
CompilerElse
  #KeyCode_Enter = 13
  #KeyCode_Return = 8
  #KeyCode_Escape = 27
CompilerEndIf

EnumerationBinary AdminLevels
  #Authentified
  #Moderator
  #Administrator
  #SpecialAIT
  #ServerADM
EndEnumeration

Declare FlushNetworkBuffer(socket, *buffer, bufLen)
Declare PrintMessage(msg$)
Declare ConnectR2C2Server(socket)

Macro Error(Text)
  ConsoleColor(12,0)
  PrintN(Text)
  ConsoleColor(7,0)
EndMacro  

Macro Prompt()
  ConsoleColor(10,0)
  Print(#CR$+Prompt$)
  ConsoleColor(7,0)
  Print(">"+Input$+" "+#BS$)
EndMacro

Structure SERVERINFO
  ServerName.s{255}           ;Nom du serveur
  socket.l                    ;Socket du serveur (inutilisé)
  IP.l                        ;IP du serveur (inutilisé)
  MotD.s{1024}                ;MotD (message de bienvenue) du serveur
  Desc.s{4096}                ;Description du serveur
  IsPasswd.b                  ;(Booléen) Mot de passe?
  RegEx_Username.s{255}       ;RegEx pour vérifier l'username
  RegEx_Passwd.s{255}         ;RegEx pour vérifier le mot de passe (non implémenté)
  UsernameDialogLabel.s{255}  ;Texte affiché pour l'invite de nom d'utilisateur
  PasswdDialogLabel.s{255}    ;Texte affiché pour l'invite de mot de passe
  defFlags.b                  ;Flags par défaut pour les droits
EndStructure

Global User$
Global AdmFlags.b

OpenConsole("R2C2 Remote Raw Client Connection [BETA 0.2.987]")

If Not InitNetwork()
  End
EndIf

*recBuf = AllocateMemory(#RECBUFSZ)
*sendBuf = AllocateMemory(#SNDBUFSZ)


;-Code principal

ConsoleColor(0,7)
PrintN("                           R2C2 Chat System                           ")
ConsoleColor(7,0)

Print("Adresse ou IP du serveur : ")
IP$ = Input()


PrintN("Connection au serveur...")

socket = OpenNetworkConnection(IP$,#ServerPort)

If socket
  ConnectR2C2Server(socket)
  ;   Repeat
  ;   PrintN("Bienvenue ! Choisissez votre nom d'utilisateur :")
  ;   User$ = Input()
  ; Until Not (FindString(User$," ") Or FindString(User$,"//"))
  ; 
  ;   Prompt$ = User$
  ;   
  ;   Print("Authentification...")
  ;   
  ;   SendNetworkString(socket,"ALOHA://"+User$+"//",#PB_UTF8)
  ;   Debug "ALOHA:"+"://"+User$+"//"
  ;   
  ;   ;-Authentification
  ;   Repeat
  ;     Delay(100)
  ;     
  ;     nEvent = NetworkClientEvent(socket)
  ;     
  ;     If nEvent = #PB_NetworkEvent_Data
  ;       ReceiveNetworkData(socket,*recBuf,#RECBUFSZ)
  ;       recStr$ = PeekS(*recBuf,-1,#PB_UTF8)
  ;     EndIf
  ;     Print(".")
  ;     
  ;   Until FindString(recStr$,"OK "+User$)
  ;   
  ;   PrintN("Connecté !")
  ;   
  ;   If FindString(recStr$,"MSG://SERVER//"); Y-a t-il un MotD ?
  ;     PrintMessage(recStr$)
  ;   EndIf
  
  Prompt$ = User$
  Prompt()
  
  Repeat
    Delay(20)
    
    nEvent = NetworkClientEvent(socket)
    
    Select nEvent
        
      Case #PB_NetworkEvent_Data
        FillMemory(*recBuf,#RECBUFSZ)
        
        recSize = ReceiveNetworkData(socket,*recBuf,#RECBUFSZ)
        recStr$ = PeekS(*recBuf,-1,#PB_UTF8)
        
        If Left(recStr$,3) = "MSG"
          PrintMessage(recStr$)
          Prompt()
        ElseIf Left(recStr$,3) = "CMD"
          PrintN(Right(recStr$,Len(recStr$)-6))
          Prompt()
        EndIf
        
      Case #PB_NetworkEvent_Disconnect
        Error("Vous avez été déconnecté du serveur !")
        PrintN("Pressez Entrée pour quitter")
        Input()
        End
        
      Case #PB_NetworkEvent_None
        InKey$ = Inkey()
        Raw = RawKey()
        
        If InKey$ <> "" And Raw <> #KeyCode_Enter
          Input$ + InKey$
          Print(InKey$)
        EndIf
        
        Select Raw
          Case #KeyCode_Enter ;Entrée
            If Left(Input$,1) = "/"
              SendNetworkString(socket,"CMD://"+Input$,#PB_UTF8)
              Input$ = ""
              PrintN("")
              
              Prompt()
            Else
              SendNetworkString(socket,"MSG://"+User$+"//"+Input$,#PB_UTF8)
              Input$ = ""
            EndIf 
            
            
          Case #KeyCode_Return ;Retour
            Input$ = Left(Input$,Len(Input$)-2)
            Prompt()
            
        EndSelect
        
    EndSelect
  Until RawKey() = #KeyCode_Escape
  
Else
  Error("Impossible de se connecter au serveur")
  PrintN("Pressez Entrée pour quitter")
  Input()
EndIf

Procedure FlushNetworkBuffer(socket,*buffer,bufLen)
  Repeat
    Delay(50)
    
    nEvent = NetworkClientEvent(socket)
    If nEvent = #PB_NetworkEvent_Data
      received = ReceiveNetworkData(socket,*buffer,bufLen)
    EndIf
  Until received = 0
  
EndProcedure

Procedure PrintMessage(msg$)
  Protected Sender$ = StringField(msg$,2,"//")
  Protected Message$ = (StringField(msg$,3,"//"))
  
  If FindString(Sender$,"SERVER")   ;Serveur
    ConsoleColor(14,0)
  ElseIf FindString(Sender$,"ADM")  ;Administrateur
    ConsoleColor(12,0)
  ElseIf FindString(Sender$,"MOD")  ;Modérateur
    ConsoleColor(10,0)
  ElseIf FindString(Sender$,"AIT")  ;Special (réservé)
    ConsoleColor(11,0)
  Else
    ConsoleColor(9,0)               ;Utilisateur par défaut (bolosse)
  EndIf
  
  Print(~"\r["+Sender$+"] : ")
  
  ConsoleColor(7,0)
  PrintN(Message$)
EndProcedure

Procedure ConnectR2C2Server(socket)
  Protected *inBuf = AllocateMemory(#RECBUFSZ)
  Protected *outBuf = AllocateMemory(#SNDBUFSZ)
  Protected recStr$, headerLen = StringByteLength("INFO:",#PB_UTF8), retry, isAuth = 0
  Protected *serverInfo.SERVERINFO = AllocateStructure(SERVERINFO)
  
  Delay(400)
  PrintN("Initialisation du protocole R2C2...")
  
  nEvent = NetworkClientEvent(socket)
  
  If nEvent = #PB_NetworkEvent_Data
    ReceiveNetworkData(socket,*inBuf,#RECBUFSZ)
    recStr$ = PeekS(*inBuf,-1,#PB_UTF8)
    
    PrintN(recStr$)
  EndIf
  FillMemory(*inBuf,#RECBUFSZ)
  
  Debug "Demande infos"
  Print(#CR$+"Récupération des informations de connection...")
  SendNetworkString(socket,"INFO://"+#R2C2_Version$+"//")
  
  Repeat
    Delay(100)
    FillMemory(*inBuf,#RECBUFSZ)
    
    nEvent = NetworkClientEvent(socket)
    
    Select nEvent
      Case #PB_NetworkEvent_Data
        ReceiveNetworkData(socket,*inBuf,#RECBUFSZ)
        recStr$ = PeekS(*inBuf,headerLen,#PB_UTF8)
        Debug recStr$
        
        If recStr$ = "INFO:"
          CopyMemory(*inBuf+headerLen,*serverInfo,SizeOf(SERVERINFO))
          Debug "["+*serverInfo\MotD+"]"
          Break 
        Else
          SendNetworkString(socket,"INFO://"+#R2C2_Version$+"//")
        EndIf
        
      Case #PB_NetworkEvent_Disconnect
        Error("Vous avez été déconnecté du serveur durant le processus d'authentifiation")
        
    EndSelect
    Print(".")
    retry +1
  Until retry > #MAX_INFO_RETRY
  
  PrintN("Connecté !")
  
  Debug *serverInfo\MotD
  With *serverInfo
    
    CreateRegularExpression(0,\RegEx_Username)
    
    Repeat
      Print(\UsernameDialogLabel)
      User$ = Input()
    Until MatchRegularExpression(0,User$)
    
    If \IsPasswd
      CreateRegularExpression(1,\RegEx_Passwd)
      
      Repeat        
        Print(\PasswdDialogLabel)
        Passwd$ = Input()
      Until MatchRegularExpression(1,Passwd$)
      
      SendNetworkString(socket,"ALOHA://"+User$+"//"+Passwd$)
    Else
      SendNetworkString(socket,"ALOHA://"+User$+"//")
    EndIf
    
    AdmFlags = \defFlags
    
    Repeat  
      Delay(100)
      
      nEvent = NetworkClientEvent(socket)
      
      If nEvent = #PB_NetworkEvent_Data
        
        ReceiveNetworkData(socket,*inBuf,#RECBUFSZ)
        recStr$ = PeekS(*inBuf,-1,#PB_UTF8)
        
        If FindString(recStr$,"OK")
          isAuth = 1
        ElseIf FindString(recStr$,"ERR")
          Error(recStr$)
          Break
        EndIf
      EndIf
      
    Until isAuth
    
    If isAuth
    EnableGraphicalConsole(1)
    ClearConsole()
    ConsoleLocate(0,0)
    EnableGraphicalConsole(0)
    
    ConsoleColor(0,7)
    PrintN(Space(30)+\ServerName+Space(30))
    ConsoleColor(7,0)
    PrintN(\Desc)
    ConsoleColor(15,0)
    PrintN(\MotD)
    ConsoleColor(7,0)
    
  Else
    Error("Authentification sur le serveur impossible. Vérifiez que vous possédez éventuellement le mot de passe serveur.")
    PrintN("Pressez Entrée pour quitter")
    Input()
    End
  EndIf
  
  EndWith
  
EndProcedure



; IDE Options = PureBasic 5.51 (Linux - x64)
; ExecutableFormat = Console
; CursorPosition = 320
; FirstLine = 279
; Folding = --
; EnableXP
; Executable = R2C2_Client.app
; CompileSourceDirectory
; EnableCompileCount = 6
; EnableBuildCount = 4
; EnableExeConstant