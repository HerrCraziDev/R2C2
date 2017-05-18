
#RECBUFSZ = 65000
#SNDBUFSZ = 65000
#ServerPort = 987

Declare FlushNetworkBuffer(socket, *buffer, bufLen)

Macro Error(Text)
  ConsoleColor(12,0)
  PrintN(Text)
  ConsoleColor(7,0)
EndMacro  




OpenConsole("R2C2 Remote Raw Client Connection [BETA 0.2.987]")

If Not InitNetwork()
  End
EndIf

*recBuf = AllocateMemory(#RECBUFSZ)
*sendBuf = AllocateMemory(#SNDBUFSZ)


PrintN("Bienvenue ! Veuillez entrer votre nom d'utilisateur :")
User$ = Input()
Prompt$ = User$ + ">"


Print("Connection au serveur...")

socket = OpenNetworkConnection("192.168.1.10",#ServerPort)

;FlushNetworkBuffer(socket, *recBuf, #RECBUFSZ)
Debug "Buffers flushed"

If socket
  Debug "Sending ack"
  SendNetworkString(socket,"ALOHA://"+User$+"//",#PB_UTF8)
  Debug "ALOHA:"+"://"+User$+"//"
  
  Repeat
    Delay(100)
    
    nEvent = NetworkClientEvent(socket)
    
    If nEvent = #PB_NetworkEvent_Data
      ReceiveNetworkData(socket,*recBuf,#RECBUFSZ)
      recStr$ = PeekS(*recBuf,-1,#PB_UTF8)
    EndIf
    Print(".")
    
  Until FindString(recStr$,"OK "+User$)
  
  PrintN("Connecté !")
  ;ClearConsole()
  
  ;EnableGraphicalConsole(1)
  ;ConsoleLocate(0,0)
  Print(Prompt$)
  
  Repeat
    Delay(50)
    
    nEvent = NetworkClientEvent(socket)
    
    Select nEvent
        
      Case #PB_NetworkEvent_Data
        FillMemory(*recBuf,#RECBUFSZ)
        
        recSize = ReceiveNetworkData(socket,*recBuf,#RECBUFSZ)
        recStr$ = PeekS(*recBuf,-1,#PB_UTF8)
        
        If Left(recStr$,3) = "MSG"
          ConsoleColor(9,0)
          Print(~"\r["+StringField(recStr$,2,"//")+"] : ")
          
          ConsoleColor(7,0)
          Print(StringField(recStr$,3,"//")+#CRLF$)
          
          Print(Prompt$+Input$)
        EndIf
        
      Case #PB_NetworkEvent_Disconnect
        Error("Vous avez été déconnecté du serveur !")
        
      Case #PB_NetworkEvent_None
        InKey$ = Inkey()
        Raw = RawKey()
        If InKey$ <> ""
          Input$ + InKey$
          Print(InKey$)
        EndIf
        
        If Raw=13
          SendNetworkString(socket,"MSG://"+User$+"//"+Input$,#PB_UTF8)
          ;Print(" >>> Envoyé !")
          Debug "Sended : "+"MSG://"+User$+"//"+Input$
          Input$ = ""
          ;Print(Prompt$)
        EndIf
        
    EndSelect
  Until RawKey() = 27
  
Else
  Error("Impossible de se connecter au serveur")
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




; IDE Options = PureBasic 5.60 (Windows - x64)
; CursorPosition = 82
; FirstLine = 63
; Folding = -
; EnableXP
; Executable = R2C2_Client.exe