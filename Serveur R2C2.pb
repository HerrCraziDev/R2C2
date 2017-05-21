
#RECBUFSZ = 65000
#SNDBUFSZ = 65000
#ServerPort = 987
#Server = 1
#R2C2_Version$ = "0.2.3"

CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  #KeyCode_Enter = 10
  #KeyCode_Return = 127
  #KeyCode_Escape = 27
  #LineBreak$ = #LF$
CompilerElse
  #KeyCode_Enter = 13
  #KeyCode_Return = 8
  #KeyCode_Escape = 27
  #LineBreak$ = #CRLF$
CompilerEndIf

Enumeration 
  #RegEx_Username
  #RegEx_Password
EndEnumeration

EnumerationBinary CommandLevel
  #CMD_User             ;Utilisateur de base,pas de commandes
  #CMD_Primary          ;Commandes informatives (/list, /motd...)
  #CMD_UserManagement   ;Commandes de gestion des utilisateurs (kick, ban, permanent ban)
  #CMD_ServerManagement ;Commandes de gestion du serveur (/passwd, /en, /motd, /banner, /name, /open)
  #CMD_Supremacy        ;Commandes de gestion avancée (modification des permissions utilisateurs)
  #CMD_Kill             ;Kill du serveur
  #CMD_Placeholder1     ;Placeholder binaire pour utilisation future
  #CMD_Placeholder2     ;Placeholder binaire pour utilisation future
EndEnumeration

EnumerationBinary AdminLevels
  #Authentified = #CMD_User | #CMD_Primary
  #Moderator = #CMD_User | #CMD_Primary | #CMD_UserManagement
  #Administrator = #CMD_User | #CMD_Primary | #CMD_UserManagement | #CMD_ServerManagement
  #SpecialAIT =  #CMD_User | #CMD_Primary | #CMD_UserManagement | #CMD_ServerManagement | #CMD_Supremacy | #CMD_Placeholder2
  #ServerADM = $FF
EndEnumeration

MotD$ = "Bienvenue ! Vous pouvez a présent discuter sur ce serveur :) Enjoy !"
Global ServerPrompt$ = "R2C2 server"
Global Passwd$ = "drowssap"
Global Port = #ServerPort

Macro Error(Text)
  ConsoleColor(12,0)
  PrintN(#CR$+Text)
  ConsoleColor(7,0)
EndMacro  

Macro Prompt()
  ConsoleColor(10,0)
  Print(#CR$+ServerPrompt$)
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

Structure CLSTAT ;Statistiques client de base
  ConnectionTime.i
  Ping.i
  AdmFlags.b
  NbMsg.l
EndStructure

Structure ACL Extends CLSTAT;Clients authentifiés, indexés par socket
  ClientSocket.l
  ClientName.s
  ClientIP.l
EndStructure

Structure WCL ;Clients en attente d'authentification indexés par ID (socket) (non utilisée, déprécié)
  Pseudo.s
  ClientIP.l
EndStructure


Declare ExecCommand(Command$,*user.ACL)
Declare GetClientSocketByIP(IP$)
Declare GetClientSocketByName(Name$)
Declare SendMessage(Dest,Message$,isCommandResult=0)
Declare SetClientLevel(socket,AdminFlags.b)
Declare CheckName(Name$)
Declare .s SetR2C2ServerAttribute(Attribute$, Value$)

Global NewMap AuthClients.ACL()

Global Server.ACL ;Utilisateur interne du serveur (console serveur). Il peut être utile de restreindre les droits locaux de la console serveur par exemple

Server\ClientIP = MakeIPAddress(127,0,0,1)
Server\ClientSocket = -2
Server\AdmFlags = #ServerADM
Server\ClientName = "SERVER"

NewMap WaitingClients.WCL()

Global *serverInfo.SERVERINFO = AllocateStructure(SERVERINFO)

;{ Paramétres par défaut
With *serverInfo
  \ServerName = "R2C2 Official"
  \Desc = "Serveur R2C2 officiel, libre et ouvert. Actuellement en stade de test, version 0.2.2. Les commandes utilisateurs sont maintenant disponibles (/help pour + d'infos)."
  \MotD = "[Betatest 4] Bienvenue sur le serveur !"
  \IsPasswd = 0
  \UsernameDialogLabel = "Choisissez votre nom d'utilisateur (pseudo) : "
  \RegEx_Username = "[a-zA-Z0-9_][^ ]"
  \PasswdDialogLabel = "Entrez le mot de passe de connection à ce serveur : "
  \RegEx_Passwd = "[a-zA-Z0-9]"
  \defFlags = #Authentified
EndWith
;}

CreateRegularExpression(#RegEx_Username,*serverInfo\RegEx_Username)
CreateRegularExpression(#RegEx_Password,*serverInfo\RegEx_Passwd)

OpenConsole("R2C2 Remote Raw Client Connection")

If Not InitNetwork()
  End
EndIf

*inBuf = AllocateMemory(#RECBUFSZ)
*outBuf = AllocateMemory(#SNDBUFSZ)

If CountProgramParameters()
  Port = Val(ProgramParameter())
EndIf

If CreateNetworkServer(#Server,Port)
  
  ConsoleTitle("R2C2 Remote Raw Client Connection - IP : ")
  ConsoleColor(10,0)
  Print(ServerPrompt$)
  ConsoleColor(7,0)
  Print(">")
  
  Repeat
    Delay(10)
    
    sEvent = NetworkServerEvent(#Server)
    clientSocket = EventClient() : ClientSocket$ = Str(clientSocket)
    
    If clientSocket
      clientIP = GetClientIP(clientSocket)
    EndIf 
    
    Select sEvent
        
      Case #PB_NetworkEvent_Connect
        
        WaitingClients(Str(clientSocket))\ClientIP = clientIP
        
        PrintN(~"\rNew client has connected : "+IPString(clientIP)+#LineBreak$+"Waiting authentification probe...")
        SendNetworkString(clientSocket,"Welcome on the R2C2 Communication Server ! To log in, send 'ALOHA://<username>//' to the Server. Port : 987.")
        
      Case #PB_NetworkEvent_Data
        
        recSize = ReceiveNetworkData(clientSocket,*inBuf,#RECBUFSZ)
        recStr$ = PeekS(*inBuf,recSize,#PB_UTF8)
        PrintN(~"\rReceived : "+recStr$)
        
        If Left(recStr$,8) = "ALOHA://" ;Authentification d'un client du type ALOHA://<nom>//<mot de passe>
          ClientName$ = StringField(recStr$,2,"//")
          
          If (*serverInfo\IsPasswd And StringField(recStr$,3,"//") = Passwd$) Or (Not *serverInfo\IsPasswd)
            If Not FindMapElement(AuthClients(),ClientSocket$) And CheckName(ClientName$);Le client n'est pas déja connecté
              With  AuthClients(ClientSocket$)
                \ClientName = ClientName$
                \ClientSocket = clientSocket
                \ClientIP = clientIP
                \ConnectionTime = Date()
                \AdmFlags = *serverInfo\defFlags
              EndWith
              
              
              SendNetworkString(clientSocket,"OK "+ClientName$,#PB_UTF8)
              Debug "OK "+ClientName$
              
              SendNetworkString(clientSocket,"MSG://SERVER//"+MotD$,#PB_UTF8) ;Envoi du MotD (déprécié)
              
              DeleteMapElement(WaitingClients(),ClientSocket$)
            Else
              SendNetworkString(clientSocket,"ERR NAME_IN_USE : This username is already used or reserved",#PB_UTF8) ;Ce nom d'utilisateur est déja utilisé
              Error("Error : Name "+ClientName$+" already allocated")
            EndIf
          Else
            SendNetworkString(clientSocket,"ERR BAD_AUTH : Wrong password",#PB_UTF8) ;Authentification refusée (pas de mot de passe ou mt de psse incorrect)
            Error("Error :"+ClientName$+" refused")
          EndIf
          
          
        ElseIf Left(recStr$,3) = "MSG" ;Message recu, diffuser à tous les utilisateurs
          outSize = PokeS(*outBuf,recStr$,-1,#PB_UTF8)
          ;Debug "Sended : "+PeekS(*outBuf,-1,#PB_UTF8)
          ForEach AuthClients()
            If SendNetworkData(AuthClients()\ClientSocket,*outBuf,outSize) <> outSize
              Error("Envoi possiblement corrompu à "+AuthClients()\ClientName+" ("+AuthClients()\ClientIP+")")
            EndIf
          Next
          
        ElseIf Left(recStr$,7) = "INFO://" ;Demande des infos serveur
          Debug "Infos demandées"
          headerLen = StringByteLength("INFO:",#PB_UTF8)
          
          PokeS(*outBuf,"INFO:",headerLen,#PB_UTF8)
          CopyMemory(*serverInfo,*outBuf+headerLen,SizeOf(SERVERINFO)) ;La structure SERVERINFO est envoyée avec un header INFO
          
          SendNetworkData(clientSocket,*outBuf,SizeOf(SERVERINFO)+headerLen)
          
        ElseIf Left(recStr$,6) = "CMD://" ;Exécution d'une commande sur le serveur
                                          ;FIXME ici : finir
          ExecCommand(Right(recStr$,Len(recStr$)-6),@AuthClients(Str(clientSocket)))
          
        EndIf
        
        Prompt()
        
      Case #PB_NetworkEvent_Disconnect
        Traitre$ = AuthClients(ClientSocket$)\ClientName
        Error(Traitre$ + " s'est déconnecté")
        DeleteMapElement(AuthClients(),ClientSocket$)
        
        ForEach AuthClients()
          SendNetworkString(AuthClients()\ClientSocket,Traitre$ + " s'est déconnecté",#PB_UTF8)
        Next
        Prompt()
        
      Case #PB_NetworkEvent_None ;Gestion de l'interface terminal
        InKey$ = Inkey()
        Raw = RawKey()
        
        If InKey$ <> "" And Raw <> #KeyCode_Enter
          Input$ + InKey$
          Print(InKey$)
        EndIf
        
        Select Raw
          Case #KeyCode_Enter
            ExecCommand(Input$,@Server)
            Input$ = ""
            
            ConsoleColor(10,0)
            Print(ServerPrompt$)
            ConsoleColor(7,0)
            Print(">")
            
          Case #KeyCode_Return
            Input$ = Left(Input$,Len(Input$)-2)
            ConsoleColor(10,0)
            Print(#CR$+ServerPrompt$)
            ConsoleColor(7,0)
            Print(">"+Input$+" "+#BS$)
            
        EndSelect
        
    EndSelect
  ForEver
  
Else
  Error("Impossible de créer le serveur sur le port "+Str(#ServerPort))
EndIf

Procedure ExecCommand(Command$,*user.ACL)
  PrintN("")
  Command$ + " "
  
  If Left(Command$,1) = "/"
    Command$ = RemoveString(RemoveString(Command$,#CR$),#LF$)
    
    Protected OpCode$ = RTrim(StringField(Command$,1," "),#LF$)
    
    Select OpCode$
        
      Case "/say"
        If *user\AdmFlags & #CMD_ServerManagement
          SendMessage(-1,StringField(Command$,2,~"\""))
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf 
        
      Case "/ban"
        If *user\AdmFlags & #CMD_UserManagement
          socket = GetClientSocketByName(StringField(Command$,2," "))
          reason$ = StringField(Command$,2,~"\"")
          If reason$ = ""
            reason$ = "raison non spécifiée"
          EndIf
          
          If Not socket
            PrintN(~"Usage : /ban <name> <\"reason\">")
          Else
            SendMessage(socket,"Vous avez été banni pour "+reason$)
            CloseNetworkConnection(socket)
            SendMessage(-1,AuthClients(Str(socket))\ClientName + " a été banni par "+*user\ClientName+" pour "+reason$)
            DeleteMapElement(AuthClients(),Str(socket))
          EndIf
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf 
        
      Case "/adm"
        If *user\AdmFlags & #CMD_Supremacy
          socket = GetClientSocketByName(StringField(Command$,2," "))
          
          SetClientLevel(socket,#Administrator)
        Else
          Error(*user\ClientName+" n'a pas assez de priviléges pour effectuer une modification de rang d'utilisateur")
        EndIf 
        
      Case "/mod"
        If *user\AdmFlags & #CMD_Supremacy
          socket = GetClientSocketByName(StringField(Command$,2," "))
          
          SetClientLevel(socket,#Moderator)
        Else
          Error(*user\ClientName+" n'a pas assez de priviléges pour effectuer une modification de rang d'utilisateur")
        EndIf 
        
      Case "/ait"
        If *user\AdmFlags & #CMD_Supremacy
          socket = GetClientSocketByName(StringField(Command$,2," "))
          
          SetClientLevel(socket,#SpecialAIT)
        Else
          Error(*user\ClientName+" n'a pas assez de priviléges pour effectuer une modification de rang d'utilisateur")
        EndIf
        
      Case "/mp"
        If *user\AdmFlags & #CMD_User
          socket = GetClientSocketByName(StringField(Command$,2," "))
          Debug "["+StringField(Command$,2," ")+"]"
          
          If Not socket
            PrintN(~"Usage : /mp <name> <\"message\">")
          Else
            SendMessage(socket,StringField(Command$,2,~"\""))
          EndIf
        EndIf 
        
      Case "/list"
        If *user\AdmFlags & #CMD_Primary
          returnString$ = "Users : "+ #LineBreak$
          ForEach AuthClients()
            returnString$ + AuthClients()\ClientName + " : "+IPString(AuthClients()\ClientIP)+", socket : "+AuthClients()\ClientSocket+", rang : "
            Select AuthClients()\AdmFlags
              Case #Authentified : returnString$+"Utilisateur"
              Case #Moderator : returnString$ + "Modérateur"
              Case #Administrator : returnString$ + "Administrateur"
              Case #SpecialAIT : returnString$ + "Administrateur Interne Total"
              Default : returnString$ + "Statut spécial non reconnu : "+Bin(AuthClients()\AdmFlags,#PB_Byte)
            EndSelect  
            returnString$ + #LineBreak$
          Next
          
          SendMessage(*user\ClientSocket,returnString$,0)
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf
        
      Case "/motd"
        If *user\AdmFlags & #CMD_Primary
          SendMessage(*user\ClientSocket,*serverInfo\MotD)
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf
        
      Case "/desc"
        If *user\AdmFlags & #CMD_Primary
          SendMessage(*user\ClientSocket,*serverInfo\Desc)
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf
        
      Case "/help"
        returnString$ = ~"Aide des commandes du serveur R2C2\nPréfixes utilisés ici : adm : Administrateur, mod : Modérateur, ait : Administrateur Interne Total (réservé)\n\t/help : cette commande.\n\t/list : Liste tous les utilisateurs connectés\n\t/mp <utilisateur> \"message\" : Envoie un message privé à <utilisateur>. Le message doit être compris entre \".\n\t/say \"message\" (adm): Envoie un message à tous les utilisateurs du serveur, en tant qu'info du serveur.\n\t/adm <user>, /mod <user>, /ait <user> : (ait) Modifie le rang de l'utilisateur <user>.\n\t/ban <user> \"raison\" : (mod) Bannit l'utilisateur <user> et affiche le message de ban avec la raison spécifiée.\n\t/motd : Affiche le message de bienvenue du serveur.\n\t/desc : Affiche la description du serveur." 
        SendMessage(*user\ClientSocket,returnString$)
        
      Case "/set"
        If *user\AdmFlags & #CMD_Supremacy
          Property$ = StringField(Command$,2," ")
          Value$ = StringField(Command$,3," ")
          If Property$ = "" Or Value$ = ""
            SendMessage(*user\ClientSocket,"Usage : /set <property> <value>",1)
          Else
            SendMessage(*user\ClientSocket,SetR2C2ServerAttribute(Property$,Value$),1)
          EndIf
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf
        
      Case "/info"
        If *user\AdmFlags & #CMD_UserManagement
          SendMessage(*user\ClientSocket,"Informations serveur :"+#LineBreak$+
                                         "Nom : "+*serverInfo\ServerName+#LineBreak$+
                                         "MotD: "+*serverInfo\MotD+#LineBreak$+
                                         "Description : "+*serverInfo\Desc+#LineBreak$+
                                         "Mot de passe: "+Passwd$+#LineBreak$+
                                         "Utilise le mot de passe : "+*serverInfo\IsPasswd+#LineBreak$+
                                         "RegEx de pseudo : "+*serverInfo\RegEx_Username+#LineBreak$+
                                         "RegEx de mdp : "+*serverInfo\RegEx_Passwd+#LineBreak$,1)
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf
        
      Case "/quit"
        If *user\AdmFlags & #CMD_Kill
          End
        Else
          SendMessage(*user\ClientSocket,"Priviléges insuffisants pour l'exécution de cette commande",1)
        EndIf
        
      Default 
        Error("Aucune commande du serveur ne correspond à ce que vous avez entré")
        
    EndSelect
  EndIf
EndProcedure

Procedure SendMessage(Dest,Message$,isCommandResult=0)
  Select Dest 
      
    Case -1;Tous les clients
      ForEach AuthClients()
        SendNetworkString(AuthClients()\ClientSocket,"MSG://SERVER//"+Message$,#PB_UTF8)
      Next
      
    Case -2;Serveur
      PrintN(Message$)
      
    Default
      If Not isCommandResult
        SendNetworkString(AuthClients(Str(Dest))\ClientSocket,"MSG://SERVER//"+Message$,#PB_UTF8)
      Else
        SendNetworkString(AuthClients(Str(Dest))\ClientSocket,"CMD://"+Message$,#PB_UTF8)
      EndIf
      
  EndSelect
EndProcedure

Procedure GetClientSocketByIP(IP$)
  ForEach AuthClients()
    If IPString(AuthClients()\ClientIP) = IP$
      ProcedureReturn AuthClients()\ClientSocket
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure GetClientSocketByName(Name$)
  ForEach AuthClients()
    Debug "["+AuthClients()\ClientName+"]"
    If AuthClients()\ClientName = Name$
      ProcedureReturn AuthClients()\ClientSocket
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure.s SetR2C2ServerAttribute(Attribute$, Value$)
  Select Attribute$
    Case "motd"
      *serverInfo\MotD = Value$
      
    Case "desc"
      *serverInfo\Desc = Value$
      
    Case "name"
      *serverInfo\ServerName = Value$
      
    Case "hostname"
      *serverInfo\ServerName = Value$
      ServerPrompt$ = Value$
      
    Case "enable-password"
      *serverInfo\IsPasswd = Bool(Val(Value$))
      
    Case "password"
      Passwd$ = Value$
    Default
      ProcedureReturn "L'attribut "+Attribute$+" n'existe pas"
  EndSelect
  ProcedureReturn "Attribut "+Attribute$+" modifié sur "+Value$
EndProcedure

Procedure CheckName(Name$)
  ForEach AuthClients()
    If AuthClients()\ClientName = Name$
      ProcedureReturn 0
    EndIf
  Next
  
  If MatchRegularExpression(#RegEx_Username,Name$)
    ProcedureReturn 1
  Else
    ProcedureReturn 0
  EndIf
EndProcedure

Procedure SetClientLevel(socket, AdminFlags.b)
  
  If Not socket
    Error("Le nom '"+StringField(Command$,2," ")+"' ne correspond à aucun utilisateur connecté")
  Else
    AuthClients(Str(socket))\AdmFlags = AdminFlags
    ;TODO mise a jour du statut sur tous les clients
    PrintN(AuthClients(Str(socket))\ClientName + " défini sur "+Bin(AdminFlags,#PB_Byte))
    Select AdminFlags
      Case #SpecialAIT
        SendMessage(socket,"Vous avez été promu AITO ! Vous avez maintenant le contrôle du serveur.")
      Case #Administrator
        SendMessage(socket,"Vous avez été promu Administrateur")
      Case #Moderator
        SendMessage(socket,"Vous avez été promu Modérateur")
      Case #Authentified
        SendMessage(socket,"Vous avez été défini comme Utilisateur")
    EndSelect
    
  EndIf
EndProcedure
; IDE Options = PureBasic 5.51 (Linux - x64)
; ExecutableFormat = Console
; CursorPosition = 46
; FirstLine = 20
; Folding = --
; EnableXP
; Executable = R2C2_Server.app
; CompileSourceDirectory
; Compiler = PureBasic 5.51 (Linux - x64)
; EnableCompileCount = 27
; EnableBuildCount = 11
; EnableExeConstant