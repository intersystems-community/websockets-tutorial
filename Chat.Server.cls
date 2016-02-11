Include (%occInclude, %cspInclude, %occIO)

Class Chat.Server Extends %CSP.WebSocket
{

/// Event handler for the <b>PreServer</b> event: this is invoked before
/// starting the WebSockets Server.
/// Changes to the <property>SharedConnection</property> flag must be made here.
Method OnPreServer() As %Status
{
	s ..SharedConnection=1
	s room=$G(%request.Data("room",1),"default")
	s:room="" room="default"
	if (..WebSocketID'=""){
		s ^CacheTemp.Chat.WebSockets(..WebSocketID)=""
		s ^CacheTemp.Chat.Room(..WebSocketID)=room
	} else {
		s ^CacheTemp.Chat.Error($I(^CacheTemp.Chat.Error),"no websocketid defined")=$H 
	}
	
	Quit $$$OK
}

/// The WebSocket Server.  Use the <Method>Read</Method> and <Method>Write</Method> methods
/// to receive data from, and send data to, the client.
/// Call the <Method>EndServer</Method> method to gracefully terminate the WebSocket Server.
/// A WebSocket operating asynchronously (<property>SharedConnection=1</property>) can exit this method (using <b>Quit</B>) and subsequently open the WebSocket using the <Method>OpenServer</Method> method.
Method Server() As %Status
{
 	
	J ..StatusUpdate(..WebSocketID)
	f {		
	s data=..Read(.size,.sc,1) 
	 If ($$$ISERR(sc)){
	    if ($$$GETERRORCODE(sc)=$$$CSPWebSocketTimeout) {
	  			//$$$DEBUG("no data")
      	}
      	If ($$$GETERRORCODE(sc)=$$$CSPWebSocketClosed){
	      	k ^cacheTemp.ChatWebSockets(..WebSocketID)	
	      	Quit  // Client closed WebSocket
      	}
	 } else {
		 s mid=$I(^CacheTemp.Chat.Message)
		 s ^CacheTemp.Chat.Message(mid)=data
	 	J ..ProcessMessage(mid)
	 }
	}
  
	Quit $$$OK
}

ClassMethod StatusUpdate(wsid As %String)
{
	s stats=##class(%Object).$new()
	s stats.Type="Status"
	s stats.Message=$SYSTEM.Encryption.Base64Encode("status update, this shouldn't be processed as message")
	s stats.WSID=wsid
	s ws=..%New()
	s sc=ws.OpenServer(wsid)	
	s sc=ws.Write(stats.$toJSON())
}

ClassMethod ProcessMessage(mid As %String)
{
	
	s sc= ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject($G(^CacheTemp.Chat.Message(mid)),"%Object",.msg)
	s msg.Type="Chat"
	
	s msg.Sent=$ZDT($H,3)
	s c=$O(^CacheTemp.Chat.WebSockets(""))
	while (c'="") {
		s ws=..%New()
		s sc=ws.OpenServer(c)
		if $$$ISERR(sc){
			s ^CacheTemp.Chat.Error($I(^CacheTemp.Chat.Error),"open failed for",c)=sc 
		}
		s sc=ws.Write(msg.$toJSON())
		s c=$O(^CacheTemp.Chat.WebSockets(c))
		
	}
}

ClassMethod BroadCast(text As %String = "testmessage")
{
	s msg=##class(%Object).$new()
	s msg.Type="Chat"
	s msg.Author="system"
	s msg.Message=$SYSTEM.Encryption.Base64Encode(text)
	s c=$O(^CacheTemp.Chat.WebSockets(""))
	while (c'="") {
		s ws=..%New()
		s sc=ws.OpenServer(c)
		if $$$ISERR(sc){
			s ^CacheTemp.Chat.Error($I(^CacheTemp.Chat.Error),"open failed for",c)=sc 
			w "failed opening "_c_" removing",!
			k ^CacheTemp.Chat.WebSockets(c)
		}
		s sc=ws.Write(msg.$toJSON())
		w "written to socket "_c_" status:"_sc,!
		s c=$O(^CacheTemp.Chat.WebSockets(c))
	}
}

}
