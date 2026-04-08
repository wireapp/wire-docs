# On-Site Debugging Test Plan

## Scope of this document

When we are visiting a customer site to debug issues with our product, these are many of the procedures that we may perform to isolate issues.

## Target Audience

- Service Delivery team members performing an on-site visit.
- Support teams of customers with issues.

---

## What we need beforehand

### The Basics
A new team set up in a target environment.

- The username/password of the team owner.
- The username/password of a member of said team, for each person working on-site.

### People
- Someone who can administrate the backend.

### If things get complicated

#### Wire Client Debugging
- The ability to run the `wire-debugger` on a computing device attached to an account on an affected backend.

#### Wire Deployment Debugging
- SSH access to the TMATE ssh servers, so that a remote wire employee can temporarilly be given access to your environment, with one of your administrators riding along side, seeing and recording everything.

#### Endpoint Device Wire compatibility
- Access to a user in the affected user group who can reproduce the issue.

## What these tests should cover

The below tests should cover functional testing of the features of the product, from the end user's perspective. They should be focused on finding issues fast, not on listing every possible thing to test.

## What these tests should NOT cover

Anything that can be tested by currently existing automation, or which adding automation is easier than writing documentation.

---

## Base layer

### Login (webapp)

1. Open the inspector, flip to the **Network** tab, and open the login page to the affected environment.
   - The login page should only show `200` or `204` statuses for all assets retrieved.
   - All of the API calls should have returned their responses in less than a second.
     - `auth.js` and `vendor.js` are the 'slow' ones.

2. Attempt to login:
   - Assuming you succeeded, examine the sites loaded and the error messages to ensure we are not trying to pull in anything the customer is not expecting (`stripe.com` is a common offender).
   - Sort the list by **Status**, and find the websocket. It will be the only item with a status of `101`.
     - Ensure that the response shows ping/pongs.

### Deep Link (Android + On-Prem)

1. Clear the data in the Android app, or if it is not installed, install it.

2. Open a web browser, and fetch the `deeplink.html` from the on-prem deployment. By default this is served at `https://nginz-https.<domain>/deeplink.html`.

3. Tap the link on the page. The app should prompt you to confirm connecting to a custom backend. Confirm.
   - The app will download the `deeplink.json` configuration file from the backend. If it cannot reach the file, or the file is malformed, it will show an **"Invalid link"** error. If you see this error, verify that the `deeplink.json` is accessible and correctly structured.
   - On success, the app's welcome screen should display a **"pill"** (header banner) at the top, identifying the custom backend. Tap **"Show more"** to confirm the configuration URL matches the expected deployment.

4. Proceed to log in. Verify that the app connects to the correct backend (not wire.com).

### Login (Android + Domain Registration)

1. Clear the data in the Android app, or if it is not installed, install it.
2. Open the app. It will open to a **Welcome** screen with an email entry field.
3. Enter the email address of a user whose domain is registered to the on-prem backend.
   - The app should detect the domain and redirect to the appropriate on-prem backend automatically, rather than proceeding with the default wire.com login flow.
   - Verify that the custom backend pill/header appears, confirming the redirect was successful.
4. Complete the login with the user's credentials.
   - Confirm the user lands in their conversation list and that the backend shown matches the expected on-prem environment.

### Deep Link (iOS + On-Prem)

1. If the Wire app is already installed and deeplinked to a different backend, delete it entirely from the device and reinstall it from the App Store. Unlike Android, iOS does not expose a "clear data" option, so a full reinstall is required to ensure the app has no prior deeplink configuration.

2. Open the app and allow it to reach the **"Simply enter your email address to start!"** welcome/login screen. Deep links work fine from this state. 
   - NOTE: If you are already logged into an account, tapping the deep link will simply switch focus to the Wire app without triggering any reconfiguration — in that case, log out or reinstall before proceeding.

3. Open Safari (or another browser) and navigate to the `deeplink.html` page on the on-prem
   deployment. By default this is served at `https://nginz-https.<domain>/deeplink.html`.

4. Tap the link on the page. iOS will prompt you to confirm opening the link in Wire.
   Confirm.
   - The app will download the `deeplink.json` configuration file from the backend.
     - If it cannot reach the file, or if the file is missing required keys, the app will display an **"Invalid link"** error. If you see this, verify that `deeplink.json` is accessible from the web browser.
   - On success, the app's welcome screen should display a **"pill"** (header banner) at the top identifying the custom backend.
   - Tap **"Show more"** to confirm the configuration URL matches the expected deployment.

5. Proceed to log in. Verify that the app connects to the correct backend (not wire.com).

> **Note:** iOS does not support a persistent WebSocket mode in the background (unlike Android's "Keep connection to websocket on" setting). Push notifications on iOS depend on APNs connectivity from Gundeck. If the tester is not receiving notifications while the app is backgrounded, this is expected behaviour and not a backend fault — it indicates a Gundeck/APNs connectivity issue rather than a deep link or login problem.

### Login (iOS + Domain Registration)

1. If it is not installed, install it.
2. Open the app. It will open to a **Welcome** screen with an email entry field.
3. Enter the email address of a user whose domain is registered to the on-prem backend.
   - The app should detect the domain and redirect to the appropriate on-prem backend automatically, rather than proceeding with the default wire.com login flow.
   - Verify that the custom backend pill/header appears, confirming the redirect was successful.
4. Complete the login with the user's credentials.
   - Confirm the user lands in their conversation list and that the backend shown matches the expected on-prem environment.

---

## Messaging

### Connection Requests (webapp, Android, iOS)

Wire has two distinct connection flows depending on the accounts involved:

- **Team member to team member (same team):** 
  - No acceptance step is required. However, a connection is not automatically established with every team member — it is created on first login to Wire, by the first logged in client.
  - If you have not previously conversed with a team member, their profile will show **"Start conversation"** rather than **"Open conversation"**. Clicking "Start conversation" creates the connection and opens the 1-to-1 conversation immediately, without any action required from the other side.
  - A user's first client will have created 1-to-1 connections with all existing team members at the time of onboarding, but any team members who joined after you will require this manual first step.
- **Cross-team or personal accounts:** 
  - A full request/accept flow is required whenever the two users belong to different teams, or either user holds a personal (non-team) account. The recipient must explicitly accept before a 1-to-1 conversation is available.

#### Team member → new team member ("Start conversation")

> Requires two team member accounts (same team) that have not previously conversed. If all
> members in your test team are already connected, add a new member to the team for this
> test.

1. From Client A, in a conversation that you both share, open the profile of a team member with whom no prior conversation exists. Ask someone who has a contact with this team member to create a conversation, if none exists.
   - In Webapp or android, verify the button for contacting this person reads **"Start conversation"**, not **"Open conversation"**.
   - In iOS, the bottom of the screen shows 'Start Conversation' for users who are in this state. There is no equivalent 'Open Conversation' button.
2. Click/tap **"Start conversation"**.
   - Verify a 1-to-1 conversation is created immediately with no notification or acceptance step required on the other side.
   - Other participant will see the newly created conversation with you pop to the top of their 'Conversations' list.
3. Send a message from Client A and verify it is received by Client B.

#### Cross-team or personal account connection request flow

> Requires either a second team on the same backend, or a personal (non-team) account.
> Either satisfies this test.

**Sending a connection request:**

1. From the sender's client, search for the recipient by name or username.
2. Open their profile and send a connection request.
   - Verify the sender's view shows the conversation in a **Sent** / pending state.
   - Verify the recipient receives a notification of the incoming request. On mobile this should arrive as a push notification (subject to the same APNs/FCM caveats as other notifications). On the webapp it should appear without requiring a refresh.

**Accepting the connection request:**

3. On the recipient's client, locate the incoming connection request.
4. Accept it.
   - Verify the pending "connection" conversation is upgraded to a full 1-to-1 conversation
     with both users as members.
   - Verify the sender's client reflects the accepted state and a message can now be sent.
5. Send a short message from the sender to confirm the 1-to-1 conversation is functional
   end-to-end.

**Additional states to spot-check:**

- **Ignoring:** Have the recipient ignore a fresh request. Verify it disappears from their
  pending list but the sender remains in the **Sent** state and can resend.
- **Cancelling:** Have the sender cancel an outstanding request. Verify it disappears from
  both sides.
- **Blocking:** With an accepted connection in place, have one user block the other. Verify
  the blocked user cannot add the blocker to conversations. Note that blocking does **not**
  remove the blocked user from existing group conversations they share.

### 1-to-1 Messaging

> Requires two clients logged in as two separate team members.

1. From Client A, open or create a 1-to-1 conversation with Client B.
   - this MAY require sending a connection request (see prior procedure).
2. Send a text message from Client A.
   - Verify the message is delivered and visible on Client B without undue delay.
3. Send a reply from Client B.
   - Verify the reply appears on Client A.
4. Send a file or image attachment from Client A.
   - Verify Client B can open/preview the asset successfully.
5. Verify that message timestamps and sender names are displayed correctly on both sides.


### Group Messaging (Proteus)

> Requires at least three clients. Confirm the conversation is using the Proteus protocol (not MLS) — this is the default for existing group conversations.

1. From Client A (team owner or admin), create a new group conversation and add at least two other team members (Client B, Client C).
2. Send a text message from Client A.
   - Verify the message is received by both Client B and Client C.
3. Send a reply from Client B.
   - Verify it appears for Client A and Client C.
4. Have Client C send a file or image attachment.
   - Verify all participants can view it.
5. Remove Client C from the conversation (via Client A).
   - Verify Client C no longer receives messages.
   - Send another message from Client A and confirm only Client B receives it.

---

### Group Messaging (MLS)

> Requires MLS to be enabled on the backend (`setEnableMLS: true` in brig config, `FEATURE_ENABLE_MLS: "true"` in the webapp, and the team admin to have opted in to MLS in team settings). Requires at least three clients with MLS-capable app versions.

1. From Client A, create a new group conversation, ensuring the MLS protocol is selected (not Proteus).
2. Add at least two other team members (Client B, Client C).
   - Verify all clients successfully join the MLS group.
3. Send a text message from Client A.
   - Verify message delivery to Client B and Client C.
4. Send a reply from Client B and another from Client C.
   - Verify all messages appear correctly for all participants.
5. Send a file attachment.
   - Verify all participants can retrieve it.
6. Have Client C leave the conversation or be removed.
   - Verify that Client C can no longer receive messages.
     - The easiest platform to do this in is webapp. Ensure you see no activity at the moment a message is sent in the conversation).
7. Confirm (via the web inspector's Network tab) that message traffic is going through MLS endpoints rather than Proteus ones.

> NOTE: Clients that have not yet uploaded their MLS key packages need to open the app once to register them.

---

### Federated Messaging

> Requires a second backend (federated with the customer's backend) and a user account on that remote backend.

1. From Client A (on the customer backend), search for the remote federated user by their `user@remote-domain` handle.
   - Verify the remote user is discoverable (federation strategy must not be `allowNone`).
2. Open or initiate a 1-to-1 conversation with the remote user.
3. Send a text message from Client A.
   - Verify delivery to the remote user on their own backend.
4. Have the remote user send a reply.
   - Verify it arrives on Client A.
5. Create a group conversation on the customer backend and add both a local user and the remote federated user.
   - Send messages from all participants and verify cross-domain delivery in both directions.
6. If **classified domains** are configured, verify that the conversation displays the correct classification banner for federated participants.

---

## Calling

### Calling (1-to-1)

> Requires two clients logged in as separate users.

1. From Client A, initiate a call to Client B.
   - Verify Client B receives the incoming call notification.
2. Client B answers the call.
   - Verify two-way audio is established. Both participants should be able to hear each other.
3. (If video is supported/enabled) Enable video on Client A.
   - Verify Client B can see Client A's video feed, and vice versa. ensure that your video is not too choppy (try counting to five, holding up fingers, and seengi all five sets of fingers)
4. End the call from Client A.
   - Verify the call ends cleanly on both sides with no lingering "call in progress" state.

### Calling (Group)

> Requires at least three clients. Requires SFT to be deployed and reachable via HTTPS from all clients.

1. From Client A, start a group call in a group conversation containing Client B and Client C.
   - Client A contacts the SFT servers via HTTPS (`CONFCONN` request).
2. Client B and Client C join the call.
   - Verify all three participants can hear each other (two-way audio for all).
3. (If video is enabled) Enable video from one participant.
   - Verify the video feed is visible to all other participants.
4. Drop Client B from the call (or have Client B leave).
   - Verify the remaining participants (A and C) continue without interruption.
5. End the call from Client A.
   - Verify clean teardown for all participants.
6. Collect logs from all participants for evidence.

### Calling (Group — participant cannot reach SFT via HTTP)

> This tests the TURN relay fallback path for a participant who cannot reach the SFT directly over HTTP/UDP. The participant in question should be on a network where direct SFT connectivity is blocked.

1. Set up a group call as above (at least Clients A and B connected normally via SFT).
2. Have Client C — who **cannot** reach the SFT server directly via HTTP — attempt to join the call.
   - On windows or linux workstations, this is easily done, by changing the 'hosts' file, adding the SFT servers in question as 127.0.0.1.
   - The client should fall back to connecting via a TURN relay. The SFT and the Coturn server must have UDP connectivity between them for this path to work.
   - Verify Client C successfully joins the call, and that audio is established between all participants.
3. Confirm (via log inspection) that Client C's media path is flowing through the TURN server rather than directly to SFT.
4. End the call and verify clean teardown for all participants.
5. Collect logs from all participants for evidence.

---

### Calling (Federated)

> Requires two federated backends, each with their own SFT deployed. The caller's SFT acts as the **anchor SFT**.

1. Create a group conversation containing users from both the customer backend (e.g., Alice, Adam) and a remote federated backend (e.g., Bob, Beth).
2. Alice initiates a group call.
   - Alice's client contacts the local SFT (anchor SFT) and receives a conference URL and anchor SFT tuple.
   - Verify Alice establishes a media connection with the local SFT by log inspection.
3. Bob (on the remote backend) joins the call.
   - Bob's client recognises the conference URL belongs to a remote domain and contacts its own local SFT, passing the anchor SFT URL and tuple.
   - The remote SFT establishes a DTLS connection back to the anchor SFT.
   - Verify Bob can hear and speak to Alice.
4. Add the remaining participants (Adam and Beth). Verify all four participants have working audio.
5. Have one remote participant (Beth) leave.
   - Verify the remaining three participants continue uninterrupted.
6. End the call and verify clean teardown on both backends.
7. If the customer's environment uses TURN for SFT-to-SFT federation traffic (to avoid exposing SFTs directly to the internet), confirm via wire-debugger that SFT inter-domain traffic is routing through the federation TURN server rather than directly between SFT instances.
8. Collect logs from all participants for evidence.
