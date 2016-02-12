Include (%occInclude, %cspInclude, %occIO)

Class Chat.Server Extends %CSP.WebSocket
{

/// Event handler for the <b>PreServer</b> event: this is invoked before
/// starting the WebSockets Server.
/// Changes to the <property>SharedConnection</property> flag must be made here.
Method OnPreServer() As %Status
{
	set ..SharedConnection=1
	set room=$GET(%request.Data("room",1),"default")
	set:room="" room="default"
	if (..WebSocketID'=""){
		set ^CacheTemp.Chat.WebSockets(..WebSocketID)=""
		set ^CacheTemp.Chat.Room(..WebSocketID)=room
	} else {
		set ^CacheTemp.Chat.Error($INCREMENT(^CacheTemp.Chat.Error),"no websocketid defined")=$HOROLOG 
	}
	
	Quit $$$OK
}

/// The WebSocket Server.  Use the <Method>Read</Method> and <Method>Write</Method> methods
/// to receive data from, and send data to, the client.
/// Call the <Method>EndServer</Method> method to gracefully terminate the WebSocket Server.
/// A WebSocket operating asynchronously (<property>SharedConnection=1</property>) can exit this method (using <b>Quit</B>) and subsequently open the WebSocket using the <Method>OpenServer</Method> method.
Method Server() As %Status
{
 	
	JOB ..StatusUpdate(..WebSocketID)
	for {		
	set data=..Read(.size,.sc,1) 
	 If ($$$ISERR(sc)){
	    if ($$$GETERRORCODE(sc)=$$$CSPWebSocketTimeout) {
	  			//$$$DEBUG("no data")
      	}
      	If ($$$GETERRORCODE(sc)=$$$CSPWebSocketClosed){
	      	kill ^cacheTemp.ChatWebSockets(..WebSocketID)	
	      	Quit  // Client closed WebSocket
      	}
	 } else {
		 set mid=$INCREMENT(^CacheTemp.Chat.Message)
		 set ^CacheTemp.Chat.Message(mid)=data
	 	JOB ..ProcessMessage(mid)
	 }
	}
  
	Quit $$$OK
}

ClassMethod StatusUpdate(wsid As %String)
{
	set stats=##class(%Object).$new()
	set stats.Type="Status"
	set stats.Message=$SYSTEM.Encryption.Base64Encode("status update, this shouldn't be processed as message")
	set stats.WSID=wsid
	set ws=..%New()
	set sc=ws.OpenServer(wsid)	
	set sc=ws.Write(stats.$toJSON())
}

ClassMethod ProcessMessage(mid As %String)
{
	set msg = ##class(%Object).$fromJSON($GET(^CacheTemp.Chat.Message(mid)))
	set msg.Type="Chat"
	
	set msg.Sent=$ZDATETIME($HOROLOG,3)
	set c=$ORDER(^CacheTemp.Chat.WebSockets(""))
	while (c'="") {
		set ws=..%New()
		set sc=ws.OpenServer(c)
		if $$$ISERR(sc){
			set ^CacheTemp.Chat.Error($INCREMENT(^CacheTemp.Chat.Error),"open failed for",c)=sc 
		}
		set sc=ws.Write(msg.$toJSON())
		set c=$ORDER(^CacheTemp.Chat.WebSockets(c))
		
	}
}

ClassMethod BroadCast(text As %String = "testmessage")
{
	set msg=##class(%Object).$new()
	set msg.Type="Chat"
	set msg.Author="system"
	set msg.Message=$SYSTEM.Encryption.Base64Encode(text)
	set c=$ORDER(^CacheTemp.Chat.WebSockets(""))
	while (c'="") {
		set ws=..%New()
		set sc=ws.OpenServer(c)
		if $$$ISERR(sc){
			set ^CacheTemp.Chat.Error($INCREMENT(^CacheTemp.Chat.Error),"open failed for",c)=sc 
			write "failed opening "_c_" removing",!
			kill ^CacheTemp.Chat.WebSockets(c)
		}
		set sc=ws.Write(msg.$toJSON())
		write "written to socket "_c_" status:"_sc,!
		set c=$ORDER(^CacheTemp.Chat.WebSockets(c))
	}
}

}
