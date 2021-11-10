WIP.

Non-federation message sending

Message sending happens in two steps.

Step 1 is the synchronous request from client to backend, which gets a response as soon as the backend has stored the message in its database.

Step 2 is asynchronous: the actual delivery of the message may happen directly via websocket if a client is online; it may get a push notification if it’s a phone and offline; or it may get nothing. If not online, clients will “catch up” by means of calling the /notifications  endpoint. It’s the client’s responsibility to store a “pointer”, the UUID of the last message they received/decrypted, and they say “give me everything newer than the last message I know about”. Message UUIDs are time-based, and as long as all the backend servers roughly agree on what time it is, message loss is rare.

See this simplified flow diagram (click it!):

Federation “M1” message sending

In the federated case, for M1 we decided to ignore reliability guarantees or any kind of retry logic or caching. As we now understand that step 2 is asynchronous, let’s look at how step 1 looks like for federation-M1 as currently (Oct 2021) implemented:

To explain also the more complicated scenario of three backends:Of course, also Charlie@C could send a message (for the conversation in A; let’s assume it also has Chris@C), in which case there’s some extra bit of logic as Charlie will first contact backend C, and backend C will make a request to backend A, and there might be more participants (Chris) at backend C as well. In this scenario:

C acts a bit like Alice above, but then A will contact B and C to fetch a list of clients; and A will store messages locally, but also contact B and C and ask them to store messages for Bob and Chris. So C’s request to A leads to two requests A->C.

This may all not be perfectly optimized, but the M1 design is roughly “if any of the backends A,B,C is down, don’t deliver messages to anyone in this conversation”, as we thought it’s safer to have fewer surprises that can happen if something is down and some users on some backends get some messages but not others, that’s likely not desired (unless we have UI indications, see next section)
